public class PicklistFetcher {
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getFieldPicklistValues(String objectName, Id recordTypeId, String fieldApiName) {
        Map<String, String> optionsMap = new Map<String, String>();
        try {
            ConnectApi.PicklistValuesCollection picklistCollection =
                ConnectApi.RecordUi.getPicklistValuesByRecordType(objectName, recordTypeId);

            if (picklistCollection.picklistFieldValues != null && picklistCollection.picklistFieldValues.containsKey(fieldApiName)) {
                ConnectApi.PicklistValues fieldDetails = picklistCollection.picklistFieldValues.get(fieldApiName);

                if (fieldDetails != null && fieldDetails.values != null) {
                    for (ConnectApi.PicklistValue option : fieldDetails.values) {
                        optionsMap.put(option.value, option.label); // Key: API Name, Value: Label
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error fetching picklist values: ' + e.getMessage());
        }
        return optionsMap;
    }
}
