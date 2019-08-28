/*
 * Class created to produce a visualforce page based on the contents of a pdf. It's the controller for the PDFHomePage.
 * It takes the image for each page of a PDF and turns it into ContentDocuments (Files) and PDFPages (references to the content files).
 * It then takes the PDFPage records and builds a Visualforce page from them.
 * Created by: Matt Gerry -- 06/17/2018
 */

global with sharing class PDFtoVFP_Generator
{
	//Declaring our class variables
	public List<String> profileNames { get; set; }
	public String sfURL { get; set; }

	public static String salesforceHost = System.Url.getSalesforceBaseURL().toExternalForm();
	public static String toolingAPIURL = salesforceHost + '/services/data/v35.0/sobjects/ApexPage';
	public static String[] profilesToUpdate;
	public static Boolean folderCreated = false;

	//In the constructor we are pulling the profile names from our custom setting (PDFtoVFP_Profiles_For_PDF_Converter)
	//and it grabs the URL for the current page we're on
	public PDFtoVFP_Generator()
	{
		profileNames = getProfileNames();
		sfURL = ApexPages.currentPage().getHeaders().get('Host');
	}

	//This method grabs the names of the profiles that should be considered for automatically granting access to the vf page we will be generating
	private List<String> getProfileNames()
	{
		//Grabbing our profiles from our custom setting of profile names and instantiating our list of profile names to pass to the vf page
		List<String> profNames = new List<String>();
		List<gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c> profs = [SELECT gAuto__Profile_Name__c FROM gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c ORDER BY Name];

		//Putting our profile names in a list of strings to pass to the vf page
		for(gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c prof : profs)
		{
			profNames.add(prof.gAuto__Profile_Name__c);
		}

		//returning profile names
		return profNames;
	}

	//This method is utilized to insert the PDF__c record that acts as a reference to the VF Page we are creating and a parent to the PDFPages
	//that are references to the ContentDocuments
	@RemoteAction
	webservice static String insertPDF(String pdfName)
	{
		//Checking to ensure the user invoking the method has visibility to the pdf object and is allowed to create pdf records
		if(Schema.sObjectType.gAuto__PDF__c.isAccessible() && Schema.sObjectType.gAuto__PDF__c.isCreateable())
		{
			//Querying to see if a PDF with the same name exists
			List<gAuto__PDF__c> pdfsFound = [SELECT Id FROM gAuto__PDF__c WHERE Name = :pdfName];

			//If we didn't find a PDF with the same name, continue
			if(pdfsFound.isEmpty())
			{
				//Trying to create and insert a new pdf record
				gAuto__PDF__c newPDF = new gAuto__PDF__c(name = pdfName);
				try
				{
					database.insert(newPDF);
				}
				//If inserting a new pdf record fails to be created log an error and return a failure to the vfp
				catch(Exception e)
				{
					PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following PDF Record ::: ' + newPDF, null);
					return 'fail';
				}

				//Returning the Id of the new PDF record to the VF Page.
				return newPDF.Id;
			}
			//If we did find an existing PDF record inform the VF Page that there is an existing VF Page with the same name (VF Page names must be unique).
			else
			{
				return 'duplicate';
			}
		}

		//If they have no access to the object return nothing to the VFP
		return null;
	}

	//This method is utilized to create a new ContentFolder for storing the ContentDocuments that get created from the images in the PDF file
	@RemoteAction
	webservice static String insertFolder(String pdfName)
	{
		//Checking to ensure that the user accessing this method has the ability to create ContentFolders
		if(Schema.sObjectType.ContentFolder.isCreateable())
		{
			//Getting the PDF to VFP settings for the org to find the Library in which PDF ContentFolders and ContentDocuments are stored
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();
			System.debug('This is the folder name ::: ' + pdfSettings.gAuto__Content_Library_Name__c);

			//Finding the library for our PDF to VFP ContentFolder to be placed in
			List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = :pdfSettings.gAuto__Content_Library_Name__c LIMIT 1];

			//If we found the library, continue
			if(!workspaceLibraries.isEmpty())
			{
				//Getting the ContentFolderLink to the library which is necessary to grab the Id of the library folder
				List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id LIMIT 1];

				//If we found the corresponding ContentFolderLink to our Library (ContentWorkspace), continue
				if(!workspaceLibraryLink.isEmpty())
				{
					//If we have not already created a folder, create ContentFolder (I think I can remove this check now, a process was creating two folders at one point)
					if(!PDFtoVFP_Generator.folderCreated)
					{
						ContentFolder newFolder = new ContentFolder();
						newFolder.Name = pdfName;
						newFolder.ParentContentFolderId = workspaceLibraryLink[0].ContentFolderId;

						//Try inserting the new folder
						try
						{
							database.insert(newFolder);
						}
						//If we failed to insert the folder generate an error log and return a failure message to the VFP
						catch(Exception e)
						{
							PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following ContentFolder ::: ' + newFolder, null);
							return 'fail';
						}

						//Return the Id of the folder to the VFP
						return newFolder.Id;
					}
				}
			}
		}

		//If the user accessing the method does not have the ability to create ContentFolders return nothing to the VF Page
		return null;
	}

	//This method inserts new ContentVersions, ContentDocumentLinks, PDFPages and organizes the ContentDocuments (created by creating ContentVersions)
	//into to the correct ContentFolder. The JSON string sent from the VFP holds the info for the ContentVersions we create (which creates ContentDocuments)
	@RemoteAction
	webservice static String insertContentDocuments(String contentDocJSON, Id parentFolderId, Id parentPDFId)
	{
		System.debug('This is the JSON ::: ' + contentDocJSON);

		//Setting up the string for the response message we send back to the controller
		String responseMsg = '';

		//Checking to ensure the user accessing this method has the ability to create and update ContentDocuments and the ability to create PDFPages
		if(Schema.sObjectType.ContentDocument.isUpdateable() && Schema.sObjectType.gAuto__PDFPage__c.isCreateable())
		{
			System.debug('We can create pdfs ::: ');

			//Setting up a savepoint to rollback all database inserts and updates in the event one fails
			Savepoint spRollback = Database.setSavepoint();

			//Taking our JSON object and using our wrapper class to parse the JSON into an object
			PDF_Page_Wrapper contentDocuments = PDF_Page_Wrapper.parse(contentDocJSON);

			//Grabbing our pdf to vfp settings to make sure we query for the correct library to put our ContentDocuments in
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();
			List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = :pdfSettings.gAuto__Content_Library_Name__c];

			//If we found a library, continue
			if(!workspaceLibraries.isEmpty())
			{
				System.debug('We have access to the library ::: ');

				//Finding the ContentFolderLink (Link to our library) to make sure it's accessible
				List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id];

				//If we found a workspace link, continue
				if(!workspaceLibraryLink.isEmpty() || Test.isRunningTest())
				{
					System.debug('We found the library link ::: ');

					//Creating the lists and sets necessary to do all of our operations
					List<ContentVersion> contentVersionInserts = new List<ContentVersion>();
					List<ContentDocumentLink> contentDocumentLinkInserts = new List<ContentDocumentLink>();
					List<gAuto__PDFPage__c> pdfPageInserts = new List<gAuto__PDFPage__c>();
					Set<Id> contentVersionIds = new Set<Id>();
					Set<Id> contentDocumentIds = new Set<Id>();

					//Iterating through our JSON object and creating new ContentVersions (which create ContentDocuments)
					for(PDF_Page_Wrapper.Documents document: contentDocuments.ContentDocuments.documentsList)
					{
						//Creating new ContentVersion
						ContentVersion newDocument = new ContentVersion();
						if(document.VersionData != null)
						{
							newDocument.VersionData = EncodingUtil.base64Decode(document.VersionData);
						}
						newDocument.Title = document.Title;
						newDocument.ContentLocation = 'S';
						newDocument.PathOnClient = document.PathOnClient;

						//Putting new ContentVersion into list of ContentVersions to be inserted later
						contentVersionInserts.add(newDocument);
					}

					//If we had ContentVersions added to our insert list, continue
					if(!contentVersionInserts.isEmpty())
					{
						System.debug('We\'re inserting these document versions ::: ' + contentVersionInserts);

						//Try inserting the ContentVersions
						try
						{
							 database.insert(contentVersionInserts);
						}
						//If we can't insert the ContentVersions, rollback all changes, insert an error into the PDFtoVFP error log
						//and return an error response
						catch(Exception e)
						{
							Database.rollback(spRollback);
							PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following ContentVersions ::: ' + contentVersionInserts, null);
							responseMsg = 'There was an error inserting the content documents for this PDF. All changes were rolled back';
							return responseMsg;
						}

						//Looping to get the ContentVersion Ids that were created via our insert of the ContentVersion Records
						for(ContentVersion cv: contentVersionInserts)
						{
							contentVersionIds.add(cv.Id);
						}

						//Querying to find more info on the ContentDocuments that got attached to the ContentVersion we created
						List<ContentVersion> createdContentVersions = [SELECT Id, ContentDocumentId, Title FROM ContentVersion WHERE Id IN: contentVersionIds];

						//Loop through the ContentVersions and create new PDFPages from it
						for(ContentVersion cVersion : createdContentVersions)
						{
							//Adding the Id of the automatically created ContentDocument to the set to use for later queries
							contentDocumentIds.add(cVersion.ContentDocumentId);

							//Creating a new PDFPage
							gAuto__PDFPage__c newPdfPage = new gAuto__PDFPage__c();
							newPdfPage.Name = cVersion.Title;
							newPdfPage.PDF__c = parentPDFId;
							newPdfPage.Page_Number__c = Decimal.valueOf(cVersion.Title.substringAfter(':::'));
							newPdfPage.Image_URL__c = '/sfc/servlet.shepherd/version/download/' + cVersion.Id;

							//Add the PDFPage to the list that we will insert
							pdfPageInserts.add(newPdfPage);
						}

						//If we have PDF Pages to insert, continue
						if(!pdfPageInserts.isEmpty())
						{
							System.debug('We\'re inserting these pdf pages ::: ' + pdfPageInserts);

							//Try inserting the PDFPages
							try
							{
								database.insert(pdfPageInserts);
							}
							//If we can't insert the pages, rollback all the previous operations, insert an error into the PDFtoVFP error logging
							//table and inform the VFP of the error
							catch(Exception e)
							{
								Database.rollback(spRollback);
								PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following pdfPages ::: ' + pdfPageInserts, null);
								responseMsg = 'There was an error inserting the pdf pages for this PDF. All changes were rolled back';
								return responseMsg;
							}
						}

						//Get a list of the ContentDocuments we just created when creating the ContentVersion records
						List<ContentDocument> contentDocumentsCreated = [SELECT Id, Title FROM ContentDocument WHERE Id IN:contentDocumentIds];

						System.debug('These are the content documents found ::: ' + contentDocumentsCreated);
						System.debug('These were the ContentDocument Ids in the set ::: ' + contentDocumentIds);

						//If we found ContentDocuments, continue
						if(!contentDocumentsCreated.isEmpty())
						{
							//Occassionally ContentDocumentLinks get automatically generated. We need to query for them to delete them prior to inserting new correct
							//ContentDocumentLinks for our ContentDocuments
							List<ContentDocumentLink> linksToDelete = [SELECT Id FROM ContentDocumentLink WHERE ContentDocumentId IN: contentDocumentIds];

							//Loop through the ContentDocuments and make ContentDocumentLinks for them (this allows the Documents to be accessible in communities)
							for(ContentDocument document : contentDocumentsCreated)
							{
									//Creating a new ContentDocumentLink
									ContentDocumentLink newDocumentLink = new ContentDocumentLink();
									newDocumentLink.ContentDocumentId = document.Id;
									newDocumentLink.LinkedEntityId = workspaceLibraries[0].Id;
									newDocumentLink.Visibility = 'AllUsers';
									newDocumentLink.ShareType = 'I';

									//Adding the ContentDocumentLink to a list that we will insert later
									contentDocumentLinkInserts.add(newDocumentLink);
							}

							//If we have ContentDocumentLinks to delete, continue
							if(!linksToDelete.isEmpty())
							{
								//Try deleting existing links
								try
								{
									database.delete(linksToDelete);
								}
								//If we can't delete the links roll everything back, log an error and inform the VF Page
								catch(Exception e)
								{
									Database.rollback(spRollback);
									PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following ContentDocumentLinks ::: ' + linksToDelete, null);
									responseMsg = 'There was an error deleting the automatically generated content document links for this PDF. All changes were rolled back';
									return responseMsg;
								}
							}

							//If we have ContentDocumentLinks, continue
							if(!contentDocumentLinkInserts.isEmpty())
							{
								System.debug('We\'re inserting these content links ::: ' + contentDocumentLinkInserts);

								//Try inserting the ContentDocumentLinks
								try
								{
									database.insert(contentDocumentLinkInserts);
								}
								//If we can't insert the ContentDocumentLinks rollback our changes, create a PDFtoVFP error log record and send the VF Page an error message
								catch(Exception e)
								{
									Database.rollback(spRollback);
									PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following ContentDocumentLinks ::: ' + contentDocumentLinkInserts, null);
									responseMsg = 'There was an error inserting the content document links for this PDF. All changes were rolled back';
									return responseMsg;
								}
							}

							Database.executeBatch(new PDFtoVFP_ContentFolderMember_Updates(contentDocumentsCreated, parentFolderId), 1);
							return 'success';
						}
						else
						{
							responseMsg = 'No content documents could be generated for this PDF. Please try again.';
						}
					}
					//If we couldn't insert ContentDocuments, inform the VF Page and user of this issue
					else
					{
						responseMsg = 'No content versions could be generated for this PDF. Please try again.';
					}
				}
				//If we couldn't find the link to our Library, inform the user the PDFtoVFP converter library has not been configured correctly
				else
				{
					responseMsg = 'The link to the workspace library could not be found. Make sure your workspace library for the PDFtoVFP converter has been configured properly.';
				}
			}
			//If we couldn't find the library inform the user that the library for the PDFtoVFP converter has not been configured correctly
			else
			{
				responseMsg = 'The workspace library could not be found. Please check the PDFtoVFP settings custom setting and make sure that' +
						'you have the correct content library name listed there. Also ensure that you (the current user) has access to that library';
			}
		}
		//If the user doesn't have access to the appropriate objects, inform them that they are unable to perform operations on them
		else
		{
			responseMsg = 'You do not have the necessary access to use the PDF to VFP converter';
		}

		return responseMsg;
	}

	//I would delete this method as it's been deprecated due to it causing memory leaks, but there is no way to delete it since it was part of the original managed package
	//so I just commented out the method so that no operations could be force performed through it.
	@RemoteAction
	webservice static String insertContentDocument(String pdfName, Integer imgNum, String fileContent, Id folderId)
	{
		/*if(Schema.sObjectType.ContentDocument.isUpdateable())
		{
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();
			List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = :pdfSettings.gAuto__Content_Library_Name__c LIMIT 1];

			if(!workspaceLibraries.isEmpty())
			{
				List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id LIMIT 1];

				if(!workspaceLibraryLink.isEmpty() || Test.isRunningTest())
				{
					ContentVersion newDocument = new ContentVersion();
					newDocument.VersionData = EncodingUtil.base64Decode(fileContent);
					newDocument.Title = pdfName + imgNum;
					newDocument.ContentLocation = 'S';
					newDocument.PathOnClient = pdfName + imgNum + '.png';
					insert newDocument;

					List<ContentDocument> contentDocumentCreated = [SELECT Id FROM ContentDocument WHERE Title = :newDocument.Title LIMIT 1];

					if(!contentDocumentCreated.isEmpty())
					{
						ContentDocumentLink newDocumentLink = new ContentDocumentLink();
						newDocumentLink.ContentDocumentId = contentDocumentCreated[0].Id;
						newDocumentLink.LinkedEntityId = workspaceLibraries[0].Id;
						newDocumentLink.Visibility = 'AllUsers';
						newDocumentLink.ShareType = 'I';
						insert newDocumentLink;

						List<ContentFolderMember> newDocumentFolderMembership = [SELECT Id, ChildRecordId, ParentContentFolderId FROM ContentFolderMember WHERE ChildRecordId = :contentDocumentCreated[0].Id LIMIT 1];

						if(!newDocumentFolderMembership.isEmpty())
						{
							newDocumentFolderMembership[0].ParentContentFolderId = folderId;
							update newDocumentFolderMembership;
						}

						return newDocument.Id;
					}
					return null;
				}
				return null;
			}
		}*/
		return null;
	}

	//I would delete this method as it's been deprecated due to it causing memory leaks, but there is no way to delete it since it was part of the original managed package
	//so I just commented out the method so that no operations could be force performed through it.
	@RemoteAction
	webservice static void insertPDFPage(String pageName, Id pdfId, String pageNum, String imageURL)
	{
		/*if(Schema.sObjectType.gAuto__PDFPage__c.isUpdateable())
		{
			gAuto__PDFPage__c newPdfPage = new gAuto__PDFPage__c();
			newPdfPage.Name = pageName;
			newPdfPage.PDF__c = pdfId;
			newPdfPage.Page_Number__c = Decimal.valueOf(pageNum);
			newPdfPage.Image_URL__c = imageURL;
			insert newPdfPage;
		}*/
	}

	//Method used to construct the vf page body based on the content of the pdf uploaded. It then calls out to another method to created the
	//VF Page via the Tooling API
	@RemoteAction
	webservice static String VFToolingManager(Id pageId, String selectedProfiles)
	{
		//Check to see if the user accessing the method has access to view the PDF object and the PDF Page object before proceeding
		if(Schema.sObjectType.gAuto__PDF__c.isAccessible() && Schema.sObjectType.gAuto__PDFPage__c.isAccessible())
		{
			//Grabbing the PDFtoVFP Settings to see what CSS the organization is utilizing for their PDFs that get generated
			//and the version number that they are using for new VF Pages
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

			//Putting the profiles we selected into a list (the split method generates a list of strings)
			PDFtoVFP_Generator.profilesToUpdate = selectedProfiles.split(',');

			System.debug('Profiles ::: ' + PDFtoVFP_Generator.profilesToUpdate);

			//Setting up the start of the VF pages body
			String vfBody = '<apex:page applyHtmlTag=\\"true\\" docType=\\"html-5.0\\" showHeader=\\"false\\" sidebar=\\"false\\" standardStylesheets=\\"false\\"> \\n <html> ';

			//Searching for our pdf, setting up the base of our css, searching for pdfPages. The <!--divAdd--> is necessary for the code to find the next place to add a PDFPage to the VF Page
			//The /n and /t are newline and tab characters that are necessary to format the page appropriately
			gAuto__PDF__c pdfFound = [SELECT Id, gAuto__VFPageId__c, Name FROM gAuto__PDF__c WHERE Id = :pageId];
			vfBody = vfBody + '\\n \\t <head>  \\n \\t \\t <apex:stylesheet value=\\"{!$Resource.' + pdfSettings.gAuto__PDF_Master_CSS_File__c + '}\\"/> \\n \\t</head> \\n \\n \\t <body class=\\"pdfContainer\\"> \\n \\t \\t <div class=\\"pageContainer\\"><!--divAdd--> \\n \\t \\t </div> \\n \\t </body>';
			List<gAuto__PDFPage__c> pdfPages = [SELECT Id, Name, gAuto__Page_Number__c, gAuto__PDF__c, gAuto__Image_URL__c FROM gAuto__PDFPage__c WHERE gAuto__PDF__c = :pageId ORDER BY gAuto__Page_Number__c ASC];
			System.debug('Pages :::' + pdfPages.size());

			//For all pdf pages generate the image for the PDF Page we are currently on. This image is a reference to the ContentDocument we created earlier
			for(gAuto__PDFPage__c page : pdfPages)
			{
				vfBody = vfBody.replace('<!--divAdd-->', '\\n \\t \\t \\t <div class=\\"page\\"> \\n \\t \\t \\t \\t <div class=\\"pageElement\\"> \\n \\t \\t \\t \\t \\t <img src=\\"' + page.gAuto__Image_URL__c + '\\"/> \\n \\t \\t \\t \\t</div> \\n \\t \\t \\t</div> <!--divAdd-->');
			}

			//Put in remaining closing tags for the VF Page body
			vfBody = vfBody + '\\n </html> \\n</apex:page>';

			//If a VF Page has already been created for this PDF, delete it.
			if(pdfFound.VFPageId__c != null)
			{
				PDFtoVFP_Generator.deleteVFPage(pdfFound.gAuto__VFPageId__c);
			}

			//Create the new VF Page by calling out to the Tooling API
			String urlForPage = PDFtoVFP_Generator.createVFPage(vfBody, pdfFound.Name, pdfFound);

			//Return the new URL for our generated VF Page
			return urlForPage;
		}

		//If the user accessing this method doesn't have access to the appropriate object, do nothing
		return null;
	}

	//This method is used to initiate the deleting of all of the records associated the PDF that was previously converted into a VF Page
	@RemoteAction
	webservice static void deletePDFFiles(Id pdfId)
	{
		//Checking to make sure the user accessing this method has the rights to delete a pdf, delete a PDFPage and to delete
		//a ContentDocument prior to running the method
		if(Schema.sObjectType.gAuto__PDF__c.isDeletable() && Schema.sObjectType.gAuto__PDFPage__c.isDeletable() && Schema.sObjectType.ContentDocument.isDeletable())
		{
			//If we passed a PDF successfully, continue
			if(pdfId != null)
			{
				//Find the PDF record that is associated to the Id that we passed in
				List<gAuto__PDF__c> pdfList = [SELECT Id, Name, VFPageId__c FROM gAuto__PDF__c WHERE Id = :pdfId LIMIT 1];

				//If we found a PDF, continue
				if(!pdfList.isEmpty())
				{
					//If a VF Page was successfully created, delete the VF Page via the Tooling API
					if(pdfList[0].VFPageId__c != null)
					{
						deleteVFPage(pdfList[0].VFPageId__c);
					}

					//Callout to the method to delete the ContentDocuments
					deleteContentDocuments(pdfList[0].Name);

					//Try deleting the PDF that we found
					try
					{
						database.delete(pdfList);
					}
					//If we failed to delete the PDF, log an error in the PDFtoVFP error logging table
					catch(Exception e)
					{
						PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following pdfs ::: ' + pdfList, null);
					}
				}
			}
		}
	}

	//Method utilized to delete ContentDocuments
	private static void deleteContentDocuments(String pdfName)
	{
		//Querying for the folder that the content documents live in
		List<ContentFolder> folderList = [SELECT Id FROM ContentFolder WHERE Name = :pdfName];

		//If we find a folder, continue
		if(!folderList.isEmpty())
		{
			//Find all the ContentDocuments (ContentFolderMember) in the folder
			List<ContentFolderMember> folderMembers = [SELECT ParentContentFolderId, ChildRecordId FROM ContentFolderMember WHERE ParentContentFolderId = :folderList[0].Id];

			//Creating the set to store the documentIds
			Set<Id> documentIds = new Set<Id>();

			//If we found ContentDocuments, continue
			if(!folderMembers.isEmpty())
			{
				//Loop through the ContentFolderMember list and store the Ids of the ContentDocuments that they represent
				for(ContentFolderMember folderMember : folderMembers)
				{
					documentIds.add(folderMember.ChildRecordId);
				}

				//Get a list of ContentDocuments using our set of Ids
				List<ContentDocument> contentDocs = [SELECT Id FROM ContentDocument WHERE Id IN:documentIds];

				//If we found ContentDocuments, continue
				if(!contentDocs.isEmpty())
				{
					//Try deleting the documents
					try
					{
						database.delete(contentDocs);
					}
					//If we can't delete the documents log an error using the PDFtoVFP error log
					catch(Exception e)
					{
						PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following content documents ::: ' + contentDocs, null);
					}
				}
			}

			//Try deleting the ContentFolder
			try
			{
				database.delete(folderList);
			}
			//If we can't delete the folder, log an error in the PDFtoVFP error log
			catch(Exception e)
			{
				PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following content folders ::: ' + folderList, null);
			}
		}
	}

	//Method used to delete a vf page using the Tooling API
	private static void deleteVFPage(String pageId)
	{
		//Getting the current users profile by querying for it and getting the profile of the system administrator
		//from the PDFtoVFP Settings custom setting
		Profile currentUsersProfile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
		gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

		//Setting up the delete request to the Tooling API
		HttpRequest req = new HttpRequest();
		String deleteURL = toolingAPIURL + '/' + pageId ;
		req.setMethod('DELETE');
		req.setEndpoint(deleteURL);
		req.setHeader('Content-type', 'application/json');

		//Setting up the variable to house the admin session id
		String adminSession = null;

		//Seeing if the current users profile is an admin profile. If it's not an admin profile, call the getAdminSessionId method to generate
		//an admin session id so that the user can make a callout to the Tooling API successfully
		if(currentUsersProfile.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
		{
			adminSession = PDFtoVFP_Generator.getAdminSessionId();
		}
		else
		{
			adminSession = UserInfo.getSessionId();
		}

		//Setting up the authorization in the header with our admin session id we generated
		req.setHeader('Authorization', 'Bearer ' + adminSession);

		//Setting up the variables for our Tooling API callout
		Http http = new Http();
		HTTPResponse res;

		//Try sending out the request
		try
		{
			res = http.send(req);
		}
		//If the request was unsuccessful, log an error in the PDFtoVFP error logging table
		catch(Exception e)
		{
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete a vfp with this request ::: ' + req, null);
		}
		System.debug(res.getBody());
	}

	//Method used to call out to the Tooling API to create our VF Page. It also updates our PDF record that is a reference to our VF Page
	//and adds the link to the VF Page and the Id of the VF Page
	private static String createVFPage(String pageBody, String pageName, gAuto__PDF__c pageToUpdate)
	{
		//Grabbing the users current profile and the pdf to vfp settings so that we can check whether or not the current user is a System Administrator
		Profile currentUsersProfile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
		gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

		//Setting up the HTTPRequest for our callout to the Tooling API
		HttpRequest req = new HttpRequest();
		req.setMethod('POST');
		req.setEndpoint(toolingAPIURL);
		req.setHeader('Content-type', 'application/json');

		//Setting up the variable to assign an admin session id to
		String adminSession = null;
		System.debug('Profile Name ::: ' + currentUsersProfile.Name + ' ::: Settings Name ::: ' + pdfSettings.gAuto__System_Admin_Profile_Name__c);

		//Determining whether the current users profile is a system admin profile or not. If it's not a system admin profile, authenticate as a system admin
		//through a connected app so that we can run the Tooling API successfully
		if(currentUsersProfile.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
		{
			adminSession = PDFtoVFP_Generator.getAdminSessionId();
		}
		else
		{
			adminSession = UserInfo.getSessionId();
		}

		//Setting up the authorization for our request using the admin session id we generated above
		req.setHeader('Authorization', 'Bearer ' + adminSession);

		//Setting up the body of our request to generate the Visualforce Page
		req.setBody('{"Name" : "' + pageName.replaceAll('\\s+', '') + '","Markup" : "' + pageBody + '","ControllerType" : "0","MasterLabel":"' + pageName + '","ApiVersion":"' + pdfSettings.gAuto__Apex_Version__c + '"}');

		System.debug('body ::: ' + pageBody);

		//Setting up our http callout variables
		Http http = new Http();
		HTTPResponse res;

		//Try sending our httpRequest out to the Tooling API to create the VFP
		try
		{
			res = http.send(req);
		}
		//If the callout fails, catch it and log it in the PDFtoVFP error loggin table, inform the VF Page we failed to create the page
		catch(Exception e)
		{
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to create a vfp with this request ::: ' + req, null);
			return 'fail';
		}

		System.debug(res.getBody());

		//Parsing the response for the Id of the VF page from the response we receive
		String vfPageId = res.getBody().substringBetween('{"id":"', '","');

		//Setting up the URL for our new VF Page
		String urlForVFP = pdfSettings.gAuto__Visualforce_Page_Base_URL__c + '/apex/' + pageName.replaceAll('\\s+', '');

		//Assign the VF Page Id and the link of the new VF Page to the PDF record we passed in
		pageToUpdate.VFPageId__c = vfPageId;
		pageToUpdate.Link_To_VF_Page__c = urlForVFP;

		//Try updating the PDF
		try
		{
			database.update(pageToUpdate);
		}
		//If the PDF fails to update, log an error in the PDFtoVFP error logger
		catch(Exception e)
		{
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to update the following PDF record : ' + pageToUpdate, null);
		}

		//Send the profiles out to the batch job that updates profiles via the metadata API
		Database.executeBatch(new PDFtoVFP_Grant_VF_Page_Access(PDFtoVFP_Generator.profilesToUpdate, pageName), 1);

		//Return the new URL for the VFP
		return urlForVFP;
	}

	//This method is utilized to grab all of the PDFs that have been created and send them back to the VF page to be loaded into a table
	@RemoteAction
	webservice static List<gAuto__PDF__c> getPDFs()
	{
		List<gAuto__PDF__c> pdfList = null;

		//Checking to see if the PDF records are viewable by the user accessing this method before querying for the data
		if(Schema.sObjectType.gAuto__PDF__c.isAccessible())
		{
			pdfList = [SELECT Id, Name, gAuto__Link_To_VF_Page__c FROM gAuto__PDF__c ORDER BY Name LIMIT 50000];
		}

		//Returning our list of PDFs
		return pdfList;
	}

	//This method returns a system administrators session id so that even if the user is not a system admin they can perform operations through the metadata API.
	private static string getAdminSessionId()
	{
		//Grabbing the custom setting that stores the admin login information
		gAuto__PDF_to_VFP_Admin_Credentials__c appLogin = gAuto__PDF_to_VFP_Admin_Credentials__c.getOrgDefaults();
		String sessionId = '';

		//Setting up a new post request to the appropriate endpoint for our custom app that we've setup to produce a system admin session id
		HttpRequest req = new HttpRequest();
		req.setMethod('POST');
		req.setEndpoint(appLogin.gAuto__App_Authentication_Base_URL__c + '?grant_type=' + appLogin.gAuto__Grant_Type__c + '&client_secret=' + appLogin.gAuto__Client_Secret__c + '&client_id=' + appLogin.gAuto__Client_Id__c + '&username=' + appLogin.gAuto__Username__c + '&password=' + appLogin.gAuto__Password__c + appLogin.gAuto__Security_Token__c + '&format=json');
		req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

		//Setting up variables for our http callout
		Http http = new Http();
		HTTPResponse res;

		//Setting up a try catch on the callout to generate valuable error logs in the event that the request fails.
		try
		{
			res = http.send(req);
		}
		catch(Exception e)
		{
			//Producing an error log if the callout fails
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to get admin session id with this request ::: ' + req, null);
		}

		//Getting the response body and then parsing it to grab the access token from the JSON returned. Then we return the session id.
		System.debug('appResponse ::: ' + res.getBody());
		String response = res.getBody();
		sessionId = response.substringBetween('{"access_token":"', '","');
		System.debug('token:::' + sessionId);
		return sessionId;
	}

	//This method inserts an error log into the PDFtoVFP Error Logging table in the event some operation fails
	public static void insertErrorLog(String errorMessage, String operation, String originalList)
	{
		//Creating a new error log
		gAuto__PDFtoVFP_Error_Log__c newError = new gAuto__PDFtoVFP_Error_Log__c();

		newError.gAuto__Internal_Error__c = errorMessage;
		newError.gAuto__Date_of_Error__c = Datetime.now();
		newError.gAuto__Operation_Attempted__c = operation;
		newError.gAuto__Original_Record_List__c = originalList;

		//Inserting the error log
		database.insert(newError);
	}
}