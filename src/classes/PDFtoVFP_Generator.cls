/*
 * Class created to produce a vf page based on the contents of a pdf. It's the controller for the PDFHomePage.
 * Created by: Matt Gerry -- 06/17/2018
 */

global with sharing class PDFtoVFP_Generator
{
	public List<String> profileNames { get; set; }
	public String sfURL { get; set; }

	public static String salesforceHost = System.Url.getSalesforceBaseURL().toExternalForm();
	public static String toolingAPIURL = salesforceHost + '/services/data/v35.0/sobjects/ApexPage';
	public static String[] profilesToUpdate;
	public static Boolean folderCreated = false;

	public PDFtoVFP_Generator()
	{
		profileNames = getProfileNames();
		sfURL = ApexPages.currentPage().getHeaders().get('Host');
	}

	private List<String> getProfileNames()
	{
		List<String> profNames = new List<String>();
		List<gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c> profs = [SELECT gAuto__Profile_Name__c FROM gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c ORDER BY Name];

		for(gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c prof : profs)
		{
			profNames.add(prof.gAuto__Profile_Name__c);
		}

		return profNames;
	}

	@RemoteAction
	webservice static String insertPDF(String pdfName)
	{
		if(Schema.sObjectType.gAuto__PDF__c.isAccessible())
		{
			List<gAuto__PDF__c> pdfsFound = [SELECT Id FROM gAuto__PDF__c WHERE Name = :pdfName];

			if(pdfsFound.isEmpty())
			{
				gAuto__PDF__c newPDF = new gAuto__PDF__c(name = pdfName);
				try
				{
					insert newPDF;
				}
				catch(Exception e)
				{
					PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following PDF Record ::: ' + newPDF, null);
					return 'fail';
				}
				return newPDF.Id;
			}
			else
			{
				return 'duplicate';
			}
		}
		return null;
	}

	@RemoteAction
	webservice static String insertFolder(String pdfName)
	{
		if(Schema.sObjectType.ContentFolder.isUpdateable())
		{
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();
			System.debug('This is the folder name ::: ' + pdfSettings.gAuto__Content_Library_Name__c);
			List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = :pdfSettings.gAuto__Content_Library_Name__c LIMIT 1];

			if(!workspaceLibraries.isEmpty())
			{
				List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id LIMIT 1];

				if(!workspaceLibraryLink.isEmpty())
				{
					if(!PDFtoVFP_Generator.folderCreated)
					{
						ContentFolder newFolder = new ContentFolder();
						newFolder.Name = pdfName;
						newFolder.ParentContentFolderId = workspaceLibraryLink[0].ContentFolderId;

						try
						{
							insert newFolder;
						}
						catch(Exception e)
						{
							PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following ContentFolder ::: ' + newFolder, null);
							return 'fail';
						}
						return newFolder.Id;
					}
				}
			}
		}

		return null;
	}

	@RemoteAction
	webservice static String insertContentDocuments(String contentDocJSON, Id parentFolderId, Id parentPDFId)
	{
		System.debug('This is the JSON ::: ' + contentDocJSON);
		String responseMsg = '';
		if(Schema.sObjectType.ContentDocument.isUpdateable() && Schema.sObjectType.gAuto__PDFPage__c.isUpdateable())
		{
			System.debug('We can create pdfs ::: ');
			Savepoint spRollback = Database.setSavepoint();
			PDF_Page_Wrapper contentDocuments = PDF_Page_Wrapper.parse(contentDocJSON);
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();
			List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = :pdfSettings.gAuto__Content_Library_Name__c];

			if(!workspaceLibraries.isEmpty())
			{
				System.debug('We have access to the library ::: ');
				List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id];

				if(!workspaceLibraryLink.isEmpty() || Test.isRunningTest())
				{
					System.debug('We found the library link ::: ');
					List<ContentVersion> contentVersionInserts = new List<ContentVersion>();
					List<ContentDocumentLink> contentDocumentLinkInserts = new List<ContentDocumentLink>();
					List<gAuto__PDFPage__c> pdfPageInserts = new List<gAuto__PDFPage__c>();
					Set<String> contentVersionTitles = new Set<String>();
					Set<Id> contentDocIds = new Set<Id>();

					for(PDF_Page_Wrapper.Documents document: contentDocuments.ContentDocuments.documentsList)
					{
						contentVersionTitles.add(document.Title);
						ContentVersion newDocument = new ContentVersion();
						if(document.VersionData != null)
						{
							newDocument.VersionData = EncodingUtil.base64Decode(document.VersionData);
						}
						newDocument.Title = document.Title;
						newDocument.ContentLocation = 'S';
						newDocument.PathOnClient = document.PathOnClient;
						contentVersionInserts.add(newDocument);
					}

					if(!contentVersionInserts.isEmpty())
					{
						System.debug('We\'re inserting these document versions ::: ' + contentVersionInserts);
						try
						{
							insert contentVersionInserts;
						}
						catch(Exception e)
						{
							Database.rollback(spRollback);
							PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following ContentVersions ::: ' + contentVersionInserts, null);
							responseMsg = 'There was an error inserting the content documents for this PDF. All changes were rolled back';
							return responseMsg;
						}

						for(ContentVersion cVersion : contentVersionInserts)
						{
							gAuto__PDFPage__c newPdfPage = new gAuto__PDFPage__c();
							newPdfPage.Name = cVersion.Title;
							newPdfPage.PDF__c = parentPDFId;
							newPdfPage.Page_Number__c = Decimal.valueOf(cVersion.Title.substringAfter(':::'));
							newPdfPage.Image_URL__c = '/sfc/servlet.shepherd/version/download/' + cVersion.Id;
							pdfPageInserts.add(newPdfPage);
						}

						if(!pdfPageInserts.isEmpty())
						{
							System.debug('We\'re inserting these pdf pages ::: ' + pdfPageInserts);
							try
							{
								insert pdfPageInserts;
							}
							catch(Exception e)
							{
								Database.rollback(spRollback);
								PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following pdfPages ::: ' + pdfPageInserts, null);
								responseMsg = 'There was an error inserting the pdf pages for this PDF. All changes were rolled back';
								return responseMsg;
							}
						}

						List<ContentDocument> contentDocumentsCreated = [SELECT Id, Title FROM ContentDocument WHERE Title IN:contentVersionTitles];

						System.debug('These are the content documents found ::: ' + contentDocumentsCreated);
						System.debug('These were the titles in the set ::: ' + contentVersionTitles);

						if(!contentDocumentsCreated.isEmpty())
						{
							for(ContentDocument document : contentDocumentsCreated)
							{
								contentDocIds.add(document.Id);
								ContentDocumentLink newDocumentLink = new ContentDocumentLink();
								newDocumentLink.ContentDocumentId = document.Id;
								newDocumentLink.LinkedEntityId = workspaceLibraries[0].Id;
								newDocumentLink.Visibility = 'AllUsers';
								newDocumentLink.ShareType = 'I';
								contentDocumentLinkInserts.add(newDocumentLink);
							}

							if(!contentDocumentLinkInserts.isEmpty())
							{
								System.debug('We\'re inserting these content links ::: ' + contentDocumentLinkInserts);
								try
								{
									insert contentDocumentLinkInserts;
								}
								catch(Exception e)
								{
									Database.rollback(spRollback);
									PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to insert the following ContentDocumentLinks ::: ' + contentDocumentLinkInserts, null);
									responseMsg = 'There was an error inserting the content documents for this PDF. All changes were rolled back';
									return responseMsg;
								}
							}

							List<ContentFolderMember> newDocumentFolderMemberships = [SELECT Id, ChildRecordId, ParentContentFolderId, ParentContentFolder.Name FROM ContentFolderMember WHERE ChildRecordId IN: contentDocIds];
							List<ContentFolderMember> unalteredFolderMemberships = newDocumentFolderMemberships;
							List<ContentFolderMember> folderMembershipUpdates = new List<ContentFolderMember>();
							Map<Id, ContentFolderMember> contentFolderMap = new Map<Id, ContentFolderMember>();
							if(!newDocumentFolderMemberships.isEmpty())
							{
								for(ContentFolderMember folderMember: newDocumentFolderMemberships)
								{
									if(parentFolderId != folderMember.ParentContentFolderId)
									{
										system.debug('This is the original folder ::: ' + folderMember.ParentContentFolder.Name);
										folderMember.ParentContentFolderId = parentFolderId;
										contentFolderMap.put(folderMember.ChildRecordId, folderMember);
									}
								}

								for(ContentFolderMember folder: contentFolderMap.values())
								{
									folderMembershipUpdates.add(folder);
								}

								System.debug('We\'re updating these content folder memberships ::: ' + folderMembershipUpdates);
								try
								{
									update folderMembershipUpdates;
								}
								catch(Exception e)
								{
									Database.rollback(spRollback);
									PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to update the following ContentFolderMembers ::: ' + folderMembershipUpdates, 'This is the original list ::: ' + unalteredFolderMemberships);
									responseMsg = 'There was an error organizing the documents into their parent folder. All changes have been rolled back.';
									return responseMsg;
								}

								return 'success';
							}
						}
					}
					else
					{
						responseMsg = 'No content documents could be generated for this PDF. Please try again.';
					}
				}
				else
				{
					responseMsg = 'The link to the workspace library could not be found. Make sure your workspace library for the PDFtoVFP converter has been configured properly.';
				}
			}
			else
			{
				responseMsg = 'The workspace library could not be found. Please check the PDFtoVFP settings custom setting and make sure that' +
						'you have the correct content library name listed there. Also ensure that you (the current user) has access to that library';
			}
		}
		else
		{
			responseMsg = 'You do not have the necessary access to use the PDF to VFP converter';
		}

		return responseMsg;
	}

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

	//Method used to construct the vf page body based on the content of the pdf uploaded.
	@RemoteAction
	webservice static String VFToolingManager(Id pageId, String selectedProfiles)
	{
		if(Schema.sObjectType.gAuto__PDF__c.isAccessible() && Schema.sObjectType.gAuto__PDFPage__c.isAccessible())
		{
			gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();
			PDFtoVFP_Generator.profilesToUpdate = selectedProfiles.split(',');

			System.debug('Profiles ::: ' + PDFtoVFP_Generator.profilesToUpdate);

			//Setting up the base for the html body of the vf page
			String vfBody = '<apex:page applyHtmlTag=\\"true\\" docType=\\"html-5.0\\" showHeader=\\"false\\" sidebar=\\"false\\" standardStylesheets=\\"false\\"> \\n <html> ';

			//Searching for our pdf, setting up the base of our css, searching for pdfPages
			gAuto__PDF__c pdfFound = [SELECT Id, gAuto__VFPageId__c, Name FROM gAuto__PDF__c WHERE Id = :pageId];
			vfBody = vfBody + '\\n \\t <head>  \\n \\t \\t <apex:stylesheet value=\\"{!$Resource.' + pdfSettings.gAuto__PDF_Master_CSS_File__c + '}\\"/> \\n \\t</head> \\n \\n \\t <body class=\\"pdfContainer\\"> \\n \\t \\t <div class=\\"pageContainer\\"><!--divAdd--> \\n \\t \\t </div> \\n \\t </body>';
			List<gAuto__PDFPage__c> pdfPages = [SELECT Id, Name, gAuto__Page_Number__c, gAuto__PDF__c, gAuto__Image_URL__c FROM gAuto__PDFPage__c WHERE gAuto__PDF__c = :pageId ORDER BY gAuto__Page_Number__c ASC];
			System.debug('Pages :::' + pdfPages.size());

			//For all pdf pages add relevant css, add divs and add their ids to the set so we can gather page elements later
			for(gAuto__PDFPage__c page : pdfPages)
			{
				vfBody = vfBody.replace('<!--divAdd-->', '\\n \\t \\t \\t <div class=\\"page\\"> \\n \\t \\t \\t \\t <div class=\\"pageElement\\"> \\n \\t \\t \\t \\t \\t <img src=\\"' + page.gAuto__Image_URL__c + '\\"/> \\n \\t \\t \\t \\t</div> \\n \\t \\t \\t</div> <!--divAdd-->');
			}

			//Put in remaining closing tags
			vfBody = vfBody + '\\n </html> \\n</apex:page>';

			//If a page has already been created, delete it.
			if(pdfFound.VFPageId__c != null)
			{
				PDFtoVFP_Generator.deleteVFPage(pdfFound.gAuto__VFPageId__c);
			}

			//Create the new vf page
			String urlForPage = PDFtoVFP_Generator.createVFPage(vfBody, pdfFound.Name, pdfFound);
			return urlForPage;
		}

		return null;
	}

	@RemoteAction
	webservice static void deletePDFFiles(Id pdfId)
	{
		if(Schema.sObjectType.gAuto__PDF__c.isDeletable() && Schema.sObjectType.gAuto__PDFPage__c.isDeletable() && Schema.sObjectType.ContentDocument.isDeletable())
		{
			if(pdfId != null)
			{
				List<gAuto__PDF__c> pdfList = [SELECT Id, Name, VFPageId__c FROM gAuto__PDF__c WHERE Id = :pdfId LIMIT 1];

				if(!pdfList.isEmpty())
				{
					if(pdfList[0].VFPageId__c != null)
					{
						deleteVFPage(pdfList[0].VFPageId__c);
					}

					deleteContentDocuments(pdfList[0].Name);

					try
					{
						delete pdfList;
					}
					catch(Exception e)
					{
						PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following pdfs ::: ' + pdfList, null);
					}
				}
			}
		}
	}

	private static void deleteContentDocuments(String pdfName)
	{
		List<ContentFolder> folderList = [SELECT Id FROM ContentFolder WHERE Name = :pdfName];

		if(!folderList.isEmpty())
		{
			List<ContentFolderMember> folderMembers = [SELECT ParentContentFolderId, ChildRecordId FROM ContentFolderMember WHERE ParentContentFolderId = :folderList[0].Id];
			Set<Id> documentIds = new Set<Id>();

			if(!folderMembers.isEmpty())
			{
				for(ContentFolderMember folderMember : folderMembers)
				{
					documentIds.add(folderMember.ChildRecordId);
				}

				List<ContentDocument> contentDocs = [SELECT Id FROM ContentDocument WHERE Id IN:documentIds];
				if(!contentDocs.isEmpty())
				{
					try
					{
						delete contentDocs;
					}
					catch(Exception e)
					{
						PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following content documents ::: ' + contentDocs, null);
					}
				}
			}

			try
			{
				delete folderList;
			}
			catch(Exception e)
			{
				PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete the following content folders ::: ' + folderList, null);
			}
		}
	}

	//Method used to delete outdated vf page using the tooling api
	private static void deleteVFPage(String pageId)
	{
		Profile currentUsersProfile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
		gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

		HttpRequest req = new HttpRequest();
		String deleteURL = toolingAPIURL + '/' + pageId ;
		req.setMethod('DELETE');
		req.setEndpoint(deleteURL);
		req.setHeader('Content-type', 'application/json');

		String adminSession = null;
		if(currentUsersProfile.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
		{
			adminSession = PDFtoVFP_Generator.getAdminSessionId();
		}
		else
		{
			adminSession = UserInfo.getSessionId();
		}

		req.setHeader('Authorization', 'Bearer ' + adminSession);
		Http http = new Http();
		HTTPResponse res;
		try
		{
			res = http.send(req);
		}
		catch(Exception e)
		{
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to delete a vfp with this request ::: ' + req, null);
		}
		System.debug(res.getBody());
	}

	//Method used to create our new vf page using the tooling api
	private static String createVFPage(String pageBody, String pageName, gAuto__PDF__c pageToUpdate)
	{
		Profile currentUsersProfile = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
		gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

		HttpRequest req = new HttpRequest();
		req.setMethod('POST');
		req.setEndpoint(toolingAPIURL);
		req.setHeader('Content-type', 'application/json');

		String adminSession = null;
		System.debug('Profile Name ::: ' + currentUsersProfile.Name + ' ::: Settings Name ::: ' + pdfSettings.gAuto__System_Admin_Profile_Name__c);
		if(currentUsersProfile.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
		{
			adminSession = PDFtoVFP_Generator.getAdminSessionId();
		}
		else
		{
			adminSession = UserInfo.getSessionId();
		}

		req.setHeader('Authorization', 'Bearer ' + adminSession);
		//for controllerType = >0 -- no controller
		req.setBody('{"Name" : "' + pageName.replaceAll('\\s+', '') + '","Markup" : "' + pageBody + '","ControllerType" : "0","MasterLabel":"' + pageName + '","ApiVersion":"' + pdfSettings.gAuto__Apex_Version__c + '"}');
		Http http = new Http();
		System.debug('body ::: ' + pageBody);
		HTTPResponse res;
		try
		{
			res = http.send(req);
		}
		catch(Exception e)
		{
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to create a vfp with this request ::: ' + req, null);
			return 'fail';
		}

		System.debug(res.getBody());
		String vfPageId = res.getBody().substringBetween('{"id":"', '","');
		String urlForVFP = pdfSettings.gAuto__Visualforce_Page_Base_URL__c + '/apex/' + pageName.replaceAll('\\s+', '');

		pageToUpdate.VFPageId__c = vfPageId;
		pageToUpdate.Link_To_VF_Page__c = urlForVFP;

		update pageToUpdate;
		Database.executeBatch(new PDFtoVFP_Grant_VF_Page_Access(PDFtoVFP_Generator.profilesToUpdate, pageName), 1);

		return urlForVFP;
	}

	@RemoteAction
	webservice static List<gAuto__PDF__c> getPDFs()
	{
		List<gAuto__PDF__c> pdfList = null;

		if(Schema.sObjectType.gAuto__PDF__c.isAccessible())
		{
			pdfList = [SELECT Id, Name, gAuto__Link_To_VF_Page__c FROM gAuto__PDF__c ORDER BY Name];
		}

		return pdfList;
	}

	private static string getAdminSessionId()
	{
		gAuto__PDF_to_VFP_Admin_Credentials__c appLogin = gAuto__PDF_to_VFP_Admin_Credentials__c.getOrgDefaults();
		String sessionId = '';

		HttpRequest req = new HttpRequest();
		req.setMethod('POST');
		req.setEndpoint(appLogin.gAuto__App_Authentication_Base_URL__c + '?grant_type=' + appLogin.gAuto__Grant_Type__c + '&client_secret=' + appLogin.gAuto__Client_Secret__c + '&client_id=' + appLogin.gAuto__Client_Id__c + '&username=' + appLogin.gAuto__Username__c + '&password=' + appLogin.gAuto__Password__c + appLogin.gAuto__Security_Token__c + '&format=json');

		req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
		Http http = new Http();
		HTTPResponse res;
		try
		{
			res = http.send(req);
		}
		catch(Exception e)
		{
			PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to get admin session id with this request ::: ' + req, null);
		}
		System.debug('appResponse ::: ' + res.getBody());

		String response = res.getBody();
		sessionId = response.substringBetween('{"access_token":"', '","');
		System.debug('token:::' + sessionId);
		return sessionId;
	}

	public static void insertErrorLog(String errorMessage, String operation, String originalList)
	{
		gAuto__PDFtoVFP_Error_Log__c newError = new gAuto__PDFtoVFP_Error_Log__c();

		newError.gAuto__Internal_Error__c = errorMessage;
		newError.gAuto__Date_of_Error__c = Datetime.now();
		newError.gAuto__Operation_Attempted__c = operation;
		newError.gAuto__Original_Record_List__c = originalList;

		insert newError;
	}
}