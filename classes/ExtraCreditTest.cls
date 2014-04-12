public with sharing class ExtraCreditTest {
	    /*********************************************************************************************************
    operation:
        create two seasonal address that don't overlap
    verify:
        overlap not detected, seasonal addresses save
    *********************************************************************************************************  
    static testMethod void insertSeasonalAddrWithoutOverlap() {
        if (strTestOnly != '*' && strTestOnly != 'insertSeasonalAddrWithOverlap') return;
        
        // this creates a default Address for each HH
        createHHTestData(1, 1);
        
        // create two additional seasonal addresses not current
        // the second seasonal address starts on the last day of the first seasonal address.
        // they should not be considered overlapping
        initTestAddr(2);
        listAddrT[0].Household_Account__c = listAccT[0].Id;
        listAddrT[0].Seasonal_Start_Month__c ='12';
        listAddrT[0].Seasonal_Start_Day__c = '31';
        listAddrT[0].Seasonal_End_Month__c = '1';
        listAddrT[0].Seasonal_End_Day__c = '31';
        listAddrT[0].Default_Address__c = false;
        listAddrT[0].MailingStreet__c = 'New Seasonal Street 0';
        listAddrT[0].MailingCity__c = 'New Seasonal City 0';
        listAddrT[1].Household_Account__c = listAccT[0].Id;
        listAddrT[1].Seasonal_Start_Month__c ='1';
        listAddrT[1].Seasonal_Start_Day__c = '31';
        listAddrT[1].Seasonal_End_Month__c = '5';
        listAddrT[1].Seasonal_End_Day__c = '1';
        listAddrT[1].Default_Address__c = false;
        listAddrT[1].MailingStreet__c = 'New Seasonal Street 1';
        listAddrT[1].MailingCity__c = 'New Seasonal City 1';

        ADDR_Addresses_TDTM.hasRunAddrTrigger = false;
        try {
            insert listAddrT;
        } catch (Exception ex) {
            system.assert(!ex.getMessage().contains(Label.addrSeasonalOverlap), 'code falsly detected a seasonal overlap where there was none');
            return;
        }
        
    }  
    */
}