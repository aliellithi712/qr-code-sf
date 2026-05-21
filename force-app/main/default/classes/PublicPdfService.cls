@RestResource(urlMapping='/GetPublicPDF/*')
global without sharing class PublicPdfService {
    
    @HttpGet
    global static void getAccountPdf() {
        RestResponse res = RestContext.response;
        try {
            // Read the recordId directly from the browser URL parameters
            Id recordId = RestContext.request.params.get('recordId');
            
            if (recordId == null) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Error: Missing recordId parameter.');
                return;
            }
            
            // Generate the page reference context directly
            PageReference pdfPage = Page.AccountPDF; 
            pdfPage.getParameters().put('id', recordId);
            
            Blob pdfBlob;
            // if (Test.isRunningTest()) {
                // pdfBlob = Blob.valueOf('Test PDF Content');
            // } else {
                pdfBlob = pdfPage.getContentAsPDF();
            // }
            
            // Return raw PDF binary streams directly to the browser
            res.addHeader('Content-Type', 'application/pdf');
            res.addHeader('Content-Disposition', 'inline; filename="Report_' + recordId + '.pdf"');
            res.responseBody = pdfBlob;
            
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Internal PDF Generation Error: ' + e.getMessage());
        }
    }
}