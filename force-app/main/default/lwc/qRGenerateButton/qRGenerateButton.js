import { LightningElement, api } from 'lwc';
import qrcode from './qrcode.js';
import { loadScript } from "lightning/platformResourceLoader";
import pdflib from "@salesforce/resourceUrl/pdf_lib";
import generateEncryptedToken from '@salesforce/apex/QRGenerateButtonController.generateEncryptedToken';
import { NavigationMixin } from 'lightning/navigation';
import saveQRCodeFile from '@salesforce/apex/QRGenerateButtonController.saveQRCodeFile';
import savePdf from '@salesforce/apex/QRGenerateButtonController.savePdf';
import getLatestPDFAttachment from "@salesforce/apex/QRGenerateButtonController.getLatestPDFAttachment";

export default class QRGenerateButton extends NavigationMixin(LightningElement) {
    isLoading = true;
    isLibraryLoaded = false;
    _recordId;
    scanResolver;

    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (this.isLibraryLoaded) {
            this.handleQrGenerationSequence();
        }
    }

    renderedCallback() {
        if (this.isLibraryLoaded) return;
        loadScript(this, pdflib)
            .then(() => {
                this.isLibraryLoaded = true;
                window.addEventListener("message", this.handleFrameResponse.bind(this), false);
                if (this._recordId) {
                    this.handleQrGenerationSequence();
                }
            })
            .catch(error => console.error('Error loading library: ', error));
    }

    // Sends an individual page's bytes to the iframe for keyword checking
    scanSinglePageForText(pageBytes,searchKey) {
        return new Promise((resolve) => {
            this.scanResolver = resolve;
            const iframe = this.refs.pdfWorkerFrame;
            if (!iframe) {
                resolve(false);
                return;
            }
            iframe.contentWindow.postMessage({
                type: 'SCAN_PDF',
                bytes: pageBytes,
                keyword: searchKey
            }, '*');
        });
    }

    handleFrameResponse(event) {
        if (event.data.type === 'SCAN_RESULT') {
            if (this.scanResolver) {
                this.scanResolver(event.data.found); // Expecting true or false per page
            }
        } else if (event.data.type === 'SCAN_ERROR') {
            if (this.scanResolver) this.scanResolver(false);
        }
    }

    async handleQrGenerationSequence() {
        try {
            this.isLoading = true;
            const encryptedToken = await generateEncryptedToken({ recordId: this._recordId });
            console.log('encrypted Token ' , encryptedToken);


            const complaintName = await saveQRCodeFile({
                recordId: this.recordId,
                name: 'Voucher',
                token: encryptedToken
            });

            const pdfBase64Data = await getLatestPDFAttachment({ recordId: this.recordId });

            const { PDFDocument, rgb, StandardFonts } = window.PDFLib;
            const pdfBytes = Uint8Array.from(window.atob(pdfBase64Data), c => c.charCodeAt(0));
            const sourcePdfDoc = await PDFDocument.load(pdfBytes);
            const totalPages = sourcePdfDoc.getPageCount();

            // --- PASS 1: Identify Keyword Pages Page-by-Page ---
            const matchPages = [];

            for (let i = 0; i < totalPages; i++) {
                // Extract a temporary single-page PDF to send to your existing iframe scanner
                const tempDoc = await PDFDocument.create();
                const [copiedPage] = await tempDoc.copyPages(sourcePdfDoc, [i]);
                tempDoc.addPage(copiedPage);
                const tempBytes = await tempDoc.save();

                const isKeywordOnPage = await this.scanSinglePageForText(tempBytes,'Customer Complaints Voucher');
                if (isKeywordOnPage) {
                    const hasR = await this.scanSinglePageForText( tempBytes, 'GOODS RETRIEVAL DATA');
                    const hasS = await this.scanSinglePageForText( tempBytes, 'SENDING GOODS DATA');

                    let status = null;
                    if (hasR) status = 'R';
                    else if (hasS) status = 'S';

                    matchPages.push({ page: i + 1, status});

                }
            }

            // --- PASS 2: Calculate Chunk Sizes Based on Found Keywords ---
            const segments = [];
            if (matchPages.length <= 1) {
                segments.push({ startPage: 1, endPage: totalPages, size: totalPages, status: matchPages[0]?.status || '' });
            } else {
                for (let m = 0; m < matchPages.length; m++) {
                    const startObj = matchPages[m];
                    if (!startObj)
                         continue;

                    const start = matchPages[m].page;
                    const nextMatch = matchPages[m + 1]?.page;
                    const status = matchPages[m].status;
                    const end = nextMatch ? (nextMatch - 1) : totalPages;
                    segments.push({
                        startPage: start,
                        endPage: end,
                        size: (end - start) + 1,
                        status: status
                    });
                }
            }

            // --- PASS 3: Apply the Stamping and Handle Resets ---
            let currentSegmentIndex = 0;
            let relativePageCounter = 1;
            const pages = sourcePdfDoc.getPages();

            for (let i = 0; i < totalPages; i++) {
                const actualPageNumber = i + 1;
                let activeSegment = segments[currentSegmentIndex];

                // If we crossed into the boundary of the next segment section, reset
                if (actualPageNumber > activeSegment.endPage && currentSegmentIndex < segments.length - 1) {
                    currentSegmentIndex++;
                    activeSegment = segments[currentSegmentIndex];
                    relativePageCounter = 1;
                }

                this.inputValue = `24.${complaintName}.${activeSegment.status}.${relativePageCounter}of${activeSegment.size}`;

                const base64Data = await this.generateQR();
                const imageBytes = Uint8Array.from(window.atob(base64Data), c => c.charCodeAt(0));
                const embeddedPng = await sourcePdfDoc.embedPng(imageBytes);
                const helveticaFont = await sourcePdfDoc.embedFont(window.PDFLib.StandardFonts.Helvetica);
                const currentPage = pages[i];
                const { width, height } = currentPage.getSize();

                const qrWidth = 65;    // Reduced from 90
                const qrHeight = 65;   // Reduced from 90

                // Aligns the smaller code perfectly in the top right corner
                const qrX = width - 80;
                const qrY = height - 80;

                // 1. Draw the QR Code Image
                currentPage.drawImage(embeddedPng, {
                    x: qrX,
                    y: qrY,
                    width: qrWidth,
                    height: qrHeight
                });

                // 2. Calculate and Draw Centered Text Label Underneath
                const textSize = 7;    // Slightly smaller font size to fit the smaller footprint
                const textWidth = helveticaFont.widthOfTextAtSize(this.inputValue, textSize);
                const centerXOffset = (qrWidth - textWidth) / 2;

                currentPage.drawText(this.inputValue, {
                    x: qrX + centerXOffset,
                    y: qrY - 10,       // Tighter padding below the smaller QR code
                    size: textSize,
                    font: helveticaFont,
                    color: rgb(0, 0, 0)
                });

                relativePageCounter++;
            }

            const modifiedPdfBytes = await sourcePdfDoc.save();
            this.downloadModifiedFile(modifiedPdfBytes);

        } catch (error) {
            console.error('❌ Error in sequence execution:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async downloadModifiedFile(bytes) {
        try {
            const blob = new Blob([bytes], { type: 'application/pdf' });

            const base64Pdf = await new Promise((resolve) => {
                const reader = new FileReader();
                reader.onloadend = () => {
                    resolve(reader.result.split(',')[1]);
                };
                reader.readAsDataURL(blob);
            });

            const contentDocumentId = await savePdf({
                recordId: this.recordId,
                base64Pdf,
                fileName: 'Stamped_Complaint_Document'
            });

            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: contentDocumentId
                }
            });

        } catch (error) {
            console.error('Error saving PDF', error);
        }

        /**  OPEN CONTENT DISTRIBUTION
        const publicUrl = await savePdf({
            recordId: this.recordId,
            base64Pdf,
            fileName: 'Stamped_Complaint_Document'
        });

        window.open(publicUrl, '_blank');

        */


        /** DOWNLOAD
        const blob = new Blob([bytes], { type: "application/pdf" });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = "Stamped_Complaint_Document.pdf";
        link.click();
        URL.revokeObjectURL(link.href);
         */

    }

    async generateQR() {
        const qrCodeGenerated = new qrcode(0, 'H');
        let strForGenearationOfQRCode = this.inputValue || '';
        qrCodeGenerated.addData(strForGenearationOfQRCode);
        qrCodeGenerated.make();
        const svgString = qrCodeGenerated.createSvgTag({});

        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement('canvas');
                canvas.width = 200;
                canvas.height = 200;
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0);
                const pngDataUrl = canvas.toDataURL('image/png');
                resolve(pngDataUrl.replace(/^data:image\/png;base64,/, ""));
            };
            img.onerror = (error) => { reject(error); };
            img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgString)));
        });
    }
}
