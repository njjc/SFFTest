@isTest
private class TEST_Address {
	
    //initiates a list of addresses for tests
    private static list<Address__c> initAddresses(integer num) {
		list<Address__c> results = new list<Address__c>();
    	for (integer i = 0; i < num; i++) {
    		Address__c a = new Address__c();
    		a.Address_Type__c = 'Home';
    		a.Street__c = 'TestStreet' + i;
    		a.City__c = 'TestCity' + i;
            a.State__c = 'TestState' + i;
            a.Postal_Code__c = 'TestZip' + i;
            a.Country__c = 'TestCountry' + i;
            results.add(a);
    	}
    	return results;
    }

	//A household must have a default address before creating a seasonal address.
	@isTest static void preventOnlySeasonal() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Start_Month__c = '1';
		a.Start_Day__c = '31';
		a.End_Month__c = '5';
		a.End_Day__c = '1';

		Exception ex = null;
		try {
			insert a;
		} catch (Exception e) {
			ex = e;			
		}

        system.assertNotEquals(ex,null,'An exception should be caught.');
        system.assert(ex.getMessage().contains('A household must have a default address before creating a seasonal address.'),ex.getMessage());
	}

	//Seasonal addresses must have complete start and end dates.
	@isTest static void preventPartialDates() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a1 = initAddresses(1)[0];
		a1.Household__c = hh.id;
		a1.Default__c = true;
		insert a1;

		address__c a2 = initAddresses(1)[0];
		a2.Household__c = hh.id;
		a2.Start_Month__c = '1';
		a2.Start_Day__c = '31';

		Exception ex = null;
		try {
			insert a2;
		} catch (Exception e) {
			ex = e;			
		}
        system.assertNotEquals(ex,null,'An exception should be caught.');
        system.assert(ex.getMessage().contains('Seasonal addresses must have complete start and end dates.'),ex.getMessage());
	}
	
	//Dates must be valid days of the year.
	@isTest static void preventInvalidDates() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;
		address__c a1 = new Address__c(
			Household__c = hh.id,
			Street__c = 'TestStreet',
			City__c = 'TestCity',
			State__c = 'TestState',
			Country__c = 'TestCountry',
			Address_Type__c = 'Home',
			Default__c = true
		);
		insert a1;

		list<Address__c> alist = [SELECT Id, Default__c FROM Address__c WHERE ID = :a1.id];
		system.debug('isdefault: ' + alist);

		address__c a2 = new address__c(
			Household__c = hh.id,
			Street__c = 'TestStreet',
			City__c = 'TestCity',
			State__c = 'TestState',
			Country__c = 'TestCountry',
			Address_Type__c = 'Seasonal',
			Start_Month__c = '1',
			Start_Day__c = '31',
			End_Month__c = '4',
			End_Day__c = '31'
		);

		Exception ex = null;
		try {
			insert a2;
		} catch (Exception e) {
			ex = e;			
		}
        system.assertNotEquals(ex,null,'An exception should be caught.');
        system.assert(ex.getMessage().contains('Dates must be valid days of the year.'),ex.getMessage());
	}

	//Seasonal addresses can't overlap with other seasonal addresses for this household for addresses within a trigger set.
	@isTest static void preventOverlapInTriggerset() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Default__c = true;
		insert a;

		list<Address__c> aList = initAddresses(2);
		
		aList[0].Household__c = hh.id;
		aList[0].Start_Month__c = '1';
		aList[0].Start_Day__c = '1';
		aList[0].End_Month__c = '4';
		aList[0].End_Day__c = '25';
		
		aList[1].Household__c = hh.id;
		aList[1].Start_Month__c = '12';
		aList[1].Start_Day__c = '15';
		aList[1].End_Month__c = '1';
		aList[1].End_Day__c = '15';

		Exception ex = null;
		try {
			insert aList;
		} catch (Exception e) {
			ex = e;
			system.debug('Exception here: ' + ex);	
		}
        system.assertNotEquals(ex,null,'An exception should be caught.');
        system.assert(ex.getMessage().contains('Seasonal addresses can\'t overlap with other seasonal addresses for this household.'),ex.getMessage());
	}

	//Seasonal addresses can't overlap with other seasonal addresses for this household that are already saved.
	@isTest static void preventOverlapInExisting() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		list<Address__c> aList = initAddresses(2);
		aList[0].Household__c = hh.id;
		aList[0].Default__c = true;
		aList[1].Household__c = hh.id;
		aList[1].Start_Month__c = '12';
		aList[1].Start_Day__c = '15';
		aList[1].End_Month__c = '1';
		aList[1].End_Day__c = '15';
		insert aList;
		
		Address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Start_Month__c = '12';
		a.Start_Day__c = '18';
		a.End_Month__c = '1';
		a.End_Day__c = '1';

		Exception ex = null;
		try {
			insert a;
		} catch (Exception e) {
			ex = e;
			system.debug('Exception here: ' + ex);	
		}
        system.assertNotEquals(ex,null,'An exception should be caught.');
        system.assert(ex.getMessage().contains('Seasonal addresses can\'t overlap with other seasonal addresses for this household.'),ex.getMessage());
	}

	//User can't uncheck default
	@isTest static void preventUncheckDefault() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Default__c = true;
		insert a;

		a.Default__c = false;
		
		Exception ex = null;
		try {
			update a;
		} catch (Exception e) {
			ex = e;
			system.debug('Exception here: ' + ex);	
		}
        system.assertNotEquals(ex,null,'An exception should be caught.');
        system.assert(ex.getMessage().contains('One address must be marked as Default. Marking another address as default will unmark this address.'),ex.getMessage());
	}

	//undeleting a default when there's a new default address unchecks the default on the undeleted record
	@isTest static void undeleteDefault() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Default__c = true;
		insert a;
		delete a;

		address__c a2 = initAddresses(1)[0];
		a2.Household__c = hh.id;
		a2.Default__c = true;
		insert a2;

		//need this to run @future method
		test.startTest();
		undelete a;
		test.stopTest();
		
		Address__c queryAddress = [SELECT Default__c FROM Address__c WHERE ID = :a.id];
		system.assert(!queryAddress.Default__c, 'Undeleting a default address with a new default in place should uncheck default on the undeleted record.');
	}

	//updating a current address updates the address on contacts and households
	@isTest static void updateContactAndHousehold() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Default__c = true;
		insert a;

		a.Street__c = 'Sesame Street';
		update a;

		npo02__Household__c queryhh = [SELECT Id, npo02__MailingStreet__c FROM npo02__Household__c WHERE Id = :hh.id];
		system.assertEquals('Sesame Street',queryhh.npo02__MailingStreet__c, 'Household address should be updated.');

		Contact querycon = [SELECT Id, MailingStreet FROM Contact WHERE Id = :c.id];
		system.assertEquals('Sesame Street',querycon.MailingStreet, 'Contact address should be updated.');
	}
	
	//A single non-seasonal address is automatically marked as default
	@isTest static void markSingleAsDefault() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;

		insert a;

		Address__c queryadd = [SELECT Id, Default__c FROM Address__c WHERE Id = :a.id];

		system.assert(queryadd.Default__c, 'A single non-seasonal address should automatically be marked as default');
	}

	//Marking a new address as default unmarks the previous default and updates contact and household
	@isTest static void newDefaultUnmarksPrevious() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		insert hh;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		insert c;

		address__c a = initAddresses(1)[0];
		a.Household__c = hh.id;
		a.Default__c = true;
		insert a;

		address__c a2 = initAddresses(1)[0];
		a2.Household__c = hh.id;
		a2.Default__c = true;
		a2.City__c = 'Shangri-La';
		insert a2;

		Address__c queryadd = [SELECT Id, Default__c FROM Address__c WHERE Id = :a.id];

		system.assert(!queryadd.Default__c, 'Marking a new address as default unmarks the previous default.');

		npo02__Household__c queryhh = [SELECT Id, npo02__MailingCity__c FROM npo02__Household__c WHERE Id = :hh.id];
		system.assertEquals('Shangri-La',queryhh.npo02__MailingStreet__c, 'Household address should be updated.');

		Contact querycon = [SELECT Id, MailingCity FROM Contact WHERE Id = :c.id];
		system.assertEquals('Shangri-La',querycon.MailingStreet, 'Contact address should be updated.');
	}

	//scheduler correctly catches and enables today's seasonal addresses, disables todays expiring addresses
	@isTest static void testSched() {
		npo02__Household__c hh = new npo02__Household__c(name='foo');
		npo02__Household__c hh2 = new npo02__Household__c(name='foo2');
		insert hh;
		insert hh2;
		Contact c = new Contact(lastname='foo', npo02__Household__c=hh.id);
		Contact c2 = new Contact(lastname='foo', npo02__Household__c=hh2.id);
		insert c;
		insert c2;

		string thisday = string.valueOf(system.today().day());
		string thismonth = string.valueOf(system.today().month());
		string lastmonth = string.valueOf(system.today().addMonths(-1).month());
		string nextmonth = string.valueOf(system.today().addMonths(1).month());

		list<address__c> aList = initAddresses(3);
		aList[0].Household__c = hh.id;
		aList[0].Default__c = true;
		aList[0].City__c = 'default';
		aList[1].Household__c = hh2.id;
		aList[1].Default__c = true;
		aList[1].City__c = 'default';

		//number 2 on the list we want to be active after insert, then we'll update it for the season to finish today
		aList[2].City__c = 'seasonal starts active';
		aList[2].Household__c = hh2.id;
		aList[2].Start_Month__c = lastmonth;
		aList[2].Start_Day__c = '1';
		aList[2].End_Month__c = nextmonth;
		aList[2].End_Day__c = thisday;
		insert aList;

		//this address' season is starting today
		address__c a2 = initAddresses(1)[0];
		a2.Household__c = hh.id;
		a2.Start_Month__c = thismonth;
		a2.Start_Day__c = thisday;
		a2.End_Month__c = lastmonth;
		a2.End_Day__c = '1';
		a2.City__c = 'Seasonal starts inactive';

		//don't let triggers run on insert so we can test batch class
		//insert season starting today, update season ending today
		Address.isRunning = true;
		insert a2;
		aList[2].End_Month__c = thismonth;
		update aList[2];
		Address.isRunning = false;
		
		//now verify that things are as we want them before running the batch class
		Address__c queryaddress1 = [SELECT Id, Current__c FROM Address__c WHERE ID = :aList[2].id];
		system.assertEquals(true, queryaddress1.Current__c, 'The address ending today should still be active.');

		Address__c queryaddress2 = [SELECT Id, Current__c FROM Address__c WHERE ID = :a2.id];
		system.assertEquals(false, queryaddress2.Current__c, 'The address taking effect today should not yet be active.');

		list<npo02__Household__c> queryhh = [SELECT Id, npo02__MailingCity__c FROM npo02__Household__c];
		system.debug('nic1!' + queryhh);

		test.StartTest();
		BATCH_Address ba = new BATCH_Address();
		id batchprocess = Database.executeBatch(ba);
		test.StopTest();
		
		queryhh = [SELECT Id, npo02__MailingCity__c FROM npo02__Household__c];
		system.debug('nic2!' + queryhh);

		//after running the batch, test that all is well.
		queryaddress1 = [SELECT Id, Current__c FROM Address__c WHERE ID = :aList[2].id];
		system.assertEquals(false, queryaddress1.Current__c, 'The address ending today should no longer be active.');

		queryaddress2 = [SELECT Id, Current__c FROM Address__c WHERE ID = :a2.id];
		system.assertEquals(true, queryaddress2.Current__c, 'The address taking effect today should now be active.');
	}
}