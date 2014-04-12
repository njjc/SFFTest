trigger Contact on Contact (before insert, before update) {
//trigger updates primary/mailing address when Active_Address__c field changes or is populated on a new contact
	
	//only run this trigger if this change isn't coming from the processing class.
	if (!Address.isRunning) {
		
		map<id,Address__c> addressMap = new map<id,Address__c>();

		for (Contact c : trigger.new) {
			//we'll use a new contact if this is an insert for the comparison, as our field on the new contact will be equal to null
			Contact oldCon = trigger.isInsert ? new Contact() : trigger.oldMap.get(c.id);

			//if address is not null on insert, or has changed on update, add to the keyset for query
			if (c.Active_Address__c != oldCon.Active_Address__c) {
				addressMap.put(c.Active_Address__c, null);
			}
		}

		if (!addressMap.isEmpty()) {
			//populate map with address sObjects
			addressMap = new map<id,Address__c>([SELECT Id, Street__c, City__c, State__c, Postal_Code__c, Country__c, Address_Type__c 
												 FROM Address__c WHERE Id IN :addressMap.keySet()]);

			for (Contact c : trigger.new) {
				Contact oldCon = trigger.isInsert ? new Contact() : trigger.oldMap.get(c.id);
				if (c.Active_Address__c != oldCon.Active_Address__c) {
					if (c.Active_Address__c == null) {
						//active address has changed to null, we could null out the address fields if we wanted to,
						//after verifying that the user hasn't updated them manually in the same operation

					} else {
						//update primary address and type. We don't care if the user has selected the override here,
						//because we want them to be able to select a new address on a contact with override enabled
						Address__c a = addressMap.get(c.Active_Address__c);
						c.MailingStreet = a.Street__c;
						c.MailingCity = a.City__c;
						c.MailingState = a.State__c;
						c.MailingPostalCode = a.Postal_Code__c;
						c.MailingCountry = a.Country__c;
						c.npe01__Primary_Address_Type__c = a.Address_Type__c;
					}
				}
			}	
		}	
	}
}