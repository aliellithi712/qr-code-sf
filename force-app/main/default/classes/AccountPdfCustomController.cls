public without sharing class AccountPdfCustomController {
    
    // Must match the exact secret string token used when generating the QR code link
    private static final String SECRET_KEY = 'MySuperSecretPrivateKeyForQRVerification';
    
    public Account currentAccount { get; private set; }
    public String qrCodeVersionId { get; private set; } 
    public Boolean isValidSignature { get; private set; } // Condition variable for your <apex:outputPanel>

    public AccountPdfCustomController() {
        this.isValidSignature = false;
        
        // 1. Extract raw parameters from the URL address bar layout
        String rawAccountId = ApexPages.currentPage().getParameters().get('id');
        String urlSignature = ApexPages.currentPage().getParameters().get('sig');
        
        try {
            if (String.isNotBlank(rawAccountId) && String.isNotBlank(urlSignature)) {
                
                // FIX: Force casting to Id type to ensure a clean 18-character string length matching
                Id accountId = (Id)rawAccountId;
                String cleanIdStr = String.valueOf(accountId);
                
                // 2. SECURITY GATE: Recompute the cryptographic SHA-256 pattern hash match
                Blob targetBlob = Blob.valueOf(cleanIdStr + SECRET_KEY);
                Blob hash = Crypto.generateDigest('SHA-256', targetBlob);
                String expectedSignature = EncodingUtil.convertToHex(hash);
                
                // 3. VALIDATION MATCH CHECK: Only touch database records if signatures align
                if (urlSignature.equals(expectedSignature)) {
                    this.isValidSignature = true;
                    
                    this.currentAccount = [
                        SELECT Name, AccountNumber, Phone, Industry 
                        FROM Account 
                        WHERE Id = :accountId 
                        LIMIT 1
                    ];

                    // Query the newest ContentVersion ID linked to this record via ContentDocumentLink
                    List<ContentDocumentLink> links = [
                        SELECT ContentDocumentId 
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId = :accountId 
                        AND ContentDocument.Title LIKE 'QRCode%' // Adjusted slightly to support flexible naming variations safely
                        LIMIT 1
                    ];

                    if (!links.isEmpty()) {
                        ContentVersion cv = [
                            SELECT Id 
                            FROM ContentVersion 
                            WHERE ContentDocumentId = :links[0].ContentDocumentId 
                            AND IsLatest = true 
                            LIMIT 1
                        ];
                        this.qrCodeVersionId = cv.Id;
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