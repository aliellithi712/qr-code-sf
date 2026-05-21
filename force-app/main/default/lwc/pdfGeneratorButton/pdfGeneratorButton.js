import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import qrcodeLib from '@salesforce/resourceUrl/qrcode';
import saveQRCodeFile from '@salesforce/apex/QRFilePDFController.saveQRCodeFile';

export default class PdfGeneratorButton extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;
    isScriptLoaded = false;

    renderedCallback() {
        if (this.isScriptLoaded) return;
        
        loadScript(this, qrcodeLib)
            .then(() => { 
                this.isScriptLoaded = true; 
                console.log('✅ QRCode library loaded');
            })
            .catch(error => {
                console.error('❌ Error loading QRCode library', error);
            });
    }

    async handleProcess() {
        if (!this.isScriptLoaded) return;
        this.isLoading = true;

        try {
            const container = this.template.querySelector('.qr-container');
            if (!container) return;
            
            container.innerHTML = ""; 

            // 1. Initialize the QR Code instance in the background
            new window.QRCode(container, {
                text: 'www.google.com',
                width: 200,
                height: 200
            });

            // 2. Clear execution stack to let the library finish rendering its nodes
            await new Promise(resolve => setTimeout(resolve, 300));

            let base64Image = '';
            const imgElement = container.querySelector('img');
            const canvasElement = container.querySelector('canvas');

            // 3. Extract base64 image data payload safely
            if (imgElement && imgElement.src && imgElement.src.startsWith('data:image')) {
                base64Image = imgElement.src.split(',')[1];
            } else if (canvasElement) {
                base64Image = canvasElement.toDataURL('image/png').split(',')[1];
            }

            if (!base64Image) {
                throw new Error('Could not extract image data payload from QR Code library.');
            }

            // 4. Send non-empty data payload to Apex controller
            await saveQRCodeFile({ recordId: this.recordId, base64Data: base64Image });
            console.log('Success');

            // 5. Navigate directly to your Visualforce Viewer page or Content Document record view
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/apex/AccountPDF?id=' + this.recordId
                }
            });

        } catch (error) {
            console.error('Execution Failed', error);
        } finally {
            this.isLoading = false;
        }
    }
}