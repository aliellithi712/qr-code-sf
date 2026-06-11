public with sharing class QRGenerateButtonController {

    private static final String PRIVATE_KEY_HEX = 'a8fe3007b37b5e6474a7c5a42f35e637';
    private static final Blob SECRET_KEY = EncodingUtil.convertFromHex(PRIVATE_KEY_HEX);

    @AuraEnabled(cacheable=false)
    public static String generateEncryptedToken(Id recordId) {
    try {

        Long expPeriod = DateTime.now().getTime() + 172800000L;
        String rawPayload = recordId + '|';
        Blob clearText = Blob.valueOf(rawPayload);
        Blob encryptedBlob = Crypto.encryptWithManagedIV('AES128', SECRET_KEY, clearText);
        String base64String = EncodingUtil.base64Encode(encryptedBlob);
        return EncodingUtil.urlEncode(base64String, 'UTF-8');

    } catch (Exception e) {
        throw new AuraHandledException('Error encrypting data: ' + e.getMessage());
    }
}



    @AuraEnabled
    public static String saveQRCodeFile(Id recordId,  String name, String token) {
        try {

            // PageReference pdfPage = Page.Mersaco_Complaints_PDF;
            String sfdcBaseURL = 'https://mersaco-lb-oce--uat.sandbox.my.salesforce-sites.com/voucher';
            String pdfUrl = sfdcBaseURL + '?token=' + token;
            PageReference pdfPage = new PageReference(pdfUrl);
            System.debug('Target PDF Generation URL: ' + pdfUrl);

            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Unit Test PDF Content Placeholder');
            } else {
            pdfBlob = pdfPage.getContentAsPDF();
        }
        String targetTitle = name + ' - Complaint Voucher PDF';
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocument.Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            AND ContentDocument.Title = :targetTitle
            LIMIT 1
        ];

        ContentVersion pdfVersion = new ContentVersion();
        pdfVersion.Title = targetTitle;
        pdfVersion.PathOnClient = name + '_Complaint_Voucher.pdf';
        pdfVersion.VersionData = pdfBlob;
        pdfVersion.FirstPublishLocationId = recordId;
        if (!existingLinks.isEmpty()) {
            Id docId = existingLinks[0].ContentDocumentId;
            delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
            // pdfVersion.ContentDocumentId = existingLinks[0].ContentDocument.Id;
            System.debug('Existing PDF found. Adding a new version to Document ID: ' + pdfVersion.ContentDocumentId);
        }
        insert pdfVersion;

        String sobjectType = recordId.getSObjectType().getDescribe().getName();
        String query = 'SELECT Name FROM ' + String.escapeSingleQuotes(sobjectType) + ' WHERE Id = :recordId LIMIT 1';
        SObject record = Database.query(query);

        return (String)record.get('Name');

            // ---------------------------------------------
            /*
            String fileName = name + '_QRCode.png';

            List<ContentDocumentLink> existingLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                AND ContentDocument.Title = :fileName
                LIMIT 1
            ];

            // If it exists, delete it so we can replace it
            if (!existingLinks.isEmpty()) {
                System.debug('QR Code file already exists. Deleting old version...');
                ContentDocument oldDoc = new ContentDocument(Id = existingLinks[0].ContentDocumentId);
                return;
                // delete oldDoc;
            }

            // This will now execute whether the file was brand new OR just deleted
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
             */

        } catch (Exception e) {
            throw new AuraHandledException('Error saving QR Code: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=false)
    public static String getLatestPDFAttachment(Id recordId) {
        try {
            // Query the latest compiled PDF version linked to this record
            List<ContentVersion> versions = [
                SELECT VersionData, Title
                FROM ContentVersion
                WHERE FirstPublishLocationId = :recordId
                AND FileExtension = 'pdf'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if(versions.isEmpty()) {
                throw new AuraHandledException('No PDF attachment found for this record.');
            }

            return EncodingUtil.base64Encode(versions[0].VersionData);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Id savePdf(String recordId, String base64Pdf, String fileName) {

        // Find existing PDFs linked to the record
        List<ContentDocumentLink> existingLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
        ];

        if (!existingLinks.isEmpty()) {
            Set<Id> documentIds = new Set<Id>();

            for (ContentDocumentLink link : existingLinks) {
                documentIds.add(link.ContentDocumentId);
            }

            // Deletes the ContentDocument and all its versions/links
            delete [
                SELECT Id
                FROM ContentDocument
                WHERE Id IN :documentIds
            ];
        }

        // Insert new PDF
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName + '.pdf',
            VersionData = EncodingUtil.base64Decode(base64Pdf),
            FirstPublishLocationId = recordId
        );

        insert cv;

        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        /**
         ContentDistribution cd = new ContentDistribution(
            Name = fileName,
            ContentVersionId = cv.Id,
            PreferencesAllowViewInBrowser = true,
            PreferencesLinkLatestVersion = true
        );

        insert cd;

        cd = [
            SELECT DistributionPublicUrl
            FROM ContentDistribution
            WHERE Id = :cd.Id
        ];

        return cd.DistributionPublicUrl;

         */

        return cv.ContentDocumentId;
    }

}
