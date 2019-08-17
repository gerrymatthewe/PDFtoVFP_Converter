/**
 * Created by gerry on 8/12/2019.
 */

global with sharing class PDFtoVFP_Grant_VF_Page_Access implements Database.Batchable<String>, Database.AllowsCallouts
{
    global final List<String> profileList;
    global final String pageName;

    global PDFtoVFP_Grant_VF_Page_Access(List<String> profilesPassed, String pageNamePassed)
    {
        profileList = profilesPassed;
        pageName = pageNamePassed;
    }

    global Iterable<String> start(Database.BatchableContext BC)
    {
        return profileList;
    }

    global void execute(Database.BatchableContext BC, List<String> profilePassed)
    {
        //If you're not a system admin, add current user profile to the list of profiles to update
        Profile prof = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

        System.debug('Profile Name ::: ' + prof.Name);

        if(prof.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
        {
            profilePassed.add(prof.Name);
        }

        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();

        String adminSession = null;
        if(prof.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
        {
            adminSession = PDFtoVFP_Generator.getAdminSessionId();
        }
        else
        {
            adminSession = UserInfo.getSessionId();
        }

        service.SessionHeader.sessionId = adminSession;

        if(!Test.isRunningTest())
        {
            MetadataService.IReadResult readResult = service.readMetadata('Profile', profilePassed);
            MetadataService.Metadata[] records = readResult.getRecords();
            MetadataService.Profile[] profMetaList = new MetadataService.Profile[]{};

            for(MetadataService.Metadata record : records)
            {
                MetadataService.Profile profileFound = (MetadataService.Profile) record;
                profileFound.tabVisibilities = new MetadataService.ProfileTabVisibility[]{};
                System.debug('Profile Found ::: ' + profileFound.fullName);
                MetadataService.ProfileApexPageAccess pap = new MetadataService.ProfileApexPageAccess(); pap.apexPage = pageName; pap.enabled = true; profileFound.pageAccesses.add(pap); profMetaList.add(profileFound);
            }

            MetadataService.SaveResult[] sr = service.updateMetadata(profMetaList);
            System.debug('Save Result ::: ' + sr);
        }
    }

    global void finish(Database.BatchableContext BC)
    {
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

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.ToAddresses  = new string[] {a.CreatedBy.Email};
        mail.setSubject('PDF to VFP Profile Update Status:  ' + a.ApexClass.name);

        string td1 = '"border:1px solid #e6e6e6; width=200px;"';
        string td2 = '"width=200px; border:1px solid #e6e6e6; background-color:#E44905; color:white; font-weight:bold;"';
        string tdHead = '"border:1px solid #e6e6e6; width=200px; color:white; background-color:#9370DB; font-weight:bold;"';
        string ExtendedStatus = '';
        if (a.ExtendedStatus != null)
            ExtendedStatus = a.ExtendedStatus;
        string tdErrors = td1;
        if (a.NumberOfErrors > 0)
            tdErrors = td2;
        string htmlBody = '<div style="border:2px solid #e6e6e6; border-radius:10px; "><p>Hi Team,</p><p><span style="color:brown; font-weight:bolder;">The PDF to VFP Converter profile access grantor </span> completed running.'
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
        mail.setHtmlBody(htmlBody);
        mail.setPlainTextBody(htmlBody);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        mails.add(mail);
        Messaging.sendEmail(mails);

        System.debug('Exit PDF to VFP profile updater finish method');
    }
}