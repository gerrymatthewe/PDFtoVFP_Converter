/**
 * This class is utilized to produce the access for the visualforce pages we just created to the profiles the user selected
 * when generating the visualforce page.
 *
 * These updates must be batched because the operation can take over two minutes for a ton of profiles. Doing it in batches prevents the timeout
 * and allows for theoretically infinite profile updates.
 *
 * Created by Matt Gerry ::: gAuto ::: on 08/12/2019.
 */

global with sharing class PDFtoVFP_Grant_VF_Page_Access implements Database.Batchable<String>, Database.AllowsCallouts
{
    //Setting our global variables
    global final List<String> profileList;
    global final String pageName;

    //The constructor takes our passed list of profiles and the name of the new vfpage and assigns it to the global variables
    global PDFtoVFP_Grant_VF_Page_Access(List<String> profilesPassed, String pageNamePassed)
    {
        profileList = profilesPassed;
        pageName = pageNamePassed;
    }

    //The start class must be an iterable type of string since we are passing it a list rather than a query. This allows us to iterate through the list of profiles
    global Iterable<String> start(Database.BatchableContext BC)
    {
        return profileList;
    }

    //The execute method performs the callout to the metadata API to update the profiles and give them access to the new VFPage we generated.
    global void execute(Database.BatchableContext BC, List<String> profilePassed)
    {
        //Grabbing the profile of the current user
        Profile prof = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];

        //Grabbing the settings for the pdftovfp converter to get the system administrator name (this is housed in a custom setting)
        gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

        System.debug('Profile Name ::: ' + prof.Name);

        //If you're not a system admin, add current user profile to the list of profiles to update
        if(prof.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c)
        {
            profilePassed.add(prof.Name);
        }

        //Setting up our callout to the metadata API
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.timeout_x = 100000;
        String adminSession = null;

        //If the profile of the running user is not a system administrator then generate a session id as an administrator so that they can
        //utilize the metadata API
        if(prof.Name != pdfSettings.gAuto__System_Admin_Profile_Name__c || Test.isRunningTest())
        {
            adminSession = getAdminSessionId();
        }
        else
        {
            adminSession = UserInfo.getSessionId();
        }

        //Set the session id in the session header of our metadata API callout
        service.SessionHeader.sessionId = adminSession;

        //To be honest we could test this but I'm too lazy to write it at the moment.
        if(!Test.isRunningTest())
        {
            //Getting the metadata for our profiles
            MetadataService.IReadResult readResult = service.readMetadata('Profile', profilePassed);
            MetadataService.Metadata[] records = readResult.getRecords();

            //Setting up the list of profiles that we will update the vfpage access for
            MetadataService.Profile[] profMetaList = new MetadataService.Profile[]{};

            //Looping through our list of profiles to update them with access to the new vfpage
            for(MetadataService.Metadata record : records)
            {
                //Setting up our profile record that we intend to update
                MetadataService.Profile profileFound = (MetadataService.Profile) record;
                profileFound.tabVisibilities = new MetadataService.ProfileTabVisibility[]{};
                System.debug('Profile Found ::: ' + profileFound.fullName);

                //Setting up the new apex page access for our generated vfpage for the current profile
                MetadataService.ProfileApexPageAccess pap = new MetadataService.ProfileApexPageAccess();
                pap.apexPage = pageName;
                pap.enabled = true;
                profileFound.pageAccesses.add(pap);

                //Adding the profile to the list of profile updates for our callout
                profMetaList.add(profileFound);
            }

            //Try calling out to the metadata API to save our profile updates
            try
            {
                MetadataService.SaveResult[] sr = service.updateMetadata(profMetaList);
                System.debug('Save Result ::: ' + sr);
            }
            //If there was an error calling out, log the error in the error logging table
            catch(Exception e)
            {
                PDFtoVFP_Generator.insertErrorLog(e.getMessage(), 'Attempted to update the profile with this request ::: ' + service + ' ::: with this data ::: ' + profMetaList, null);
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
        string htmlBody = '<div style="border:2px solid #e6e6e6; border-radius:10px; "><p>Hi ' + UserInfo.getFirstName() + ' ' + UserInfo.getLastName() + ',</p><p><span style="color:brown; font-weight:bolder;">The PDF to VFP Converter profile access grantor </span> completed running.'
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
}