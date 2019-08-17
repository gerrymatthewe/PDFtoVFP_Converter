@isTest
public class PDFtoVFP_HTTP_Callout_Mock
{
    protected Integer code;
    protected String status;
    protected String bodyAsString;
    protected Blob bodyAsBlob;
    protected Map<String, String> responseHeaders;

    public PDFtoVFP_HTTP_Callout_Mock(Integer code, String status, String body, Map<String, String> responseHeaders)
    {
        this.code = code;
        this.status = status;
        this.bodyAsString = body;
        this.bodyAsBlob = null;
        this.responseHeaders = responseHeaders;
    }

    public HttpResponse respond(HTTPRequest req)
    {
        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(code);
        resp.setStatus(status);
        resp.setBody(bodyAsString);

        if (responseHeaders != null)
        {
            for (String key : responseHeaders.keySet())
            {
                resp.setHeader(key, responseHeaders.get(key));
            }
        }

        return resp;
    }

    public static HttpCalloutMock generateToolingMock(Integer authResponseCode, String authResponseMsg, String authResponseBody, Integer mockCode, String mockResponseMsg, String mockResponseBody, String apexPageId)
    {
        String toolingURL = URL.getSalesforceBaseUrl().toExternalForm() + '/services/data/v35.0/sobjects/ApexPage';

        if(apexPageId != null)
        {
            toolingURL +=  '/' + apexPageId;
        }

        Map<String, String> authHeaders = new Map<String, String>();
        authHeaders.put('Content-Type', 'application/x-www-form-urlencoded');
        PDFtoVFP_HTTP_Callout_Mock authResponse = new PDFtoVFP_HTTP_Callout_Mock(authResponseCode, authResponseMsg, authResponseBody, authHeaders);

        Map<String, String> getHeaders = new Map<String, String>();
        getHeaders.put('Content-Type', 'application/json');
        getHeaders.put('Authorization', 'Bearer 00D1H000000Mzke!ARgAQC1mQ_3AXRbp5SCFneXWhlRTHYstC4tMrtWwhCwBIYFMoyF7m.0ne.d_vM5NxyuQATxGrf.aVX7hOhSh2djhm3BKAhqf');
        PDFtoVFP_HTTP_Callout_Mock toolingResponse = new PDFtoVFP_HTTP_Callout_Mock(mockCode, mockResponseMsg, mockResponseBody, getHeaders);

        System.debug('Tooling URL ::: ' + toolingURL);

        Map<String, PDFtoVFP_HTTP_Callout_Mock> tooling_Mock_Endpoints = new Map<String, PDFtoVFP_HTTP_Callout_Mock>();
        tooling_Mock_Endpoints.put('https://login.salesforce.com/services/oauth2/token?grant_type=password&client_secret=3679621402961549684&client_id=3MVG9nthuDc9owbdOQHwOGRCe54kl_.9e7TIWo0AYPp8zWMXU6yp6V.D.LvUfz_yVH2OQukhAPC.KgHzvNUNJ&username=dennywinnie@gmail.com&password=MommaJune19O4OwjBWIcrpfpoFpSjW05GqAh&format=json', authResponse);
        tooling_Mock_Endpoints.put(toolingURL, toolingResponse);

        HttpCalloutMock cemsCallouts = new PDFtoVFP_MultiRequestMock(tooling_Mock_Endpoints);
        return cemsCallouts;
    }

    public static String generateAdminSession_Response()
    {
        String response = '';
        response = '{'+
                '"access_token": "00D1H000000Mzke!ARgAQC1mQ_3AXRbp5SCFneXWhlRTHYstC4tMrtWwhCwBIYFMoyF7m.0ne.d_vM5NxyuQATxGrf.aVX7hOhSh2djhm3BKAhqf",' +
                '"instance_url": "https://na72.salesforce.com",' +
                '"id": "https://login.salesforce.com/id/00D1H000000MzkeUAC/0051H000007UPhHQAW",' +
                '"token_type": "Bearer",' +
                '"issued_at": "1565671074062",' +
                '"signature": "L+HFE07LndeicVOAjO0YMU/p8VHjcqyrCB2ce6ZxS+0="' +
                '}';
        return response;
    }

    public static String generateVFPage_ToolingAPI_Body()
    {
        String returnMsg = '{' +
                '"Name" : "DonkeyLong",' +
                '"Markup" : "<apex:page><html></html></apex:page>",' +
                '"ControllerType" : "0",' +
                '"MasterLabel" : "Jambette",' +
                '"ApiVersion" : "45.0"' +
                '}';

        return returnMsg;
    }

    public static String generateVFPage_ToolingAPI_Response()
    {
        String response = '';
        response = '{' +
        '"id": "0661H0000032oVBQAY",' +
        '"success": true,' +
        '"errors": []' +
        '}';
        return response;
    }
}