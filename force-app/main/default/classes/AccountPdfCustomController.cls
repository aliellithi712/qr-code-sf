public without sharing class AccountPdfCustomController {
    
    // Must match the exact secret string token used when generating the QR code link
    private static final String PRIVATE_KEY_HEX = 'a8fe3007b37b5e6474a7c5a42f35e637';
    private static final Blob SECRET_KEY = EncodingUtil.convertFromHex(PRIVATE_KEY_HEX);
    
    public Account currentAccount { get; private set; }
    public String qrCodeVersionId { get; private set; } 
    public Boolean isValidSignature { get; private set; } // Condition variable for your <apex:outputPanel>
    public String decryptedBlob { get; set; } // Condition variable for your <apex:outputPanel>
    public String qrCodeBase64 { get; private set; }
    public List<PageWrapper> pdfPages { get; private set; }


    public class PageWrapper {
        public Id qrCodeVersionId { get; set; }
        public String city { get; set; }
        public Account acc { get; set; }
        
        public PageWrapper(Id fileId, String c, Account a) {
            this.qrCodeVersionId = fileId;
            this.city = c;
            this.acc = a;
        }
    }


    


    public  AccountPdfCustomController() {
        // this.isValidSignature = false;
        
        // 1. Extract raw parameters from the URL address bar layout
        String encryptedHex = ApexPages.currentPage().getParameters().get('e');
        
        try {
            if (String.isNotBlank(encryptedHex)) {
                /**
                Cache.OrgPartition orgPart = Cache.Org.getPartition('local.qrCodeCache');
                Set<String> cacheKeys = orgPart.getKeys();
                System.debug('==========================================');
                System.debug('CACHE DIAGNOSTICS FOR: qrCodeCache');
                System.debug('Total Keys Found: ' + cacheKeys.size());
                System.debug('Partition Capacity Used: ' + orgPart.getCapacity() + '%');
                System.debug('==========================================');
                this.qrCodeBase64 = (String)orgPart.get('Alexandria');
                 */
                
                // 2. SECURITY GATE: Recompute the cryptographic SHA-256 pattern hash match
                Blob encryptedBlob = EncodingUtil.convertFromHex(encryptedHex);
                Blob tempDecryptedBlob = Crypto.decryptWithManagedIV('AES128', SECRET_KEY, encryptedBlob);
                this.decryptedBlob = tempDecryptedBlob.toString();
                List<String> splitValues = this.decryptedBlob.split('\\|');

                Id accountId = null;
                // FIX: Initialize the list instead of leaving it null
                List<String> cities = new List<String>(); 

                // Guard against missing values to avoid IndexOutOfBoundsException
                if (splitValues.size() >= 2) {
                    accountId = Id.valueOf(splitValues[0].trim());
                    // for(Integer i = 1; i < splitValues.size(); i++) {
                        // cities.add(splitValues[i].trim());
                    // }
                }

                    this.currentAccount = [
                        SELECT Name, AccountNumber, Phone, Industry 
                        FROM Account 
                        WHERE Id = :accountId 
                        LIMIT 1
                    ];
                    System.debug('Found linked ContentDocument: ' + this.currentAccount.Name + ' . ');

                    

                    // Query the newest ContentVersion ID linked to this record via ContentDocumentLink
                    // String title = '%' + city + '%';
                    List<ContentDocumentLink> links = [
                        SELECT ContentDocumentId,ContentDocument.Title,ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId = :accountId 
                        AND ContentDocument.Title LIKE '%QRCode%'
                        // LIMIT 1
                    ];
                    
                    if (!links.isEmpty()) {
                        this.pdfPages = new List<PageWrapper>();
                        for (ContentDocumentLink l : links) {
                            this.pdfPages.add(new PageWrapper(
                                l.ContentDocument.LatestPublishedVersionId, 
                                l.ContentDocument.Title.split('_QRCode')[0] , 
                                this.currentAccount.clone(true, true, false, false))
                                );                            
                        }

            }
        }
            
        } catch (Exception e) {
            this.isValidSignature = false;
            System.debug('Security parameters verification check failed: ' + e.getMessage());
        }
        
        // Fallback initializing state logic to prevent UI markup rendering runtime crashes
        if (this.currentAccount == null) {
            this.currentAccount = new Account();
        }
    }
}