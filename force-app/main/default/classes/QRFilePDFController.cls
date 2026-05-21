public with sharing class QRFilePDFController {
    
    private static final String SECRET_KEY = 'MySuperSecretPrivateKeyForQRVerification';
    @AuraEnabled(cacheable=true)
    public static String getSignedSiteUrl(Id recordId) {
        try {
            if (recordId == null) {
                throw new AuraHandledException('Missing Record ID.');
            }

            // 1. Force the Record ID into a clean 18-character format string length
            String cleanIdStr = String.valueOf((Id)recordId);

            // 2. Generate the identical secure cryptographic SHA-256 pattern hash match
            Blob targetBlob = Blob.valueOf(cleanIdStr + SECRET_KEY);
            Blob hash = Crypto.generateDigest('SHA-256', targetBlob);
            String signature = EncodingUtil.convertToHex(hash);
            
            // 3. Build the public direct Visualforce link routing parameters map layout
            return 'https://resourceful-moose-gu6rll-dev-ed.trailblaze.my.site.com/testcomplaint/apex/AccountPDF?id=' 
                + cleanIdStr + '&sig=' + signature;

        } catch(Exception e) {
            throw new AuraHandledException('Failed to generate valid secure link: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void saveQRCodeFile(Id recordId, String base64Data) {
        try {
            String fileName = 'QRCode.png';
            
            // 1. Check if the QR Code file already exists for this record
            Integer existingCount = [
                SELECT COUNT() 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :recordId 
                AND ContentDocument.Title = :fileName
            ];
            
            // 2. If it exists, stop completely and return without doing any DML operations
            if (existingCount > 0) {
                System.debug('QR Code file already exists. Skipping record creation.');
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
}