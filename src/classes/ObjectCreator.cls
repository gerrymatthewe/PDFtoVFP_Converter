/**
 * Created by gerry on 8/13/2019.
 */

public with sharing class ObjectCreator
{
    //Create PDF to VFP profiles
    public static List<gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c> createPDFProfiles()
    {
        List<gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c> pdfProfiles = new List<gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c>();
        gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c pdfProfile = new gAuto__PDFtoVFP_Profiles_For_PDF_Converter__c();
        pdfProfile.gAuto__Profile_Name__c = 'Solution Manager - Custom';
        pdfProfile.Name = 'Solution Manager - Custom';
        pdfProfiles.add(pdfProfile);
        insert pdfProfiles;
        return pdfProfiles;
    }

    //Create PDF to VFP admin credentials
    public static List<gAuto__PDF_to_VFP_Admin_Credentials__c> createPDFAdminCredentials()
    {
        List<gAuto__PDF_to_VFP_Admin_Credentials__c> adminCredentials = new List<gAuto__PDF_to_VFP_Admin_Credentials__c>();
        gAuto__PDF_to_VFP_Admin_Credentials__c adminCredential = new gAuto__PDF_to_VFP_Admin_Credentials__c();
        adminCredential.gAuto__App_Authentication_Base_URL__c = 'https://login.salesforce.com/services/oauth2/token';
        adminCredential.gAuto__Client_Id__c = '3MVG9nthuDc9owbdOQHwOGRCe54kl_.9e7TIWo0AYPp8zWMXU6yp6V.D.LvUfz_yVH2OQukhAPC.KgHzvNUNJ';
        adminCredential.gAuto__Client_Secret__c = '3679621402961549684';
        adminCredential.gAuto__Grant_Type__c = 'password';
        adminCredential.gAuto__Password__c = 'MommaJune19';
        adminCredential.gAuto__Security_Token__c = 'O4OwjBWIcrpfpoFpSjW05GqAh';
        adminCredential.gAuto__Username__c = 'dennywinnie@gmail.com';
        adminCredentials.add(adminCredential);
        insert adminCredentials;
        return adminCredentials;
    }

    //Create PDF to VFP Settings records
    public static List<gAuto__PDF_to_VFP_Settings__c> createPDFSettings()
    {
        List<gAuto__PDF_to_VFP_Settings__c> pdfSettings = new List<gAuto__PDF_to_VFP_Settings__c>();
        gAuto__PDF_to_VFP_Settings__c pdfSetting = new gAuto__PDF_to_VFP_Settings__c();
        pdfSetting.gAuto__PDF_Master_CSS_File__c = 'PDFtoVFP_Default_Generated_PDF_Page_CSS';
        pdfSetting.gAuto__Apex_Version__c = '46.0';
        pdfSetting.gAuto__Content_Library_Name__c = 'PDF to VFP Library';
        pdfSettings.add(pdfSetting);
        insert pdfSettings;
        return pdfSettings;
    }

    //Create PDF Records
    public static List<gAuto__PDF__c> createPDFs(Integer dbEntries, String pdfName)
    {
        List<gAuto__PDF__c> pdfList = new List<gAuto__PDF__c>();

        for(Integer x = 0; x< dbEntries; x++)
        {
            pdfList.add(new gAuto__PDF__c(Name = pdfName + x, gAuto__Link_To_VF_Page__c = 'https://na72.salesforce.com/apex/testPage' + x, gAuto__VFPageId__c = '123456789123456'));
        }

        insert pdfList;
        return pdfList;
    }

    //Create PDFPage Records
    public static List<gAuto__PDFPage__c> createPDFPages(Integer dbEntries, String pdfPageName, String pdfRecordId)
    {
        List<gAuto__PDFPage__c> pdfPageList = new List<gAuto__PDFPage__c>();

        for(Integer x = 0; x< dbEntries; x++)
        {
            pdfPageList.add(new gAuto__PDFPage__c(Name = pdfPageName + x, gAuto__PDF__c = pdfRecordId, gAuto__Page_Number__c = x, gAuto__Image_URL__c = '/sfc/servlet.shepherd/version/download/0681H000006DppsQAC'));
        }

        insert pdfPageList;
        return pdfPageList;
    }
}