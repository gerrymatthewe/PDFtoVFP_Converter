/**
 * Created by gerry on 8/12/2019.
 */

public with sharing class PDFtoVFP_MultiRequestMock implements HttpCalloutMock
{
        Map<String, PDFtoVFP_HTTP_Callout_Mock> requests;

        public PDFtoVFP_MultiRequestMock(Map<String, PDFtoVFP_HTTP_Callout_Mock> requests)
        {
            this.requests = requests;
        }

        public HTTPResponse respond(HTTPRequest req)
        {
            PDFtoVFP_HTTP_Callout_Mock mock = requests.get(req.getEndpoint());
            if (mock != null)
            {
                return mock.respond(req);
            }
            else
            {
                System.debug('Multi Mock Failure');
                return null;
            }
        }
}