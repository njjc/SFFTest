global without sharing class RG_Rollup_PaymentsToOpportunity extends GW_ABS_Rollup implements Schedulable {

	global void execute (SchedulableContext bc) {
		RG_Rollup_PaymentsToOpportunity rollup = new RG_Rollup_PaymentsToOpportunity(200);
		rollup.runRollups();
	}

	public RG_Rollup_PaymentsToOpportunity () {
		super (200);
	}

	public RG_Rollup_PaymentsToOpportunity (id parentRecId) {
		super (parentRecId);
	}
	
	public RG_Rollup_PaymentsToOpportunity (string SOQL) {
		super (SOQL);
	}

	public RG_Rollup_PaymentsToOpportunity (integer batchSz) {
		super (batchSz);
	}
	
	public RG_Rollup_PaymentsToOpportunity (set<id> parentRecIds) {
		super (parentRecIds);
	}
	
	global override string setParentObjName() {
		return 'Opportunity';
	}
	
	global virtual override list<RollupSpec> setRollupSpecs() {
		list<RollupSpec> mySpecs = new list<RollupSpec>();
		
		//total this / last / two fiscal years ago
		RollupSpec rs = new RollupSpec('npe01__OppPayment__c', 'npe01__Opportunity__c');
		rs.filter = 'npe01__Paid__c = TRUE AND npe01__Written_Off__c = FALSE';
		rs.aggregateToParentFieldnameMap = new map<string, string> {
			'SUM(npe01__Payment_Amount__c)' => 'Total_Payments_All_Time__c',
			'COUNT_DISTINCT(ID)' => 'Total_Number_Of_Payments_All_Time__c',
			'MIN(npe01__Payment_Amount__c)' => 'Smallest_Payment__c',
			'MAX(npe01__Payment_Amount__c)' => 'Largest_Payment__c',
			'MIN(npe01__Payment_Date__c)' => 'First_Payment_Date__c',
			'MAX(npe01__Payment_Date__c)' => 'Last_Payment_Date__c'
		};
		
		rs.subgroupExpression = 'Fiscal_Year(npe01__Payment_Date__c)';
		rs.subgroupValueToParentFieldnameMap = new map<string, map<object, string>> {
			'SUM(npe01__Payment_Amount__c)' => new map<object, string> { 
				System.Today().Year() => 'Total_Payments_This_Year__c', 
				System.Today().AddYears(-1).Year() => 'Total_Payments_Last_Year__c',
				System.Today().AddYears(-2).Year() => 'Total_Payments_Two_Years_Ago__c'
			},
			'COUNT_DISTINCT(ID)' => new map<object, string> { 
				System.Today().Year() => 'Total_Number_Of_Payments_This_Year__c', 
				System.Today().AddYears(-1).Year() => 'Total_Number_Of_Payments_Last_Year__c',
				System.Today().AddYears(-2).Year() => 'Total_Number_Of_Payments_Two_Years_Ago__c'
			}
		};
		mySpecs.add(rs);

		//last 365 days
		RollupSpec rs3 = new RollupSpec('npe01__OppPayment__c', 'npe01__Opportunity__c');
		rs3.filter = 'npe01__Paid__c = TRUE AND npe01__Written_Off__c = FALSE AND npe01__Payment_Date__c = LAST_N_DAYS:365';
		rs3.aggregateToParentFieldnameMap = new map<string, string> {
			'SUM(npe01__Payment_Amount__c)' => 'Total_Payments_Last_365_Days__c',
			'COUNT_DISTINCT(ID)' => 'Total_Number_of_Payments_Last_365_Days__c'
		};

		mySpecs.add(rs3);
		
		return mySpecs; 
	}

	global virtual override void finish(Database.BatchableContext bc) {
		system.debug('running finish method in extended class RG_Rollup_PaymentsToOpportunity');
		//run contact batch when this batch is done
		RG_Rollup_OpportunityToContact otc = new RG_Rollup_OpportunityToContact(200);
		otc.runRollups();
	}


}