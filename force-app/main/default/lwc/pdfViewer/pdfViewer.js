import { LightningElement, api, wire } from 'lwc';
import getAccountPdfBase64 from '@salesforce/apex/SitePdfController.getAccountPdfBase64';

export default class PdfViewer extends LightningElement {
    @api recordId;
    base64Data;
    error;
    pdfDataUrl = '';
    pdfBlobUrl;

    // Fixed: Ensure the imported method name and parameter key matches Apex perfectly
    @wire(getAccountPdfBase64, { recordId: '$recordId' })
    wiredPdf({ error, data }) {
        if (data) {
            this.base64Data = data;
            this.processBlobUrl(data);
            this.pdfDataUrl = `data:application/pdf;base64,${data}`;
            
        } else if (error) {
            this.error = error;
            this.base64Data = undefined;
            console.error('Error fetching PDF blob: ', error);
        }
    }

    processBlobUrl(base64String) {
        // 1. Decode the base64 string back into binary characters
        const byteCharacters = atob(base64String);
        const byteNumbers = new Array(byteCharacters.length);
        
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        
        // 2. Build a raw structural byte array
        const byteArray = new Uint8Array(byteNumbers);
        
        // 3. Instantiate a safe local browser Blob object
        const blob = new Blob([byteArray], { type: 'application/pdf' });
        
        // 4. Create a native scheme URL ('blob:https://yourdomain...')
        this.pdfBlobUrl = URL.createObjectURL(blob);
    }

    
    get isButtonDisabled() {
        return !this.base64Data;
    }

    get pdfUrl() {
        // return `/apex/AccountPDF?id=${this.recordId}`;
        return this.base64Data ? `data:application/pdf;base64,${this.base64Data}` : '';
    }

    handleMobileOpen() {
        if (this.base64Data) {
            const fileIdentifier = this.recordId ? this.recordId : 'Download';
            const fileName = `Account_Report_${fileIdentifier}.pdf`;

            const downloadLink = document.createElement('a');
            downloadLink.href = `data:application/pdf;base64,${this.base64Data}`;
            downloadLink.download = fileName;
            
            document.body.appendChild(downloadLink);
            downloadLink.click();
            document.body.removeChild(downloadLink);
        }
    }
}