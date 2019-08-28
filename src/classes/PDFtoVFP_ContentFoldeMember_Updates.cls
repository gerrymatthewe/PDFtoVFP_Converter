/**
 * This class is utilized to produce the access for the visualforce pages we just created to the profiles the user selected
 * when generating the visualforce page.
 *
 * These updates must be batched because the operation can take over two minutes for a ton of profiles. Doing it in batches prevents the timeout
 * and allows for theoretically infinite profile updates.
 *
 * Created by Matt Gerry ::: gAuto ::: on 08/12/2019.
 */

global with sharing class PDFtoVFP_ContentFolderMember_Updates implements Database.Batchable<ContentDocument>
{
	//Setting our global variables
	global final List<ContentDocument> documentList;
	global final String folderId;

	//The constructor takes our passed list of profiles and the name of the new vfpage and assigns it to the global variables
	global PDFtoVFP_ContentFolderMember_Updates(List<ContentDocument> documentListPassed, String folderIdPassed)
	{
		documentList = documentListPassed;
		folderId = folderIdPassed;
	}

	//The start class must be an iterable type of string since we are passing it a list rather than a query. This allows us to iterate through the list of profiles
	global Iterable<ContentDocument> start(Database.BatchableContext BC)
	{
		return documentList;
	}

	//The execute method performs the callout to the metadata API to update the profiles and give them access to the new VFPage we generated.
	global void execute(Database.BatchableContext BC, List<ContentDocument> documentPassed)
	{

		//Gettings the list of ContentFolderMemberships for our newly created ContentDocuments (Basically a list of the folders they reside in)
		List<ContentFolderMember> newDocumentFolderMemberships = [SELECT Id, ChildRecordId, ParentContentFolderId, ParentContentFolder.Name FROM ContentFolderMember WHERE ChildRecordId = :documentPassed[0].Id LIMIT 1];

		//This list only exists for potential error logging purposes
		List<ContentFolderMember> unalteredFolderMemberships = newDocumentFolderMemberships;

		//If we found ContentFolderMemberships, continue
		if(!newDocumentFolderMemberships.isEmpty())
		{
			//Loop through our folder memberships and update their ParentFolderId to the ContentFolder we generated earlier specifically for this PDF
			for(ContentFolderMember folderMember: newDocumentFolderMemberships)
			{
				//Updating the parent folder
				folderMember.ParentContentFolderId = folderId;
			}

			System.debug('We\'re updating these content folder memberships ::: ' + newDocumentFolderMemberships);

			//Trying to update the ContentFolderMemberships
			try
			{
				database.update(newDocumentFolderMemberships);
			}
			//If we can't update the ContentFolderMemberships, rollback all of our changes thus far, insert a PDFtoVFP error log and return a response to the VF Page
			//to inform it an error occured
			catch(Exception e)
			{
				PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to update the following ContentFolderMembers ::: ' + newDocumentFolderMemberships, 'This is the original list ::: ' + unalteredFolderMemberships);
			}
		}
	}

	//Generating the email that is sent our after the profiles have been updated. This informs the user whether or not the profile updates were successful.
	global void finish(Database.BatchableContext BC)
	{
		//Querying the job table to gather the relevant info for the email we send out at finish
		System.debug('Enter PDF to VFP profile updater finish method');
		AsyncApexJob a = [SELECT Id,
				Status,
				NumberOfErrors,
				JobItemsProcessed,
				TotalJobItems,
				CompletedDate,
				ExtendedStatus,
				ApexClass.name,
				CreatedBy.Email,
				CreatedBy.Name
		FROM AsyncApexJob
		WHERE Id = :BC.getJobId()];

		//Setting up the email message that we will send out
		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
		mail.ToAddresses  = new string[] {a.CreatedBy.Email};
		mail.setSubject('PDF to VFP Profile Update Status:  ' + a.ApexClass.name);

		//Setting up the table stylings for the html body of the email
		string td1 = '"border:1px solid #e6e6e6; width=200px;"';
		string td2 = '"width=200px; border:1px solid #e6e6e6; background-color:#E44905; color:white; font-weight:bold;"';
		string tdHead = '"border:1px solid #e6e6e6; width=200px; color:white; background-color:#9370DB; font-weight:bold;"';
		string ExtendedStatus = '';
		string tdErrors = td1;

		//If we have an extended status, assign it to our string
		if (a.ExtendedStatus != null)
		{
			ExtendedStatus = a.ExtendedStatus;
		}

		//If we have errors, assign the td2 stylings to the errors table data string
		if (a.NumberOfErrors > 0)
		{
			tdErrors = td2;
		}
		//Setting up the htmlbody with all the job info to be sent out
		string htmlBody = '<div style="border:2px solid #e6e6e6; border-radius:10px; "><p>Hi ' + UserInfo.getFirstName() + ' ' + UserInfo.getLastName() + ',</p><p><span style="color:brown; font-weight:bolder;">The ContentFolderMember updater </span> completed running.'
				+ '<p>Results:</p>'
				+ '<center><table style="border:3px solid #e6e6e6; border-collapse:collapse;">'
				+ '<tr><td style=' + tdHead + '>Class Name</td><td style=' + tdHead + '>' + a.ApexClass.name + '</td></tr>'
				+ '<tr><td style=' + td1 + '>Completed Date</td><td style=' + td1 + '>' + a.CompletedDate + '</td></tr>'
				+ '<tr><td style=' + td1 + '>Status</td><td style=' + td1 + '>' + a.Status + '</td></tr>'
				+ '<tr><td style=' + td1 + '>Job Items Processed</td><td style=' + td1 + '>' + a.JobItemsProcessed + ' / ' + a.TotalJobItems + '</td></tr>'
				+ '<tr><td style=' + td1 + '>NumberOfErrors</td><td style=' + tdErrors + '>' + a.NumberOfErrors + '</td></tr>'
				+ '<tr><td style=' + td1 + '>Extended Status</td><td style=' + td1 + '>' + ExtendedStatus + '</td></tr>'
				+ '<tr><td style=' + tdHead + '>Created By</td><td style=' + tdHead + '>' + a.CreatedBy.Name + ' (' + a.CreatedBy.Email + ')</td></tr>'
				+ '</table></center>'
				+ '<p><span style="font-family:"Courier New", Courier, monospace; color:#e6e6e6; font-weight:bold; font-size:larger;">PDF to VFP Converter Automated Message</span></p></div>';

		//Setting the email body up for the email we will send out
		mail.setHtmlBody(htmlBody);
		mail.setPlainTextBody(htmlBody);

		//Adding the email we've set up to the list of outbound emails we will send
		List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
		mails.add(mail);

		//If we aren't running tests, send out the email. Test classes sending fake emails still count toward your daily email limit. To prevent eating unnecessary emails on that
		//limit we prevent the test from sending out the fake email.
		if(!Test.isRunningTest())
		{
			Messaging.sendEmail(mails);
		}

		System.debug('Exit PDF to VFP profile updater finish method');
	}
}