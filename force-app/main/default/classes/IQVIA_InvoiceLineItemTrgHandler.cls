public with sharing class IQVIA_InvoiceLineItemTrgHandler extends IQVIA_TriggerService.Handler {

    public IQVIA_InvoiceLineItemTrgHandler() {
        // Constructor
    }

    public override void afterInsert(Map<Id, SObject> newMap) {
        List<Invoice_Line_Item__c> newInvoiceItems = (List<Invoice_Line_Item__c>)newMap.values();
        Map<Id, String> textMapping = getComplaintTargetText(newInvoiceItems);
        handleVoucherCount(newInvoiceItems, null, textMapping, null, false);
    }

    public override void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<Invoice_Line_Item__c> newInvoiceItems = (List<Invoice_Line_Item__c>)newMap.values();
        Map<Id, String> textMapping = getComplaintTargetText(newInvoiceItems);

        // Fetch old target text mapping to evaluate field value criteria changes accurately
        Map<Id, Invoice_Line_Item__c> oldInvoiceItemsMap = (Map<Id, Invoice_Line_Item__c>)oldMap;
        Map<Id, String> oldTextMapping = getComplaintTargetText(oldInvoiceItemsMap.values());

        handleVoucherCount(newInvoiceItems, oldInvoiceItemsMap, textMapping, oldTextMapping, false);
    }

    public override void beforeDelete(Map<Id, SObject> oldMap) {
        List<Invoice_Line_Item__c> olditems = (List<Invoice_Line_Item__c>)oldMap.values();
        Map<Id, String> textMapping = getComplaintTargetText(olditems);
        handleVoucherCount(olditems, null, textMapping, null, true);
    }

    public Map<Id, String> getComplaintTargetText(List<Invoice_Line_Item__c> items) {
        Map<Id, String> itemToTextMap = new Map<Id, String>();
        if (items == null || items.isEmpty()) {
            return itemToTextMap;
        }

        Set<Id> parentIds = new Set<Id>();
        for (Invoice_Line_Item__c record : items) {
            if (record.Complaint__c != null)
                parentIds.add(record.Complaint__c);
            }

        Map<Id, Complaint__c> parentMap = new Map<Id, Complaint__c>([
            SELECT Id, Category__c FROM Complaint__c WHERE Id IN :parentIds
            ]);

        Map<String, Complaint_Status_Mapping__mdt> metadataMap = new Map<String, Complaint_Status_Mapping__mdt>();

        for (Complaint_Status_Mapping__mdt mdt : Complaint_Status_Mapping__mdt.getAll().values()) {
            if (String.isBlank(mdt.Frigo__c)) {
                metadataMap.put(mdt.Category__c + '|Y|' + mdt.Status__c, mdt);
                metadataMap.put(mdt.Category__c + '|N|' + mdt.Status__c, mdt);
                metadataMap.put(mdt.Category__c + '||' + mdt.Status__c, mdt);
            } else {
                String key = mdt.Category__c + '|' + mdt.Frigo__c + '|' + mdt.Status__c;
                metadataMap.put(key, mdt);
            }
        }

        for (Invoice_Line_Item__c record : items) {
            Complaint__c parent = parentMap.get(record.Complaint__c);
            String category = (parent != null) ? parent.Category__c : '';
            String status = record.status__c;
            String frigo = record.frigo__c;
            String manualFrigo = record.Frigo_Manual__c;

            String selectedFrigo = (record.Is_API__c == true) ? frigo : manualFrigo;
            String frigoValue = String.isBlank(selectedFrigo) ? '' : selectedFrigo;
            String key = category + '|' + frigoValue + '|' + status;

            Complaint_Status_Mapping__mdt mapping = metadataMap.get(key);
            String targetText = (mapping == null) ? 'No Voucher' : mapping.Target_Text__c;

            if (record.Id != null) {
                itemToTextMap.put(record.Id, targetText);
            }
        }
        return itemToTextMap;
    }

    private void handleVoucherCount(
        List<Invoice_Line_Item__c> items,
        Map<Id, Invoice_Line_Item__c> oldMap,
        Map<Id, String> textMapping,
        Map<Id, String> oldTextMapping,
        Boolean isDelete
    ) {
        Map<Id, Integer> parentCountChanges = new Map<Id, Integer>();

        for (Invoice_Line_Item__c record : items) {
            if (record.Complaint__c == null) continue;

            Id parentId = record.Complaint__c;
            Integer changeAmount = 0;

            // Check current status: anything other than 'No Voucher' counts as generated
            String currentText = textMapping.get(record.Id);
            Boolean isCurrentVoucherGenerated = (currentText != null && currentText != 'No Voucher');

            if (isDelete) {
                if (isCurrentVoucherGenerated) {
                    changeAmount = -1;
                }
            } else if (oldMap == null) {
                // Insert context
                if (isCurrentVoucherGenerated) {
                    changeAmount = 1;
                }
            } else {
                // Update context: evaluate based on target text value changes
                String oldText = oldTextMapping != null ? oldTextMapping.get(record.Id) : 'No Voucher';
                Boolean isOldVoucherGenerated = (oldText != null && oldText != 'No Voucher');

                if (isCurrentVoucherGenerated != isOldVoucherGenerated) {
                    changeAmount = isCurrentVoucherGenerated ? 1 : -1;
                }
            }

            if (changeAmount != 0) {
                Integer currentChange = parentCountChanges.containsKey(parentId) ? parentCountChanges.get(parentId) : 0;
                parentCountChanges.put(parentId, currentChange + changeAmount);
            }
        }

        if (!parentCountChanges.isEmpty()) {
            Map<Id, Complaint__c> parentsToUpdate = new Map<Id, Complaint__c>([
                SELECT Id, Applicable_Voucher_Items__c
                FROM Complaint__c
                WHERE Id IN :parentCountChanges.keySet()
            ]);

            for (Id parentId : parentCountChanges.keySet()) {
                Complaint__c parent = parentsToUpdate.get(parentId);
                if (parent != null) {
                    Decimal currentCount = parent.Applicable_Voucher_Items__c != null ? parent.Applicable_Voucher_Items__c : 0;
                    parent.Applicable_Voucher_Items__c = currentCount + parentCountChanges.get(parentId);

                    if (parent.Applicable_Voucher_Items__c < 0) {
                        parent.Applicable_Voucher_Items__c = 0;
                    }
                }
            }

            if (!parentsToUpdate.isEmpty()) {
                update parentsToUpdate.values();
            }
        }
    }
}
