import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadScript } from 'lightning/platformResourceLoader';
import qrcodeLib from '@salesforce/resourceUrl/qrcode';
import saveQRCodeFile from '@salesforce/apex/QRFilePDFController.saveQRCodeFile';
import getSignedSiteUrl from '@salesforce/apex/QRFilePDFController.getSignedSiteUrl';
import cacheQRCode from '@salesforce/apex/QRFilePDFController.cacheQRCode';

export default class PdfGeneratorButton extends NavigationMixin(LightningElement) {
    @api recordId;
    isLoading = false;
    isScriptLoaded = false;
    cityUrlMap = {};


    async handleSaveCache(base64Image, cityName) {
        try {
            // Imperative Apex call passing the raw base64 string
            await cacheQRCode({ base64Data: base64Image , cityName:cityName });
            console.log('QR Code successfully cached.');
        } catch (error) {
            console.error('Error caching QR code:', error);
        }
    }

    async generateAndSaveQRCodes() {
        
        
        const container = this.template.querySelector('.qr-container');
        if (!container) return;

        console.log('AAA');
        console.log(this.cityUrlMap);
        

        // Use a for...of loop so await executes sequentially
        for (const [cityName, targetUrl] of Object.entries(this.cityUrlMap)) {
            

            
            // 1. Clear the single container for the current city
            container.innerHTML = ""; 
            console.log(targetUrl);
            
            // 2. Initialize the QR Code instance (Notice: no quotes around targetUrl)
                new window.QRCode(container, {
                    text: targetUrl, 
                    width: 200,
                    height: 200
                });

            // 3. Wait 300ms for the library to finish drawing the image/canvas into the DOM
            await new Promise(resolve => setTimeout(resolve, 300));
            // 4. Extract the freshly generated base64 image data from the container
            let base64Image = '';
            const imgElement = container.querySelector('img');
            
            const canvasElement = container.querySelector('canvas');
            if (imgElement && imgElement.src && imgElement.src.startsWith('data:image')) {
                base64Image = imgElement.src.split(',')[1];
            } else if (canvasElement) {
                base64Image = canvasElement.toDataURL('image/png').split(',')[1];
            }
            this.handleSaveCache(base64Image, cityName)
             console.log('H! ' , base64Image);

            if (!base64Image) {
                throw new Error('Could not extract image data payload from QR Code library.');
            }

            if (base64Image) {
                try {
        // Ensure the parameter key here ('cityName') exactly matches the variable name in your Apex signature
                    await saveQRCodeFile({ 
                        recordId: this.recordId, 
                        base64Data: base64Image,
                        cityName: cityName
                    });
                    console.log(`Successfully saved QR Code file for city: ${cityName}`);
                } catch (apexError) {
                    const errorMsg = apexError?.body?.message || apexError?.message || JSON.stringify(apexError);
                    console.error(`Apex upload failed for city [${cityName}]:`, errorMsg);
                }
            }
        }
    }

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
            this.cityUrlMap = await getSignedSiteUrl({ recordId: this.recordId });
            console.log(this.cityUrlMap);
            const container = this.template.querySelector('.qr-container');
            if (!container) return;
            this.generateAndSaveQRCodes();            
            /**
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
            */
            
            console.log('Success');

            // 5. Navigate directly to your Visualforce Viewer page or Content Document record view
            // this[NavigationMixin.Navigate]({
                // type: 'standard__webPage',
                // attributes: {
                    // url: '/apex/AccountPDF?id=' + this.recordId
                // }
            // });

        } catch (error) {
            console.error('Execution Failed', error);
        } finally {
            this.isLoading = false;
        }
    }
}