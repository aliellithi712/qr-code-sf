public with sharing class IQVIA_IvoiceLineItemTrgHandler extends IQVIA_TriggerService.Handler {

    public IQVIA_IvoiceLineItemTrgHandler() {
        // Constructor
    }

    public override void afterInsert(Map<Id, SObject> newMap) {
        getComplaintTargetText((List<OCE__Inquiry__c>)newMap.values());
    }

    public override void afterUpdate(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        getComplaintTargetText((List<OCE__Inquiry__c>)newMap.values());
    }

    public void getComplaintTargetText(List<OCE__Inquiry__c> inquiries) {
        if (inquiries == null || inquiries.isEmpty()) {
            return;
        }

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


        for (OCE__Inquiry__c record : inquiries) {

            String category = record.OCE__Category__c;
            String status = record.OCE__Status__c;
            String frigo = record.Frigo_Field__c;

            String frigoValue = String.isBlank(frigo) ? '' : frigo;
            String key = category + '|' + frigoValue + '|' + status;

            Complaint_Status_Mapping__mdt mapping = metadataMap.get(key);

            String targetText = (mapping == null) ? 'No Voucher' : mapping.Target_Text__c;

            // Example: Assign target text back to a field or use it in further logic
            // record.Target_Text_Field__c = targetText;
        }
    }
}
