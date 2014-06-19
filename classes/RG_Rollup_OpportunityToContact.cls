global without sharing class RG_Rollup_OpportunityToContact extends GW_ABS_Rollup {

	public RG_Rollup_OpportunityToContact (id parentRecId) {
		super (parentRecId);
	}
	
	public RG_Rollup_OpportunityToContact (string SOQL) {
		super (SOQL);
	}

	public RG_Rollup_OpportunityToContact (integer batchSz) {
		super (batchSz);
	}
	
	public RG_Rollup_OpportunityToContact (set<id> parentRecIds) {
		super (parentRecIds);
	}
	
	global override string setParentObjName() {
		return 'Contact';
	}
	
	global virtual override list<RollupSpec> setRollupSpecs() {
		list<RollupSpec> mySpecs = new list<RollupSpec>();
		
		//total this / last / two fiscal years ago
		RollupSpec rs = new RollupSpec('OpportunityContactRole', 'ContactID');
		rs.filter = 'Opportunity.isClosed = TRUE and Opportunity.isWon = TRUE and Opportunity.RecordType.Name!=\'Program Payment\'';
		rs.aggregateToParentFieldnameMap = new map<string, string> {
			'SUM(Opportunity.Total_Payments_All_Time__c)' => 'Total_Payments_All_Time__c',
			'SUM(Opportunity.Total_Number_Of_Payments_All_Time__c)' => 'Total_Number_Of_Payments_All_Time__c',
			'SUM(Opportunity.Total_Payments_This_Year__c)' => 'Total_Payments_This_Year__c',
			'SUM(Opportunity.Total_Payments_Last_Year__c)' => 'Total_Payments_Last_Year__c',
			'SUM(Opportunity.Total_Payments_Two_Years_Ago__c)' => 'Total_Payments_Two_Years_Ago__c',
			'SUM(Opportunity.Total_Number_Of_Payments_This_Year__c)' => 'Total_Number_Of_Payments_This_Year__c',
			'SUM(Opportunity.Total_Number_Of_Payments_Last_Year__c)' => 'Total_Number_Of_Payments_Last_Year__c',
			'SUM(Opportunity.Total_Number_Of_Payments_Two_Years_Ago__c)' => 'Total_Number_Of_Payments_Two_Years_Ago__c',
			'SUM(Opportunity.Total_Payments_Last_365_Days__c)' => 'Total_Payments_Last_365_Days__c',
			'SUM(Opportunity.Total_Number_of_Payments_Last_365_Days__c)' => 'Total_Number_of_Payments_Last_365_Days__c',
			'MAX(Opportunity.Largest_Payment__c)' => 'Largest_Payment__c',
			'MIN(Opportunity.Smallest_Payment__c)' => 'Smallest_Payment__c',
			'MIN(Opportunity.First_Payment_Date__c)' => 'First_Payment_Date__c',
			'MAX(Opportunity.Last_Payment_Date__c)' => 'Last_Payment_Date__c'
			
		};

		mySpecs.add(rs);
		
		return mySpecs; 
	}

}