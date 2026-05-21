public without sharing class SitePdfController {
    
    // This secret key MUST match the exact key used when you generated the QR code signature
    private static final String SECRET_KEY = 'MySuperSecretPrivateKeyForQRVerification';

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
}