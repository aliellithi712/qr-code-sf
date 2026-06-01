/**
 * Controller used by the public site to fetch weather data and render
 * account record PDFs via a signed URL.
 */
public without sharing class SitePdfController {
    
    // This secret key MUST match the exact key used when you generated the QR code signature
    private static final String PRIVATE_KEY_HEX = 'a8fe3007b37b5e6474a7c5a42f35e637';
    private static final Blob SECRET_KEY = EncodingUtil.convertFromHex(PRIVATE_KEY_HEX);

    /**
     * Decrypt Method to get city from encrypted input.
     * @param input The encrypted string containing account ID and city
     * @return city The decrypted city name
     */
    @AuraEnabled(cacheable=true)
    public static string getCity(String input) {
        Id accountId = null;
        String city = null;
        Blob encryptedBlob = EncodingUtil.convertFromHex(input);
        Blob tempDecryptedBlob = Crypto.decryptWithManagedIV('AES128', SECRET_KEY, encryptedBlob);
        String decryptedBlob = tempDecryptedBlob.toString();
        List<String> splitValues = decryptedBlob.split('\\|');
        if (splitValues.size() >= 2) {
            accountId = (Id)splitValues[0].trim();
            city = splitValues[1].trim();
        }
        return city;

    }


    
    /**
     * Call the weather api and return weather data to the PDF viewer LWC.
     * @return WeatherData response from the weather API.
     */
    @AuraEnabled(cacheable=true)
    public static WeatherData getWeatherData(String Location) {
        Weather_Setting__mdt config = Weather_Setting__mdt.getInstance('Default_Config');
        if (config == null) {
            throw new AuraHandledException('Custom Metadata record missing.');
        }
        
        // Reconstructing truncated key as established earlier
        String fullKey = config.Key__c; 
        // String location = config.Q__c;
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:weather?key=' + fullKey + '&q=' + EncodingUtil.urlEncode(location, 'UTF-8'));
        req.setMethod('GET');
        
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Deserialize the response straight into our Apex wrapper structure
                return (WeatherData) JSON.deserialize(res.getBody(), WeatherData.class);
            } else {
                throw new AuraHandledException('Weather API Error: ' + res.getBody());
            }
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Weather Data */
    public class WeatherData {
        /**  Location of the weather. */
        @AuraEnabled public LocationInfo location { get; set; }
        /** Info of the weather of the weather API */
        @AuraEnabled public CurrentInfo current { get; set; }
    }

    public class LocationInfo {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String localtime { get; set; }
    }

    public class CurrentInfo {
        @AuraEnabled public Decimal temp_c { get; set; }
        @AuraEnabled public Integer humidity { get; set; }
        @AuraEnabled public Decimal wind_kph { get; set; }
        @AuraEnabled public ConditionInfo condition { get; set; }
    }

    /**
     * Condition data structure returned by the weather API.
     */
    public class ConditionInfo {
        /** The human-readable weather condition text returned by the API. */
        @AuraEnabled public String text { get; set; }
        /** The URL or path to the weather condition icon returned by the API. */
        @AuraEnabled public String icon { get; set; }
    }



    /** 
    @AuraEnabled
    public static String getAccountPdfBase64(Id recordId, String urlSignature) {
        try {
            // 1. SECURITY GATE: Recompute the expected SHA-256 hash pattern
            Blob targetBlob = Blob.valueOf(recordId + SECRET_KEY);
            Blob hash = Crypto.generateDigest('SHA-256', targetBlob);
            String expectedSignature = EncodingUtil.convertToHex(hash);
            
            // 2. VERIFY MATCH: Block execution instantly if parameters don't line up
            if (urlSignature == null || !urlSignature.equals(expectedSignature)) {
                throw new AuraHandledException('ACCESS DENIED: The security signature token is invalid or has been modified.');
            }
            
            // 3. ID VERIFIED SAFE: Proceed to render the Visualforce asset
            // Generate the absolute URL to the page via your public site domain
            String siteUrl = 'https://resourceful-moose-gu6rll-dev-ed.trailblaze.my.site.com/testcomplaint/apex/AccountPDF?id=' + recordId;
            
            PageReference pdfPage = new PageReference(siteUrl); 
            Blob pdfBlob;
            
            // if (Test.isRunningTest()) {
                // pdfBlob = Blob.valueOf('Test PDF Content');
            // } else {
                pdfBlob = pdfPage.getContent();
            // }
            
            return EncodingUtil.base64Encode(pdfBlob);
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
        */
}