@RestResource(urlMapping='/HttpPostExample/*')
global class HttpPostExample 
{
	@HttpPost 
    global static String CreateAPDF(String pdfId)
    {
        HttpPostExample.createVFP(pdfId);
        return 'New PDF Id: ' + pdfId;
    }
    
    global static void createVFP(String pdfId)
    {
		PDFtoVFGenerator.VFToolingManager(pdfId);        
    }
}