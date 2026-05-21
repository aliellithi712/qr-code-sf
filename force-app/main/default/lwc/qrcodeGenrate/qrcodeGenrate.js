import { LightningElement, track, api, wire } from 'lwc';
import qrcodeLib from '@salesforce/resourceUrl/qrcode';
import { loadScript } from 'lightning/platformResourceLoader';
import getSignedSiteUrl from '@salesforce/apex/QRFilePDFController.getSignedSiteUrl';

export default class QrcodeGenrate extends LightningElement {
    @api recordId; 
    @track inputText = '';
    qrcodeInitialized = false;
    qrLibLoaded = false;
    signedUrl = '';

    renderedCallback() {
        if (this.qrcodeInitialized) return;
        this.qrcodeInitialized = true;

        loadScript(this, qrcodeLib)
            .then(() => {
                this.qrLibLoaded = true;
                console.log('✅ QRCode library loaded');
                
                // Trigger compilation execution flow
                this.generateQRCode();
            })
            .catch(error => {
                console.error('❌ Error loading QRCode library', error);
            });
    }

    // Use a reactive wire framework adapter to pull the signed URL string securely on record load
    @wire(getSignedSiteUrl, { recordId: '$recordId' })
    wiredUrl({ error, data }) {
        if (data) {
            this.signedUrl = data;
            // Re-render the canvas if the third-party JS library is already in memory
            if (this.qrLibLoaded) {
                this.generateQRCode();
            }
        } else if (error) {
            console.error('❌ Error fetching signed site URL endpoint from server: ', error);
        }
    }

    generateQRCode() {
        // Halt generation if the library isn't ready or if the signed URL hasn't returned from Apex yet
        if (!this.qrLibLoaded || !this.signedUrl) return;

        const container = this.template.querySelector('.qrcode');
        if (!container) return;
        
        container.innerHTML = ""; // Clear out previous layout canvas frames

        // Instantiate the rendering engine using the cryptographically verified URL string
        new window.QRCode(container, {
            text: this.signedUrl, // Passes the full verified string containing both parameters maps (?id=...&sig=...)
            width: 200,
            height: 200
        });
    }
}