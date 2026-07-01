public with sharing class ComplaintStatusFlowHandler {

    public class Input {
        @InvocableVariable(required=true)
        public String category;

        @InvocableVariable(required=true)
        public String status;

        @InvocableVariable
        public String frigo;
    }

    public class Output {
        @InvocableVariable
        public String targetText;
    }

    @InvocableMethod(label='Get Complaint Target Text')
    public static List<Output> process(List<Input> inputs) {

        // Build metadata map once per execution
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

        Input item = inputs[0];

        String frigoValue = String.isBlank(item.frigo) ? '' : item.frigo;

        String key = item.category + '|' + frigoValue + '|' + item.status;

        Complaint_Status_Mapping__mdt mapping = metadataMap.get(key);

        Output out = new Output();

        if (mapping == null) {
            out.targetText = 'No Voucher';
        } else {
            out.targetText = mapping.Target_Text__c;
        }

        return new List<Output>{ out };
    }
}
