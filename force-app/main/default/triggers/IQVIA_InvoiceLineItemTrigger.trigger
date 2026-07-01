trigger IQVIA_InvoiceLineItemTrigger on Invoice_Line_Item__c (before insert, before update, before delete) {
    IQVIA_TriggerService.execute();
}