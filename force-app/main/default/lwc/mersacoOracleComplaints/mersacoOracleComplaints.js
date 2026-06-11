import { LightningElement, track, api, wire } from 'lwc';
import getInvoices from '@salesforce/apex/Mersaco_Oracle_Callout.getInvoices';
import insertLineItems from '@salesforce/apex/Mersaco_Line_Item_Insertion.insertLineItems';
import checkIfInvoiceExists from '@salesforce/apex/Mersaco_Oracle_Callout.checkIfInvoiceExists';
// import fetchRecordTypePicklistValues from '@salesforce/apex/PicklistFetcher.fetchRecordTypePicklistValues';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import INVOICE_LINE_OBJECT from '@salesforce/schema/Invoice_Line_Item__c'
import Status_FIELD from "@salesforce/schema/Invoice_Line_Item__c.Status__c";


export default class MersacoOracleComplaints extends LightningElement {

    @api recordId;
    @track invoice = '';
    @track invoiceType = '';
    @track showResponse = false;
    @track showSuccessScreen = false;
    @track showErrorScreen = false;
    @track lines = [];
    @track headers = [];
    @track details = [];
    @track message = '';
    @track messageType = '';
    @track selectedLineKeys = new Set();
    @track duplicateComplaintLinks = [];
    @track showDuplicateWarningModal = false;
    @track pendingInvoiceFetch = false;
    objectInfo;


    renderedCallback() {
        console.log('Rendered with recordId:', this.recordId);
        if (!this.styleInjected) {
        const style = document.createElement('style');
        style.innerText = `
            .slds-modal__container {
                width: 100vw !important;
                max-width: 100vw !important;
            }
        `;
        document.head.appendChild(style);
        this.styleInjected = true;
    }
    }

    @wire(getObjectInfo, { objectApiName: INVOICE_LINE_OBJECT })
        handleObjectInfo({ error, data }) {
            if (data)
                this.objectInfo = data;
    }

    @wire(getPicklistValues, {
        recordTypeId: "$objectInfo.defaultRecordTypeId",
        fieldApiName: Status_FIELD
        //dummyParam: '$_triggerWire'
    })
    picklistResultsSpeciality({ error, data }) {
        if(data){
            this.statusOptions = [
                ...data.values
            ];
            console.log('HERE2' , this.statusOptions);
        }
    }

    get showSection() {
        return this.showSuccessScreen || this.showErrorScreen;
    }


    columns = [
        { label: 'Rep Name', fieldName: 'rep_name', type: 'text', initialWidth: 150 },
        { label: 'Order Number', fieldName: 'order_number', type: 'number', initialWidth: 100 },
        { label: 'Type', fieldName: 'order_type', type: 'text', initialWidth: 100 },
        { label: 'Account Number', fieldName: 'account_number', type: 'text', initialWidth: 100 },
        { label: 'Account Name', fieldName: 'account_name', type: 'text', initialWidth: 100 },
        { label: 'Currency', fieldName: 'invoice_currency', type: 'text', initialWidth: 100 },
        { label: 'Type', fieldName: 'invoice_type', type: 'text', initialWidth: 100 },
        { label: 'Invoice Date', fieldName: 'invoice_date', type: 'text', initialWidth: 200 },
        { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 200 },
        { label: 'Remaining Amount', fieldName: 'amount_remaining', type: 'number', initialWidth: 200 }
    ];

    // statusOptions = [
        // { label: '-- Select --', value: '' },
        // { label: 'Sending Goods', value: 'Sending Goods' },
        // { label: 'Goods Retrieval', value: 'Goods Retrieval' }
    // ];



    get invoiceOptions() {
        return [
            { label: 'INV', value: 'INV' },
            { label: 'DR', value: 'DR' },
            { label: 'CR', value: 'CR' }
        ];
    }

    getInvoiceButton(event) {
        this.invoice = event.target.value;
        this.message = '';
        this.messageType = '';
    }

    handleInvoiceTypeChange(event) {
        this.invoiceType = event.detail.value;
        this.message = '';
        this.messageType = '';
    }



    handleGetInvoice() {
        if (!this.invoice || !this.invoiceType) {
            this.message = 'Please enter both Invoice Number and Invoice Type.';
            this.messageType = 'error';
            return;
        }

        checkIfInvoiceExists({InvNum: this.invoice})
        .then(existingLines => {
            if (existingLines && existingLines.length > 0) {
                this.duplicateComplaintLinks = existingLines;
                console.log(existingLines);
                this.showDuplicateWarningModal = true;
                this.pendingInvoiceFetch = true; // Mark that we still want to fetch it
            } else {
                this.getInvoices(); // No duplicates, proceed
            }
        })
        .catch(error => {
            console.error('Error checking invoice existence:', error);
            this.message = 'Error checking for duplicate complaints.';
            this.messageType = 'error';
        });
    }

    handleStatusChange(event) {
        const code = event.target.dataset.id;
        const value = event.detail.value;
        this.updateLine(code, 'status', value);
    }

    handleQSChange(event) {
        const code = event.target.dataset.id;
        const value = parseInt(event.target.value, 10);
        this.updateLine(code, 'Variance_Quantity', value);
    }

    handleCheckboxChange(event) {
        const key = event.target.dataset.id;
        if (event.target.checked) {
            this.selectedLineKeys.add(key);
        } else {
            this.selectedLineKeys.delete(key);
        }
    }

    updateLine(code, field, value) {
        this.lines = this.lines.map(line => {
            if (line.key === code) {
                return { ...line, [field]: value };
            }
            return line;
        });
    }

    saveComplains() {
        const selectedLines = this.lines.filter(line => this.selectedLineKeys.has(line.key));
        if (selectedLines.length === 0) {
            this.message = 'Please select at least one line item to save.';
            this.messageType = 'error';
            return;
        }
        const invalidLines = selectedLines.filter(line => {
            return !line.status || line.Variance_Quantity === undefined || line.Variance_Quantity === null || isNaN(line.Variance_Quantity)  || (line.status === 'Sending Goods' && line.Variance_Quantity > line.quantity)
            || line.Variance_Quantity <= 0
        });

        if (invalidLines.length > 0) {
            const hasNegative = invalidLines.some(line => line.Variance_Quantity <= 0);
            const hasinvalidvariance = invalidLines.some(line =>
                (line.status === 'Sending Goods' && line.Variance_Quantity > line.quantity))

            if (hasNegative) {
                this.message = 'Some lines have a negative Variance Quantity.';
            } else if (hasinvalidvariance) {
                this.message = 'Some lines with a Sending Goods status have a Variance Quantity that is greater than or equal to the Invoice Quantity.';
            } else {
                this.message = 'Please make sure all selected lines have a Status and a positive Variance Quantity value.';
            }

            this.messageType = 'error';
            return;
        }





        const jsonString = JSON.stringify(selectedLines);
        this.message = '';
        this.messageType = '';

        insertLineItems({ LINE_LEVEL: jsonString })
            .then(() => {
                this.message = 'Line items added successfully.';
                this.messageType = 'success';
                this.showSuccessScreen = true;
                this.showResponse = false;
            })
            .catch(error => {
                console.error('Error inserting line items:', error);
                let errorMsg = 'An unexpected error occurred.';
                if (error && error.body) {
                    if (Array.isArray(error.body)) {
                        errorMsg = error.body.map(e => e.message).join(', ');
                    } else if (typeof error.body.message === 'string') {
                        errorMsg = error.body.message;
                    }
                } else if (typeof error.message === 'string') {
                    errorMsg = error.message;
                }

                this.message = errorMsg;
                this.messageType = 'error';
                this.showErrorScreen = true;
                this.showResponse = false;
            });
    }
    continueDespiteDuplicates() {
        this.showDuplicateWarningModal = false;
        if (this.pendingInvoiceFetch) {
            this.getInvoices();
            this.pendingInvoiceFetch = false;
        }
    }
    cancelDueToDuplicates() {
        this.showDuplicateWarningModal = false;
        this.pendingInvoiceFetch = false;
    }

    getInvoices(){
    getInvoices({ InvNum: this.invoice, InvType: this.invoiceType, recordId: this.recordId})
            .then(result => {
                const data = JSON.parse(result);
                this.headers = data.ACCOUNT_LEVEL || [];
                this.details = data.LINE_LEVEL || [];
                this.lines = [...this.details];
                this.selectedLineKeys = new Set();
                this.showResponse = true;
                this.message = '';
                this.messageType = '';

                if (this.headers.length === 0 && this.details.length === 0) {
                    this.message = 'Please make sure that the invoice number and invoice type are valid.';
                    this.messageType = 'error';
                    this.showResponse = 'false';
                }
            })
            .catch(error => {
                console.error('Error fetching invoices:', error);
                this.message = 'Error fetching invoices. Please try again.';
                this.messageType = 'error';
                this.showResponse = 'false';
            });
    }}
