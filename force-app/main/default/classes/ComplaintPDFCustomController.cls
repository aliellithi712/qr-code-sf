public without sharing class ComplaintPDFCustomController {
    public Complaint__c complaint { get; set; }
    public List<Invoice_Line_Item__c> invoiceLineItems { get; set; }
    public List<Invoice_Line_Item__c> allItems { get; set; }
    public List<Invoice_Line_Item__c> missingLineItems { get; set; }
    public List<Invoice_Line_Item__c> additionalLineItems { get; set; }
    public String todayDate { get; set; }
    public Boolean showBlankPage { get; set; }
    public List<List<PageWrapper>> pdfPages { get; set; }



    // Crypto Constants
    private static final String PRIVATE_KEY_HEX = 'a8fe3007b37b5e6474a7c5a42f35e637';
    private static final Blob SECRET_KEY = EncodingUtil.convertFromHex(PRIVATE_KEY_HEX);

    public class PageWrapper {
        public List<Invoice_Line_Item__c> items { get; set; }
        public Complaint__c complaint { get; set; }
        // public Id qrCodeId { get; set; }
        public List<String> qrCodeIds {get; set;}
        public String status { get; set; }

        public PageWrapper(List<Invoice_Line_Item__c> items, Complaint__c complaint, List<String> qrCodeIds, String status) {
            this.items = items;
            this.complaint = complaint;
            this.qrCodeIds = qrCodeIds;
            this.status = status;
        }
    }

    // No-argument constructor for Custom Controller
    public ComplaintPDFCustomController() {
        this.showBlankPage = true; // Secure default

        // 1. Extract and decrypt the token to find out which record this is
        Id extractedComplaintId = getRecordIdFromToken();

        // 2. If the token is valid and gave us a record ID, load the data
        if (extractedComplaintId != null) {
            this.showBlankPage = false;

            complaint = [
                SELECT Id, Name, Account_Number__c, Account_Name__r.Name, Account_Wave_ID__c,
                       Account_Name__r.OCE__PrimaryAccountAddress__r.OCE__AddressLine1__c,
                       Account_Name__r.OCE__PrimaryAccountAddress__r.OCE__AddressLine2__c,
                       Order_Number__c, Invoice_Number__c, Category__c
                FROM Complaint__c
                WHERE Id = :extractedComplaintId
                LIMIT 1
            ];

            allItems = [
                SELECT Id, product_code__c, product_name__c, Variance_Quantity__c,
                       lot__c, expiry_date__c, frigo__c, Status__c,Frigo_Manual__c,Is_API__c,Complaint__r.Category__c
                FROM Invoice_Line_Item__c
                WHERE Complaint__c = :extractedComplaintId
            ];

            List<ContentDocumentLink> contentdocs = [
                SELECT ContentDocument.latestPublishedVersionId
                FROM ContentDocumentLink
                WHERE ContentDocument.Title LIKE '%QRCode%'
                AND LinkedEntityId = :extractedComplaintId
                LIMIT 1
            ];

            List<Id> qrVersionIds = new List<Id>();
            if (!contentdocs.isEmpty()) {
                qrVersionIds.add(contentdocs[0].ContentDocument.LatestPublishedVersionId);
            }

            // List<Id> qrVersionIds = new List<Id>();
            if (!contentdocs.isEmpty()) {
                Id firstId = contentdocs[0].ContentDocument.LatestPublishedVersionId;
                qrVersionIds.add(firstId); // First addition
                qrVersionIds.add(firstId); // Second addition
                }

            // pdfPages = new List<PageWrapper>{ new PageWrapper(allItems, complaint, qrVersionId) };

            // invoiceLineItems = allItems;
            pdfPages = new List<List<PageWrapper>>();
            missingLineItems = new List<Invoice_Line_Item__c>();
            additionalLineItems = new List<Invoice_Line_Item__c>();

            Map<String, Complaint_Status_Mapping__mdt> metadataMap = new Map<String, Complaint_Status_Mapping__mdt>();
            for (Complaint_Status_Mapping__mdt mdt : Complaint_Status_Mapping__mdt.getAll().values()) {
                if (String.isBlank(mdt.Frigo__c)) {
                    metadataMap.put( mdt.Category__c + '|Y|' + mdt.Status__c, mdt);
                    metadataMap.put( mdt.Category__c + '|N|' + mdt.Status__c,mdt);
                    metadataMap.put( mdt.Category__c + '||' + mdt.Status__c,mdt);
                }
                else{
                    String key = mdt.Category__c + '|' + mdt.Frigo__c + '|' + mdt.Status__c;
                    metadataMap.put(key, mdt);
                }
            }

            /**
            Map<String, Complaint_Status_Mapping__mdt> metadataMap = Complaint_Status_Mapping__mdt.getAll();
            Map<String, Complaint_Status_Mapping__mdt> labelToMetadataMap = new Map<String, Complaint_Status_Mapping__mdt>();
            for (Complaint_Status_Mapping__mdt mapping : metadataMap.values())
                labelToMetadataMap.put(mapping.MasterLabel, mapping);
            */

            for (Invoice_Line_Item__c item : allItems) {

                String frigoValue;
                if (item.Is_API__c)
                    frigoValue = item.Frigo__c;
                else
                    frigoValue = item.Frigo_Manual__c;

                String key = item.Complaint__r.Category__c + '|' + (String.isBlank(frigoValue) ? '' : item.frigo__c) + '|' +
                item.Status__c;
                System.debug('DIDI1 ' + key);
                System.debug('DIDI2 ' + metadataMap.get(key) );
                Complaint_Status_Mapping__mdt mapping = metadataMap.get(key);
                if (mapping == null)
                    continue;
                    if (mapping.Target_Text__c == 'Both') {
                        missingLineItems.add(item);
                        additionalLineItems.add(item);
                    }
                    else if (mapping.Target_Text__c == 'Sending Goods') {
                        missingLineItems.add(item);
                    }
                    else if (mapping.Target_Text__c == 'Goods Retrieval') {
                        additionalLineItems.add(item);
                    }

            }

            if (!missingLineItems.isEmpty())
                pdfPages.add(new List<PageWrapper>{  new PageWrapper(missingLineItems, complaint, qrVersionIds, 'Sending Goods') });
            if(!additionalLineItems.isEmpty())
                pdfPages.add(new List<PageWrapper>{  new PageWrapper(additionalLineItems, complaint, qrVersionIds, 'Goods Retrieval') });
        }

        Datetime dt = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        todayDate = dt.format('dd/MM/yyyy');
    }

    /**
     * Decrypts token and extracts the Record ID if valid and not expired.
     * Returns null if anything fails validation.
     */
    private Id getRecordIdFromToken() {
        try {
            String urlEncodedToken = ApexPages.currentPage().getParameters().get('token');
            if (String.isBlank(urlEncodedToken)) {
                return null;
            }


            Blob encryptedData = EncodingUtil.base64Decode(urlEncodedToken);
            Blob decryptedBlob = Crypto.decryptWithManagedIV('AES128', SECRET_KEY, encryptedData);
            String rawPayload = decryptedBlob.toString();

            if (String.isBlank(rawPayload) || !rawPayload.contains('|')) {
                return null;
            }

            String[] parts = rawPayload.split('\\|');
            Id decryptedRecordId = (Id)parts[0];

            /*
            Long expirationTime = Long.valueOf(parts[1]);
            Long currentTime = DateTime.now().getTime();
            if (currentTime <= expirationTime)
            */
                return decryptedRecordId;

        } catch (Exception e) {
            System.debug('Token Decryption Failed: ' + e.getMessage());
        }
        return null;
    }
}
