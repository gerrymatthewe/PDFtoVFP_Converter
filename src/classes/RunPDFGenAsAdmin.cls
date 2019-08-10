global class RunPDFGenAsAdmin 
{
    webservice static string getAdminSessionId()
    {
        gAuto__PDF_to_VFP_Admin_Credentials__c appLogin = gAuto__PDF_to_VFP_Admin_Credentials__c.getOrgDefaults();
        String sessionId = '';
        
        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(appLogin.gAuto__App_Authentication_Base_URL__c + '?grant_type='+ appLogin.gAuto__Grant_Type__c +'&client_secret='+appLogin.gAuto__Client_Secret__c+'&client_id='+appLogin.gAuto__Client_Id__c+'&username='+appLogin.gAuto__Username__c+'&password='+appLogin.gAuto__Password__c+appLogin.gAuto__Security_Token__c+'&format=json');
        
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        Http http = new Http();
        

        HTTPResponse res = http.send(req);
        System.debug('appResponse ::: '+res.getBody());
        
        String response = res.getBody();
        sessionId = response.substringBetween('{"access_token":"', '","');
        System.debug('token:::' + sessionId);
        return sessionId;
    }
}