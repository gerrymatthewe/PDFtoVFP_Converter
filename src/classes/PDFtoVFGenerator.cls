/*
 * Class created to produce a vf page based on the contents of a pdf. It's the controller for the PDFHomePage.
 * Created by: Matt Gerry -- 06/17/2018
 */

global class PDFtoVFGenerator
{
    public List<String> profileNames {get; set;}
    public String sfURL {get;set;}

    public static String salesforceHost = System.Url.getSalesforceBaseURL().toExternalForm();
    public static String url =  salesforceHost + '/services/data/v35.0/sobjects/ApexPage';
    public static String[] profilesToUpdate;
    public static Boolean folderCreated = false;
    public static String folderId;
    
    public PDFtoVFGenerator()
    {
        profileNames = GetProfileNames();
        sfURL = ApexPages.currentPage().getHeaders().get('Host');
    }
    
    public List<String> GetProfileNames()
    {
        List<String> profNames = new List<String>();
        List<gAuto__Profiles_For_PDF_Converter__c> profs = [SELECT gAuto__Profile_Name__c FROM gAuto__Profiles_For_PDF_Converter__c ORDER BY Name];
        
        for(gAuto__Profiles_For_PDF_Converter__c prof: profs)
        {
            profNames.add(prof.gAuto__Profile_Name__c);
        }
        
        return profNames;
    }

    @RemoteAction
    webservice static String insertPDF(String pdfName)
    {
        List<gAuto__PDF__c> pdfsFound = [SELECT Id FROM gAuto__PDF__c WHERE Name = :pdfName];

        if(pdfsFound.isEmpty())
        {
            gAuto__PDF__c newPDF = new gAuto__PDF__c(name = pdfName);
            insert newPDF;
            return newPDF.Id;
        }
        else
        {
            return 'duplicate';
        }
    }

    @RemoteAction
    webservice static String insertFolder(String pdfName)
    {
        List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = 'PDF to VFP Library' LIMIT 1];

        if(!workspaceLibraries.isEmpty())
        {
            List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id LIMIT 1];

            if(!workspaceLibraryLink.isEmpty())
            {
                if(!PDFtoVFGenerator.folderCreated)
                {
                    ContentFolder newFolder = new ContentFolder();
                    newFolder.Name = pdfName;
                    newFolder.ParentContentFolderId = workspaceLibraryLink[0].ContentFolderId;
                    insert newFolder;
                    return newFolder.Id;
                }
            }
        }

        return null;
    }


    @RemoteAction
    webservice static String insertContentDocument(String pdfName, Integer imgNum, String fileContent, Id folderId)
    {
        List<ContentWorkspace> workspaceLibraries = [SELECT Id FROM ContentWorkspace WHERE Name = 'PDF to VFP Library' LIMIT 1];

        if(!workspaceLibraries.isEmpty())
        {
            List<ContentFolderLink> workspaceLibraryLink = [SELECT Id, ContentFolderId, ParentEntityId FROM ContentFolderLink WHERE ParentEntityId = :workspaceLibraries[0].Id LIMIT 1];

            if(!workspaceLibraryLink.isEmpty())
            {
                ContentVersion newDocument = new ContentVersion();
                newDocument.VersionData = EncodingUtil.base64Decode(fileContent);
                newDocument.Title = pdfName + imgNum;
                newDocument.ContentLocation = 'S';
                newDocument.PathOnClient = pdfName + imgNum  + '.png';
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

                    if (!newDocumentFolderMembership.isEmpty())
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
        return null;
    }

    @RemoteAction
    webservice static void insertPDFPage(String pageName, Id pdfId, String pageNum, String imageURL)
    {
        gAuto__PDFPage__c newPdfPage = new gAuto__PDFPage__c();
        newPdfPage.Name = pageName;
        newPdfPage.PDF__c = pdfId;
        newPdfPage.Page_Number__c = Decimal.valueOf(pageNum);
        newPdfPage.Image_URL__c = imageURL;
        insert newPdfPage;
    }
    
    //Method used to construct the vf page body based on the content of the pdf uploaded.
    @RemoteAction
    webservice static void VFToolingManager(Id pageId, String selectedProfiles)
    {
        PDFtoVFGenerator.profilesToUpdate = selectedProfiles.split(',');
        gAuto__PDF_to_VFP_Settings__c pdfSettings = gAuto__PDF_to_VFP_Settings__c.getOrgDefaults();

        System.debug('Profiles ::: ' + PDFtoVFGenerator.profilesToUpdate);
        
        //Setting up the base for the html body of the vf page
        String vfBody = '<apex:page applyHtmlTag=\\"true\\" docType=\\"html-5.0\\" showHeader=\\"false\\" sidebar=\\"false\\" standardStylesheets=\\"false\\"> \\n <html> ';
        
        //Searching for our pdf, setting up the base of our css, searching for pdfPages
        gAuto__PDF__c pdfFound = [SELECT Id, gAuto__VFPageId__c, Name, gAuto__Background_Color__c, gAuto__Page_Numbers__c FROM gAuto__PDF__c WHERE Id = :pageId];
        vfBody = vfBody + '\\n \\t <head>  \\n \\t \\t <apex:stylesheet value=\\"{!$Resource.' + pdfSettings.gAuto__PDF_Master_CSS_File__c + '}\\"/> \\n \\t</head> \\n \\n \\t <body class=\\"pdfContainer\\"> \\n \\t \\t <div class=\\"pageContainer\\"><!--divAdd--> \\n \\t \\t </div> \\n \\t </body>';
        List<gAuto__PDFPage__c> pdfPages = [SELECT Id, Name, gAuto__Page_Number__c, gAuto__PDF__c, gAuto__Image_URL__c FROM gAuto__PDFPage__c WHERE gAuto__PDF__c = :pageId ORDER BY gAuto__Page_Number__c ASC];
        System.debug('Pages :::' + pdfPages.size());
        
        //For all pdf pages add relevant css, add divs and add their ids to the set so we can gather page elements later
        for(gAuto__PDFPage__c page: pdfPages)
        {
            vfBody = vfBody.replace('<!--divAdd-->', '\\n \\t \\t \\t <div class=\\"page\\"> \\n \\t \\t \\t \\t <div class=\\"pageElement\\"> \\n \\t \\t \\t \\t \\t <img src=\\"' + page.gAuto__Image_URL__c + '\\"/> \\n \\t \\t \\t \\t</div> \\n \\t \\t \\t</div> <!--divAdd-->');
        }
        
        //Put in remaining closing tags
        vfBody = vfBody + '\\n </html> \\n</apex:page>';
        
        //If a page has already been created, delete it.
        if(pdfFound.VFPageId__c != null)
        {
            PDFtoVFGenerator.deleteVFPage(pdfFound.gAuto__VFPageId__c);
        }
        
        //Create the new vf page
        PDFtoVFGenerator.createVFPage(vfBody, pdfFound.Name, pdfFound);
    }

    @RemoteAction
    webservice static void deletePDFFiles(Id pdfId)
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

                delete pdfList;
            }
        }
    }

    webservice static void deleteContentDocuments(String pdfName)
    {
        List<ContentFolder> folderList = [SELECT Id FROM ContentFolder WHERE Name = :pdfName];

        if(!folderList.isEmpty())
        {
            List<ContentFolderMember> folderMembers = [SELECT ParentContentFolderId, ChildRecordId FROM ContentFolderMember WHERE ParentContentFolderId = :folderList[0].Id];
            Set<Id> documentIds = new Set<Id>();

            if (!folderMembers.isEmpty())
            {
                for (ContentFolderMember folderMember : folderMembers)
                {
                    documentIds.add(folderMember.ChildRecordId);
                }

                List<ContentDocument> contentDocs = [SELECT Id FROM ContentDocument WHERE Id IN:documentIds];
                if (!contentDocs.isEmpty())
                {
                    delete contentDocs;
                }
            }

            delete folderList;
        }
    }
    
    //Method used to delete outdated vf page using the tooling api
    webservice static void deleteVFPage(String pageId)
    {
        HttpRequest req = new HttpRequest();
        String deleteURL = url+'/' + pageId ;
        req.setMethod('DELETE');
        req.setEndpoint(deleteURL);
        req.setHeader('Content-type', 'application/json');
        String adminSession = RunPDFGenAsAdmin.getAdminSessionId();
        req.setHeader('Authorization', 'Bearer ' + adminSession);
        Http http = new Http();
        
        if(!Test.isRunningTest())
        {
            HTTPResponse res = http.send(req);
            System.debug(res.getBody());
        }
    }
    
    //Method used to create our new vf page using the tooling api
    webservice static void createVFPage(String pageBody, String pageName, gAuto__PDF__c pageToUpdate)
    {
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(url);
        req.setHeader('Content-type', 'application/json');
        String adminSession = RunPDFGenAsAdmin.getAdminSessionId();
        req.setHeader('Authorization', 'Bearer ' + adminSession);
        //for controllerType = >0 -- no controller
        req.setBody('{"Name" : "' + pageName.replaceAll('\\s+', '') + '","Markup" : "'+ pageBody +'","ControllerType" : "0","MasterLabel":"'+pageName+'","ApiVersion":"43.0"}');         
        Http http = new Http();
        System.debug('body ::: ' +pageBody);
        
        if(!Test.isRunningTest())
        {
            HTTPResponse res = http.send(req);
            System.debug(res.getBody());
            String vfPageId = res.getBody().substringBetween('{"id":"','","');
            pageToUpdate.VFPageId__c = vfPageId;
        }
        
        pageToUpdate.Link_To_VF_Page__c = salesforceHost+'/apex/'+pageName.replaceAll('\\s+', '');
        
        
        PDFtoVFGenerator.updateProfilePageAccess(pageName, pageToUpdate);
    }

    //Method used to interact with the metadata API and create profile access for the new VF page
    webservice static void updateProfilePageAccess(String pageName, gAuto__PDF__c pageToUpdate)
    {
        //If you're not a system admin, add current user profile to the list of profiles to update
        Profile prof = [SELECT Id, Name FROM Profile WHERE Id = :UserInfo.getProfileId()];
        System.debug('Profile Name ::: ' + prof.Name);

        if(prof.Name != 'System Administrator')
        {
            PDFtoVFGenerator.profilesToUpdate.add(prof.Name);
        }

        Boolean pageEnabled = false;
        MetadataService.MetadataPort service = new MetadataService.MetadataPort();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = RunPDFGenAsAdmin.getAdminSessionId();
        MetadataService.IReadResult readResult = service.readMetadata('Profile', PDFtoVFGenerator.profilesToUpdate);
        MetadataService.Metadata[] records = readResult.getRecords();
        MetadataService.Profile[] profMetaList = new MetadataService.Profile[]{};

        for(MetadataService.Metadata record: records)
        {
            pageEnabled = false;
            MetadataService.Profile profileFound = (MetadataService.Profile)record;
            profileFound.tabVisibilities = new MetadataService.ProfileTabVisibility[] {};
            System.debug('Profile Found ::: ' + profileFound.fullName);
            MetadataService.ProfileApexPageAccess pap = new MetadataService.ProfileApexPageAccess();
            pap.apexPage = pageName;
            pap.enabled = true;
            profileFound.pageAccesses.add(pap);
            profMetaList.add(profileFound);

        }

        MetadataService.SaveResult[] sr = service.updateMetadata(profMetaList);
        System.debug('Save Result ::: ' + sr);
        update pageToUpdate;
    }
    
}