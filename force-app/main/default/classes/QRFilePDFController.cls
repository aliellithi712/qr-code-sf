public with sharing class QRFilePDFController {
    
    // This is a valid, pre-computed 256-bit (32-byte) cryptographically secure Base64 key
    private static final String PRIVATE_KEY_HEX = 'a8fe3007b37b5e6474a7c5a42f35e637';
    private static final Blob SECRET_KEY = EncodingUtil.convertFromHex(PRIVATE_KEY_HEX);

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getSignedSiteUrl(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException('Missing Record ID.');
            }

            if (!Schema.sObjectType.Account.isAccessible() ||
                !Schema.sObjectType.Account.fields.long_conversion__c.isAccessible()) {
                throw new AuraHandledException('Insufficient permissions to access Account or field data.');
            }

            Account acct = [SELECT long_conversion__c FROM Account WHERE Id = :recordId LIMIT 1];
            String cities = acct.long_conversion__c;
            List<String> cityList = new List<String>();

            if (String.isNotBlank(cities)) {
                // Collect unique, trimmed cities into a list to pull by positional index
                Set<String> citySet = new Set<String>();
                for (String city : cities.split(',')) {
                    citySet.add(city.trim());
                }
                cityList.addAll(citySet);
            }

            // Ensure we have at least 2 cities to fulfill the request
            if (cityList.size() < 2) {
                throw new AuraHandledException('The account record must contain at least two comma-separated cities.');
            }

            String cleanIdStr = String.valueOf((Id)recordId);
            String baseUrl = 'resourceful-moose-gu6rll-dev-ed.trailblaze.my.site.com/testcomplaint/s?e=';
            Map<String, String> cityUrlMap = new Map<String, String>();


            for (String city : cityList) {
                if (String.isBlank(city)) {
                    continue;
                }
                // 1. Create payload combining recordId and the specific loop city
                String payload = cleanIdStr + '|' + city; 
                
                // 2. Encrypt the payload string
                
                Blob encryptedBlob = Crypto.encryptWithManagedIV('AES128', SECRET_KEY, Blob.valueOf(payload));
                String encryptedHex = EncodingUtil.convertToHex(encryptedBlob);
                String finalUrl = baseUrl + encryptedHex;
                
                // 3. Store into the map with the city name as the key
                cityUrlMap.put(city, finalUrl);
            }
        return cityUrlMap;
            
        } catch(Exception e) {
            throw new AuraHandledException('Failed to generate valid secure link: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void saveQRCodeFile(Id recordId, String base64Data,String cityName) {
        try {
            String fileName = cityName + '_QRCode.png';
            
            // 1. Check if the QR Code file already exists for this record
            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId 
                AND ContentDocument.Title = :fileName
                LIMIT 1
            ];
            
            // 2. If it exists, stop completely and return without doing any DML operations
            if (!existingLinks.isEmpty()) {
                System.debug('QR Code file already exists. Replacing with new version...');
                ContentDocument oldDoc = new ContentDocument(Id = existingLinks[0].ContentDocumentId);
                delete oldDoc;
                return; 
            }
            
            // 3. If it does not exist, insert the new file
            Blob filePayload = EncodingUtil.base64Decode(base64Data);
            
            ContentVersion newCv = new ContentVersion();
            newCv.Title = fileName;
            newCv.PathOnClient = fileName;
            newCv.VersionData = filePayload;
            newCv.IsMajorVersion = true;
            insert newCv;
            
            Id contentDocId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :newCv.Id
            ].ContentDocumentId;
            
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
            
            System.debug('New QR Code created successfully.');
            
        } catch (Exception e) {
            throw new AuraHandledException('Error saving QR Code: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void cacheQRCode(String base64Data, String cityName) {
        try {
            if (String.isBlank(base64Data)) {
                throw new AuraHandledException('Base64 string cannot be empty');
            }

            // Get the 'qrCodeCache' partition
            // Format is: Cache.Org.getPartition('PartitionName')
            Cache.OrgPartition orgPart = Cache.Org.getPartition('local.qrCodeCache');
            
            // Generate a unique key or use a session identifier (e.g., 'current_qr')
            String cacheKey = cityName;
            
            // Cache the base64 string (TTL/Time-to-live set to 300 seconds / 5 mins)
            orgPart.put(cacheKey, base64Data, 300);
            
        } catch (Exception e) {
            throw new AuraHandledException('Failed to store QR code in cache: ' + e.getMessage());
        }
    }

}