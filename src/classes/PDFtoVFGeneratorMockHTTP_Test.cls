@isTest
global class PDFtoVFGeneratorMockHTTP_Test implements HttpCalloutMock
{
    global HttpResponse respond(HTTPRequest req)
    {
        HttpResponse res = new HttpResponse();
        res.setStatus('OK');
        res.setStatusCode(200);
        res.setBody('Hey Baeb.');
        return res;
    }
}