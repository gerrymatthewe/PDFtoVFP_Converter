/**
 * Created by gerry on 8/13/2019.
 */
@isTest
public with sharing class PDFtoVFP_Generator_Test
{
    @TestSetup
    public static void setupTestData()
    {
        ObjectCreator.createPDFProfiles();
        ObjectCreator.createPDFAdminCredentials();
        ObjectCreator.createPDFSettings();
    }

    public static testMethod void constructor_Test()
    {
        Test.StartTest();
            PDFtoVFP_Generator vfpGenerator = new PDFtoVFP_Generator();
        Test.StopTest();
    }

    public static testMethod void insertPDF_Test()
    {
        Test.StartTest();
            ObjectCreator.createPDFs(1, 'Test');
            PDFtoVFP_Generator.insertPDF('JohnStamos');
            PDFtoVFP_Generator.insertPDF('Test0');
        Test.StopTest();
    }

    public static testMethod void insertPDFPages_TEST()
    {
        Test.StartTest();
            List<gAuto__PDF__c> pdfList = ObjectCreator.createPDFs(1, 'TestBoiz');
            PDFtoVFP_Generator.insertPDFPage('Page1', pdfList[0].Id, '1', '/sfc/servlet.shepherd/version/download/0681H000006DppsQAC');
        Test.StopTest();
    }

    public static testMethod void insertContentFolder_Test()
    {
        Test.StartTest();
            Id folderId = PDFtoVFP_Generator.insertFolder('Dolongo');
            PDFtoVFP_Generator.insertContentDocument('Dolongo', 1, 'chocolate', folderId);
        Test.StopTest();
    }

    public static testMethod void insertVFP_Test()
    {
        HttpCalloutMock insertVFPCallout = PDFtoVFP_HTTP_Callout_Mock.generateToolingMock(200, 'OK', PDFtoVFP_HTTP_Callout_Mock.generateAdminSession_Response(), 200, 'OK', PDFtoVFP_HTTP_Callout_Mock.generateVFPage_ToolingAPI_Response(), null);
        Test.setMock(HttpCalloutMock.class, insertVFPCallout);
        List<gAuto__PDF__c> pdfList = ObjectCreator.createPDFs(1, 'TestBoiz');
        pdfList[0].VFPageId__c = null;
        update pdfList;

        ObjectCreator.createPDFPages(1, 'HiThur', pdfList[0].Id);

        Test.startTest();
            PDFtoVFP_Generator.VFToolingManager(pdfList[0].Id, 'Solution Manager - Custom');
        Test.stopTest();
    }

    public static testMethod void getPDFs_Test()
    {
        Test.startTest();
            List<gAuto__PDF__c> pdfList = ObjectCreator.createPDFs(1, 'TestBoiz');
            PDFtoVFP_Generator.getPDFs();
        Test.stopTest();
    }

    public static testMethod void deletePDFs_Test()
    {
        HttpCalloutMock insertVFPCallout = PDFtoVFP_HTTP_Callout_Mock.generateToolingMock(200, 'OK', PDFtoVFP_HTTP_Callout_Mock.generateAdminSession_Response(), 204, 'No Content', '{}', '123456789123456');
        Test.setMock(HttpCalloutMock.class, insertVFPCallout);
        List<gAuto__PDF__c> pdfList = ObjectCreator.createPDFs(1, 'TestBoiz');

        Test.startTest();
            PDFtoVFP_Generator.deletePDFFiles(pdfList[0].Id);
        Test.stopTest();
    }
}