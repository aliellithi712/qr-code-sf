import { LightningElement, api, track } from 'lwc';
import pdflib from "@salesforce/resourceUrl/pdf_lib";
import { loadScript } from "lightning/platformResourceLoader";
import getLatestPDFAttachment from "@salesforce/apex/QRGenerateButtonController.getLatestPDFAttachment";

export default class ModifiedCompliantPdf extends LightningElement {
    @api recordId; // Automatically populated if placed on a Record Page
    isLibraryLoaded = false;

    renderedCallback() {
        if (this.isLibraryLoaded) return;

        loadScript(this, pdflib)
            .then(() => {
                this.isLibraryLoaded = true;
                console.log('pdf-lib successfully loaded');
            })
            .catch(error => {
                console.error('Error loading library: ', error);
            });
    }

    // Call this method from an LWC button click handler
    async handleAddImageToPdf(base64PngImage) {
        if (!this.isLibraryLoaded) {
            console.error('Library not initialized yet.');
            return;
        }

        try {
            // 1. Fetch the Base64 data string of the PDF from Apex
            const pdfBase64Data = await getLatestPDFAttachment({ recordId: this.recordId });

            // 2. Access the global PDFLib context initialized by your static resource script
            const { PDFDocument } = window.PDFLib;

            // 3. Convert both data variables into working Uint8Array binary format arrays
            const pdfBytes = Uint8Array.from(atob(pdfBase64Data), c => c.charCodeAt(0));
            const imageBytes = Uint8Array.from(atob(base64PngImage), c => c.charCodeAt(0));

            // 4. Load the document array mapping frame
            const pdfDoc = await PDFDocument.load(pdfBytes);
            const pages = pdfDoc.getPages();

            // 5. Register your target PNG asset inside the loaded document context
            const embeddedPng = await pdfDoc.embedPng(imageBytes);

            // 6. Loop through each physical layout page and stamp the image in the top-right corner
            for (let i = 0; i < pages.length; i++) {
                const currentPage = pages[i];
                const { width, height } = currentPage.getSize();

                currentPage.drawImage(embeddedPng, {
                    x: width - 110,   // 110 pixels from the right margin line boundary
                    y: height - 110,  // 110 pixels down from the absolute top page limit
                    width: 90,
                    height: 90
                });
            }

            // 7. Save out the modified document binary structures
            const modifiedPdfBytes = await pdfDoc.save();
            this.downloadModifiedFile(modifiedPdfBytes);

        } catch (error) {
            console.error('Failed to stamp image overlay onto your PDF document: ', error);
        }
    }

    downloadModifiedFile(bytes) {
        const blob = new Blob([bytes], { type: "application/pdf" });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = "Stamped_Complaint_Document.pdf";
        link.click();
    }
}
