public class Mersaco_Oracle_Callout {


    public static string getToken(){
        string token ='';
        string username= 'BV6wnGWF9dBA0l7nzvzyrg..';
        string password = 'FGOjOvS5Q1tCGOnq0nRSuw..';
        string authString = username + ':' + password;
        string encodedAuthString = EncodingUtil.base64Encode(blob.valueof(authString));
        HttpRequest request= new HttpRequest ();
        request.setEndPoint('https://cloudapi.mersaco.com/merapi/oauth/token');
        request.setMethod ('POST');
        request.setHeader ('Authorization','Basic '+ encodedAuthString);
        string requestBody = 'grant_type=client_credentials';
        request.setBody (requestBody);
        request.setTimeOut(120000);

        HttpResponse response = new Http().send(request);

        if(response.getStatusCode()==200){
            // Deserialize the JSON string into collections of primitive data types.
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            token= (String) results.get('access_token');
            system.debug('StatusCode '+ response.getStatusCode());
            system.debug('Body '+ response.getBody());
            system.debug('result:'+ results);
            system.debug('token:'+ token);

        }
        else {
            system.debug('callout Failed with StatusCode '+ response.getStatusCode());

        }
        return token;
    }

        public class OrderResponse {
        public List<OrderHeader> ORDER_HEADER;
        public List<OrderDetail> ORDER_DETAIL;
    }

    public class OrderHeader {
        @AuraEnabled public String header_id;
        @AuraEnabled public String order_number;
        @AuraEnabled public Datetime order_date;
        @AuraEnabled public String order_type;
        @AuraEnabled public String salesrep;
        @AuraEnabled public String currency_code;
        @AuraEnabled public Decimal order_value;
        @AuraEnabled public String status;
    }

    public class OrderDetail {

        @AuraEnabled public String header_id;
        @AuraEnabled public String product_code;
        @AuraEnabled public String product_name;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal unit_price;
        @AuraEnabled public String tax;
        @AuraEnabled public String lot;
        @AuraEnabled public String expiry_date;
        @AuraEnabled public String invoice_number;
        @AuraEnabled public String key ;
    }

    @AuraEnabled(cacheable=true)
    public static string getOrderHeader(Id recordId){
        string bearerToken = Mersaco_Oracle_Callout.getToken();
        Account acc = [SELECT Mersaco_Account_Number__c	 FROM Account WHERE id = :recordId limit 1];
        Decimal ACC_NUM = acc.Mersaco_Account_Number__c;
        system.debug('Acc_Num:'+ ACC_NUM);
        string encodedBearerToken = EncodingUtil.base64Encode(blob.valueof(bearerToken));
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('https://cloudapi.mersaco.com/merapi/CRM_IQVIA/GET_ORDER_HISTORY?ACC_NUM='+ ACC_NUM);
        req.setMethod('GET');
        //req.setTimeOut(120000);
        httpResponse res = h.send(req);
        String responseBody = res.getBodyAsBlob().toString();
        system.debug('respnsebody '+ responseBody);
        OrderResponse data = (OrderResponse) JSON.deserialize(responseBody, OrderResponse.class);
        for (OrderDetail od : data.ORDER_DETAIL) {
            od.key = od.header_id + od.product_code + String.valueOf(od.quantity);
        }
        string orderList = JSON.serialize(data) ;
        if(res.getStatusCode()==200){
            system.debug('StatusCode '+ res.getStatusCode());
            system.debug('res' + res.getBody());
        }
        else {
            system.debug('callout Failed with StatusCode '+ res.getStatusCode());
        }
        Return orderList;
    }

    public class InvoiceResponse {
        public List<InvoiceHeader> ACCOUNT_LEVEL;
        public List<InvoiceLines> LINE_LEVEL;
    }

    public class InvoiceHeader {
        @AuraEnabled public String rep_name;
        @AuraEnabled public Decimal order_number;
        @AuraEnabled public string order_type;
        @AuraEnabled public String account_number;
        @AuraEnabled public String account_name;
        @AuraEnabled public String invoice_currency;
        @AuraEnabled public String invoice_type;
        @AuraEnabled public string invoice_date;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal amount_remaining;
    }

    public class InvoiceLines {

        @AuraEnabled public String product_code;
        @AuraEnabled public String product_name;
        @AuraEnabled public Integer quantity;
        @AuraEnabled public Decimal net_price;
        @AuraEnabled public Decimal tax;
        @AuraEnabled public String lot;
        @AuraEnabled public string expiry_date;
        @AuraEnabled public String frigo;
        @AuraEnabled public String status='';
        @AuraEnabled public String Variance_Quantity= '';
        @AuraEnabled public Id ComplaintID;
        @AuraEnabled public String key ;
        @AuraEnabled public string InvoiceNumber;
        @AuraEnabled public decimal OrderNumber;
        @AuraEnabled public Boolean ISAPI;

    }

    public class ComplaintLink {
        @AuraEnabled public String name;
        @AuraEnabled public String url;

        public ComplaintLink(String name, String url) {
            this.name = name;
            this.url = url;
        }
    }


    @AuraEnabled(cacheable=true)
    public static List<ComplaintLink> checkIfInvoiceExists(String InvNum) {
        List<Complaint__c> existingLines = [
            SELECT Id, Name
            FROM Complaint__c
            WHERE Invoice_Number__c = :InvNum
        ];

        List<ComplaintLink> complaintLinks = new List<ComplaintLink>();

        for (Complaint__c line : existingLines) {
            if (line.Id != null) {
                String url = 'https://mersaco-lb-oce--dev.sandbox.lightning.force.com/lightning/r/Complaint__c/' + line.Id + '/view';//To be replaced with production URL
                complaintLinks.add(new ComplaintLink(line.Name, url));
            }
        }

        return complaintLinks;
    }


    @AuraEnabled(cacheable=true)

    public static string getInvoices(string InvNum, string InvType, ID recordId){
        string bearerToken = Mersaco_Oracle_Callout.getToken();
        string INV_NUM = InvNum;
        string INV_Type = InvType;
       	ID Complaint_ID;
        Boolean ISAPI;
        Decimal ACC_NUM;
		Schema.SObjectType sobjectType = recordId.getSObjectType();
        System.debug('SObject Type: ' + sobjectType);
        if(sobjectType == Account.SObjectType){
        	Account acc = [SELECT Mersaco_Account_Number__c	 FROM Account WHERE id = :recordId limit 1];
        	ACC_NUM = acc.Mersaco_Account_Number__c;
        	system.debug('Acc_Num:'+ ACC_NUM);
        }
        else {
           Complaint_ID = recordId;
           Complaint__c Comp = [SELECT Account_Number__c FROM Complaint__c WHERE id = :recordId limit 1];
           ACC_NUM = Comp.Account_Number__c;
           system.debug('Complaint:'+ Complaint_ID);

        }

        string encodedBearerToken = EncodingUtil.base64Encode(blob.valueof(bearerToken));
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('https://cloudapi.mersaco.com/merapi/CRM_IQVIA/GET_INVOICE_DETAILS?ACC_NUM='+ ACC_NUM +'&INV_NUM='+INV_NUM+'&INV_TYPE='+INV_Type);
        req.setMethod('GET');
        req.setTimeOut(120000);
        httpResponse res = h.send(req);
        string responseBody = res.getBodyAsBlob().toString();
        system.debug('respnsebody '+ responseBody);
        InvoiceResponse data = (InvoiceResponse) JSON.deserialize(responseBody, InvoiceResponse.class);
        Decimal orderNum = data.ACCOUNT_LEVEL[0].order_number;
        for (InvoiceLines il : data.LINE_LEVEL) {
            il.key = il.product_code + String.valueOf(il.quantity) + String.valueOf(il.net_price);
            il.ComplaintID = Complaint_ID;
            il.InvoiceNumber = InvNum;
            il.OrderNumber = orderNum;
            il.ISAPI = true;
        }


        string InvoiceList = JSON.serialize(data) ;
        if(res.getStatusCode()==200){
            system.debug('StatusCode '+ res.getStatusCode());
            system.debug('res' + res.getBody());
            system.debug('InvoiceList '+  InvoiceList);
        }
        else {
            system.debug('callout Failed with StatusCode '+ res.getStatusCode());
        }
        Return InvoiceList;
    }

    public class CollectionResponse {
        public List<Collections> OPEN_INV;
    }

    public class Collections {
        @AuraEnabled public String client_code;
        @AuraEnabled public String account_name;
        @AuraEnabled public Decimal remaining_amount;
        @AuraEnabled public string invoice_currency_code;
        @AuraEnabled public Decimal nb_of_days_remaining;
        @AuraEnabled public String key;
    }

    @AuraEnabled(cacheable=true)
    public static string getCollections(string dueDate, ID userId){
        string bearerToken = Mersaco_Oracle_Callout.getToken();
        string User_ID = userId;
        UserTerritory2Association UT = [SELECT territory2.Name FROM UserTerritory2Association WHERE UserId = :User_ID limit 1];
        string TERRITORY_ID = UT.territory2.Name;
        string DUE_DATE = dueDate;
        string encodedBearerToken = EncodingUtil.base64Encode(blob.valueof(bearerToken));
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('https://cloudapi.mersaco.com/merapi/CRM_IQVIA/GET_OPEN_INVOICE?DUE_DATE='+DUE_DATE+'&ACC_NUM='+'&TERRITORY_ID='+TERRITORY_ID);
        system.debug('endpoint'+req.getendpoint());
        req.setMethod('GET');
        //req.setTimeOut(120000);
        httpResponse res = h.send(req);
        String responseBody = res.getBodyAsBlob().toString();
        system.debug('respnsebody '+ responseBody);
        system.debug('Original Response'+ res);
        CollectionResponse data = (CollectionResponse) JSON.deserialize(responseBody, CollectionResponse.class);
        for (Collections co : data.OPEN_INV) {
            co.key = co.client_code + co.invoice_currency_code + String.valueOf(co.remaining_amount);
        }
        string CollectionList = JSON.serialize(data) ;
        if(res.getStatusCode()==200){
            system.debug('StatusCode '+ res.getStatusCode());
            system.debug('res' + res.getBody());
            system.debug('OpenInvoiceList '+  CollectionList);
        }
        else {
            system.debug('callout Failed with StatusCode '+ res.getStatusCode());
        }
        Return CollectionList;
    }

    @AuraEnabled(cacheable=true)
    public static string getAccountCollection(ID recordId, string dueDate, ID userId){
        string bearerToken = Mersaco_Oracle_Callout.getToken();
        string User_ID = userId;
        UserTerritory2Association UT = [SELECT territory2.Name FROM UserTerritory2Association WHERE UserId = :User_ID limit 1];
        string TERRITORY_ID = UT.territory2.Name;
        Account acc = [SELECT Mersaco_Account_Number__c  FROM Account WHERE id = :recordId limit 1];
        Decimal ACC_NUM = acc.Mersaco_Account_Number__c;
        string DUE_DATE = dueDate;
        string encodedBearerToken = EncodingUtil.base64Encode(blob.valueof(bearerToken));
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('Authorization', 'Bearer ' + bearerToken);
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('https://cloudapi.mersaco.com/merapi/CRM_IQVIA/GET_OPEN_INVOICE?DUE_DATE='+DUE_DATE+'&ACC_NUM='+ACC_NUM+'&TERRITORY_ID='+TERRITORY_ID);
        system.debug('endpoint'+req.getendpoint());
        req.setMethod('GET');
        //req.setTimeOut(120000);
        httpResponse res = h.send(req);
        String responseBody = res.getBodyAsBlob().toString();
        system.debug('respnsebody '+ responseBody);
        system.debug('Original Response'+ res);
        CollectionResponse data = (CollectionResponse) JSON.deserialize(responseBody, CollectionResponse.class);
        for (Collections co : data.OPEN_INV) {
            co.key = co.client_code + co.invoice_currency_code + String.valueOf(co.remaining_amount);
        }
        string CollectionList = JSON.serialize(data) ;
        if(res.getStatusCode()==200){
            system.debug('StatusCode '+ res.getStatusCode());
            system.debug('res' + res.getBody());
            system.debug('OpenInvoiceList '+  CollectionList);
        }
        else {
            system.debug('callout Failed with StatusCode '+ res.getStatusCode());
        }
        Return CollectionList;
    }

}
