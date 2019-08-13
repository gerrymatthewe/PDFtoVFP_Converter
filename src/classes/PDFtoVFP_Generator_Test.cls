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

    public static testMethod void testConstruction()
    {
        Test.StartTest();
            PDFtoVFP_Generator vfpGenerator = new PDFtoVFP_Generator();
        Test.StopTest();
    }

    public static testMethod void insertPDF()
    {
        Test.StartTest();
            ObjectCreator.createPDFs(1, 'Test');
            PDFtoVFP_Generator.insertPDF('JohnStamos');
            PDFtoVFP_Generator.insertPDF('Test0');
        Test.StopTest();
    }

    public static testMethod void insertPDFPages()
    {
        Test.StartTest();
            List<gAuto__PDF__c> pdfList = ObjectCreator.createPDFs(1, 'TestBoiz');
            PDFtoVFP_Generator.insertPDFPage('Page1', pdfList[0].Id, '1', '/sfc/servlet.shepherd/version/download/0681H000006DppsQAC');
        Test.StopTest();
    }

    public static testMethod void insertContentFolder()
    {
        Test.StartTest();
            Id folderId = PDFtoVFP_Generator.insertFolder('Dolongo');
            PDFtoVFP_Generator.insertContentDocument('Dolongo', 1, 'chocolate', folderId);
        Test.StopTest();
    }
}