global class BATCH_Address implements Database.Batchable<sObject>, Schedulable {
/*Batchable scheduleable class that runs nightly, preferably soon after midnight.
Class finds all seasonal addresses either starting or ending on this day and sends
them to the processing class via a simple update.
*/

	integer batchSize = 200;
	string query;

	global void execute(SchedulableContext SC) {
		ID batchprocessid = Database.executeBatch(new BATCH_Address(), batchSize);
	}	

	global BATCH_Address() {
		integer thisMonth = system.today().month();
		integer thisDay = system.today().day();
		//build query for all Address records that either start or end today
		query = 'SELECT Id, Household__c, Start_Day__c, Start_Month__c, End_Day__c, End_Month__c, Street__c, City__c, State__c, Postal_Code__c, Country__c FROM Address__c '+
				'WHERE (Start_Month__c=\''+thisMonth+'\' AND Start_Day__c=\''+thisDay+'\') OR (End_Month__c=\''+thisMonth+'\' AND End_Day__c=\''+thisDay+'\')';
	}

	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator(query);
	}

   	global void execute(Database.BatchableContext BC, List<sObject> scope) {
		//generate variables for running address class' methods
		list<Address__c> aList = (list<Address__c>) scope;
		set<id> householdIds = new set<id>();
		for (Address__c a : aList) {
			householdIds.add(a.Household__c);
		}
		
		//instantiate class
		Address addressClass = new Address();
		
		//fill wrapper map
		map<id,Address.addressWrapper> batchWrapper = addressClass.fillAddressWrapper (householdIds, aList);
		
		//process map
		addressClass.processAddressWrapper(batchWrapper.values());
		
	}

	global void finish(Database.BatchableContext BC) {}
}