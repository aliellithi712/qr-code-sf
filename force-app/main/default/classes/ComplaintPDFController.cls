public with sharing class ComplaintPDFController {
    public Complaint__c complaint { get; set; }
    public List<Invoice_Line_Item__c> invoiceLineItems { get; set; }
    public List<Invoice_Line_Item__c> allItems { get; set; }
    public List<Invoice_Line_Item__c> missingLineItems { get; set; }
    public List<Invoice_Line_Item__c> additionalLineItems { get; set; }
    public string todayDate { get; set; }


    private final ApexPages.StandardController stdController;

    public ComplaintPDFController(ApexPages.StandardController controller) {
        this.stdController = controller;
        Id complaintId = controller.getId();


        if (complaintId != null) {
            // Complaint data
            complaint = [
                SELECT Id, Name, Account_Number__c, Account_Name__r.Name, Account_Wave_ID__c,Account_Name__r.OCE__PrimaryAccountAddress__r.OCE__AddressLine1__c,
                Account_Name__r.OCE__PrimaryAccountAddress__r.OCE__AddressLine2__c,Order_Number__c,
                Invoice_Number__c, Category__c
                FROM Complaint__c
                WHERE Id = :complaintId
                LIMIT 1
            ];

            // Fetch all invoice line items for this complaint
            List<Invoice_Line_Item__c> allItems = [
                SELECT Id, product_code__c, product_name__c,Variance_Quantity__c,
                lot__c, expiry_date__c, frigo__c, Status__c
                FROM Invoice_Line_Item__c
                WHERE Complaint__c = :complaintId
            ];

            // Split the items based on Status__c
            invoiceLineItems = new List<Invoice_Line_Item__c>();
            missingLineItems = new List<Invoice_Line_Item__c>();
            additionalLineItems = new List<Invoice_Line_Item__c>();

            invoiceLineItems = allItems;
            for (Invoice_Line_Item__c item : allItems) {
                if (item.Status__c == 'Sending Goods') {
                    missingLineItems.add(item);
                } else if (item.Status__c == 'Goods Retrieval') {
                    additionalLineItems.add(item);
                }
            }
        }

        // Format the current date
        Datetime dt = DateTime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0));
        todayDate = dt.format('dd/MM/yyyy');
    }

}
