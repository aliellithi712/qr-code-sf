// Write your anonymous Apex code here
// Then run it using either:
// - the menu command "Nerdy stuff -> Run anonymous Apex code"
// - the context menu on the file or in this window "Run anonymous Apex code"

// 1. Define the Object API Name
String objectName = 'Account';

// 2. Query a valid Record Type ID for that object
// (Change the developer name to match a record type in your org, or remove the WHERE clause to grab the first one)
Id recordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = :objectName AND IsActive = true LIMIT 1].Id;

// 3. Execute the method
System.debug('--- START PICKLIST EXTRACTION ---');
PicklistFetcher.fetchRecordTypePicklistValues(objectName, recordTypeId);
System.debug('--- END PICKLIST EXTRACTION ---');
