public with sharing class Address {

	//static flag to prevent recursion
	public static boolean isRunning = false;
	
	//constructor
	public Address() {}

	//wrapper class to hold all contact and address information related to a household and facilitate calculations
	public class addressWrapper {
		//all contacts for this household
		public list<Contact> contactList = new list<Contact>();
		//all addresses currently saved for this household
		public list<Address__c> addressList = new list<Address__c>();
		//all addresses currently in trigger set for this household
		public list<Address__c> triggerList = new list<Address__c>();
		//default and current addresses for this household, and household object
		public Address__c defaultAddress = null;
		public Address__c currentAddress = null;
		public npo02__Household__c household = null;
	}

	//address trigger handler
	public void addressTrigger(list<Address__c> newList, list<address__c> oldList, map<id,Address__c> oldMap, boolean isBefore, boolean isAfter, boolean isInsert, boolean isUpdate, boolean isDelete, boolean isUndelete) {
		map<id,addressWrapper> aw = new map<id,addressWrapper>();
		Date today = System.Today();

		//Before insert / update:
		//do all possible validation before querying for related objects, to avoid excess queries
		if (isBefore && !isDelete) {
			for (Address__c a : newList) {
				//this validation applies to both inserts and updates
				if (!isSeasonal(a) && !isNotSeasonal(a)) {
					//if this address is neither seasonal nor not seasonal (i.e. no date fields filled), we have partial address information
					a.addError('Seasonal addresses must have complete start and end dates.');
				} else if (!datesAreValid(a)) {
					a.addError('Dates must be valid days of the year. February 29th is not considered a valid date to avoid seasonal addresses that only go into or out of effect on leap years.');
				} else if (isSeasonal(a) && getCurrentStart(a) == getCurrentEnd(a)){
					a.addError('A seasonal address cannot start and end on the same date.');
				} else if (a.Default__c && isSeasonal(a)) {
					a.addError('A default address cannot also be a seasonal address. Please either uncheck Default or remove seasonal dates.');
				
				//insert 
				// if this address is a default, we need to uncheck any other default addresses and update contact/household
				// if this address is not default and is the only address, it needs to be marked default
				// if this address is seasonal and is the only address, we need to prevent insertion and tell the user to create a default first
				} else if (isInsert) {
					aw.put(a.Household__c, null);
				} else if (isUpdate) {
					Address__c olda = oldMap.get(a.id);
					//validate that user can't uncheck default
					if (a.Default__c == false && olda.Default__c == true) {
						a.addError('One address must be marked as Default. Marking another address as default will unmark this address.');
					//if the dates are changed, add to processing list to make sure we don't have overlap
					//with existing addresses and we don't need to update contact addresses
					} else if (datesChanged(a,olda)) {
						aw.put(a.Household__c, null);
					}
				}
			}
		//BEFORE DELETE:
		// we need prevent deletion if this is the default and there other addresses. 
		// if this is default and the only address, deletion is fine. we'll leave the addresses on contact/household in place.
		// if it's an active seasonal address we'll need to update contacts
		} else if (isBefore && isDelete) {
			for (Address__c a : oldList) {
				if (a.Default__c) aw.put(a.Household__c,null);
			}
		//AFTER INSERT / UPDATE / DELETE / UNDELETE
		// in the after trigger, we'll assume all validation is handled. 
		// add to processing list if changes are substantative and require updating contacts/households
		} else if (isAfter) {
			for (Address__c a : isDelete ? oldList : newList) {
				
				//DELETE:
				//if we're deleting a current seasonal address, update contacts and household
				if (isDelete && inSeason(a,today)) {
					aw.put(a.Household__c, null);	
				//UNDELETE:
				// if this was a default address, set on contacts and household if there's no current default, or uncheck default
				// if this address is seasonal, we need to prevent overlap and potentially update contacts/households
				} else if (isUndelete && (a.Default__c || isSeasonal(a))) {
					aw.put(a.Household__c, null);
				//INSERT/UPDATE
				// if dates changed and today's date became in or out of inactive, update contacts and household
				// if marked Default, unmark other defaults, update contacts and household
				// if marked Default, update contacts and household, unless they're overridden or there's an active seasonal address
				// if the address has changed: need to update contacts and household if currently marked Default or currently in season, and all contacts using this address as override
				} else if (isInsert || isUpdate) {
					Address__c olda = isInsert ? new Address__c() : oldMap.get(a.id);
					if (inSeason(a,today)!=inSeason(olda,today) || 
						(a.Default__c && a.Default__c != olda.Default__c) || 
						(addressChanged(a,olda))) {
							aw.put(a.Household__c, null);
					}
				}
			}
		}

		//all validation not needing related records is complete, we have our list of records we need related records to process, 
		//we will run our queries and fill our wrapper if any records in this trigger fit our criteria
		if (!aw.isEmpty()) {
			aw = fillAddressWrapper(aw.keySet(), isDelete ? oldList : newList);
			//now that we have all necessary context to make decisions on, we'll go over necessary trigger actions again and make changes

			//BEFORE INSERT/UPDATE:
			//perform validation that we need related records to verify
			if (isBefore && (isInsert || isUpdate)) {
				for (Address__c a : newList) {
                    //if we have a wrapper for this address, i.e. previously decided this record needed processing
					if (aw.containsKey(a.Household__c)) {
						addressWrapper w = aw.get(a.Household__c);
						//first prevent overlapping addresses for records this trigger
						for (Address__c a2 : w.triggerList) {
							//this isn't the same address and is overlapping
							if (a != a2 && isOverlapping(a,a2)) 
								a.addError('Seasonal addresses can\'t overlap with other seasonal addresses for this household.');
	                    }
						//then, iterate over existing address list for this household, ensure we don't have any overlaps
						for (Address__c a2 : w.addressList) {
							if (a2 != a && isOverlapping(a,a2)) 
								a.addError('Seasonal addresses can\'t overlap with other seasonal addresses for this household.');
						}
						//no overlapping seasons at this point, set active seasonal address as current
						if (inSeason(a,today)) {
							a.Current__c = true;
							w.currentAddress = a;
						//set any address marked as default
						} else if (a.Default__c) {
							w.defaultAddress = a;
							if (w.currentAddress == null){
								a.Current__c = true;
								w.currentAddress = a;
							}
						}
					}
				}
				//now we need to loop through addresses a second time
				//to prevent inserting a list of addresses with no default
				for (Address__c a : newList) {
					if (aw.containsKey(a.Household__c)) {
						addressWrapper w = aw.get(a.Household__c);
						//this address isn't default or seasonal and we still don't have a default address, make this one default
						if (!a.Default__c && !isSeasonal(a) && w.defaultAddress == null) {
							if (w.defaultAddress == null) {
								a.Default__c = true;
								w.defaultAddress = a;
								if (w.currentAddress == null){
									a.Current__c = true;
									w.currentAddress = a;
								}
							}
						//if this address is seasonal, make sure we have a default address
						} else if (isSeasonal(a) && w.defaultAddress == null) {
							a.addError('A household must have a default address before creating a seasonal address.');
						}
					}
				}
			//BEFORE DELETE
			//prevent deletion if this is the default and there other addresses
			//while being sure we're not preventing bulk deletions of all addresses for this household
			} else if (isBefore && isDelete) {
				for (Address__c a : oldList) {
					if (aw.containsKey(a.Household__c)) {
						addressWrapper w = aw.get(a.Household__c);
						if (a.Default__c && w.addressList.size() != w.triggerList.size()) {
							a.addError('A household must have a default address, please create another default before deleting this address.');
						}
					}
				}
			//AFTER INSERT/UPDATE
			//Ensure a new default address is marked as default in our wrapper
			} else if (isAfter && (isInsert || isUpdate)) {
				for (Address__c a : newList) {
					if (aw.containsKey(a.Household__c)) {
						addressWrapper w = aw.get(a.Household__c);
						Address__c olda = isInsert ? new Address__c() : oldMap.get(a.id);
						//if this address became default in this transaction, ensure that it's default in our wrapper for later processing
						if (a.Default__c!=olda.Default__c && a.Default__c) {
							w.defaultAddress = a;
						} 
					}
				}
			//AFTER UNDELETE
			//Make sure undeleting a record isn't causing multiple defaults, or seasonal overlaps. 
			//If it is, update the newly undeleted records to not clash.
			} else if (isAfter && isUndelete) {
				map<id,string> updAddressWorkaround = new map<id,string>();
				for (Address__c a : newList) {
					if (aw.containsKey(a.Household__c)) {
						addressWrapper w = aw.get(a.Household__c);
						if (a.Default__c) {
							// if this was a default address and we have another default, remove default
							if (w.defaultAddress!=null && w.defaultAddress != a) {
								//since we can't directly modify trigger.new in undelete triggers, 
								//we'll need to use a workaround and an @future method
								updAddressWorkaround.put(a.id,'notDefault');
							// if this is current, mark as current
							} else if (w.currentAddress == a) {
								// mark current
								if (!a.Current__c) {
									updAddressWorkaround.put(a.id,'isCurrent');
								}
							}
						} else if (isSeasonal(a)) {
							// if this was a seasonal address that creates overlap, remove seasonal dates
							for (Address__c a2 : w.addressList) {
								if (a!=a2 && isOverlapping(a,a2)) {
									updAddressWorkaround.put(a.id,'notSeasonal');
								}
							}
							// if this is still a seasonal address and is currently in season, set it as current for later processing
							if (inSeason(a,today)) {
								w.currentAddress = a;
							}
						}
					}
				}
				if (!updAddressWorkaround.isEmpty()) {
					updUndeletedAddresses(updAddressWorkaround);
				}
			//AFTER DELETE
			//We don't need to do anything here because the wrapper will have the 
			//correct default/in season address and the post routine will update everything
			}
		}

		//at this point, our wrapper has correct active address information
		//process wrapper objects to updates contacts, households, and addresses where appropriate
		processAddressWrapper(aw.values());
	}

	// method fills the address wrapper with data
	//called both from trigger and batch class
	public map<id,addressWrapper> fillAddressWrapper (set<id> householdIDs, list<Address__c> triggerList) {
		map<id,addressWrapper> results = new map<id,addressWrapper>();
		
		//query for households, create wrappers, add household and trigger addresses to wrapper
		for (npo02__Household__c hh : [SELECT Id, npo02__MailingStreet__c, npo02__MailingCity__c, npo02__MailingState__c, npo02__MailingPostalCode__c, 
										npo02__MailingCountry__c FROM npo02__Household__c WHERE ID IN :householdIDs]) {
			addressWrapper w = new addressWrapper();
			w.household = hh;
			for (Address__c a : triggerList) {
				if (a.Household__c == hh.id)
					w.triggerList.add(a);
			}
			results.put(hh.id, w);
		}

		//query for address records, and fill in wrapper
		for (Address__c a : [SELECT Id, Household__c, Start_Day__c, Start_Month__c, End_Day__c, End_Month__c, Default__c, Address_Type__c, Current__c,
							 Street__c, City__c, State__c, Postal_Code__c, Country__c FROM Address__c WHERE Household__c IN :householdIDs]) {
			addressWrapper w = results.get(a.Household__c);
			
			//if this address is marked default, fill in default.
			//if current is blank, fill in with default
			if (a.Default__c) {
				w.defaultAddress = a;
				if (w.currentAddress == null)
					w.currentAddress = a;
			}
			//if this address is in season, it is the current address. Our validation has already ensured no overlapping seasons.
			if (inSeason(a,system.today())) w.currentAddress = a;

			//add this address to the list
			w.addressList.add(a);
			
		}

		//query for contact records, and fill in the wrapper
		for (Contact c : [SELECT Id, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, npe01__Primary_Address_Type__c, 
						  Active_Address__c, Override_Address__c, npo02__Household__c FROM Contact WHERE npo02__Household__c IN :householdIDs ]) {
			addressWrapper w = results.get(c.npo02__Household__c);
			w.contactList.add(c);
		}
		return results;
	}

	//processes an address wrapper and makes changes to households, contacts, and related addresses
	//called both from trigger and batch class
	public void processAddressWrapper (list<AddressWrapper> wrapper) {
		list<Contact> contactForUpdate = new list<Contact>();
		list<Address__c> addressForUpdate = new list<Address__c>();
		list<npo02__Household__c> householdForUpdate = new list<npo02__Household__c>();

		for (addressWrapper w : wrapper) {
			for (Contact c : w.contactList) {
				//only update contact address if override isn't checked and if this contact doesn't already use this address, or the address has changed
				if (!c.Override_Address__c && (c.Active_Address__c != w.currentAddress.id || contactAddressChange(c,w.currentAddress))) {
					c.Active_Address__c = w.currentAddress.id;
					contactForUpdate.add(c);
				//update override address if it has changed
				} else if (c.Override_Address__c ) {
					for (Address__c a : w.addressList) {
						if (c.Active_Address__c == a.id && contactAddressChange(c,a)) {
							contactForUpdate.add(c);
						}
					}
				}
			}
			
			if (householdAddressChange(w.household, w.currentAddress))
				//if household address is different from current, update it
				householdForUpdate.add(w.household);
			
			for (Address__c a : w.addressList) {
				//if this is marked default and isn't actually our default, uncheck it and update it
				if (a.Default__c && w.defaultAddress.id != a.id) {
					a.Default__c = false;
					addressForUpdate.add(a);
				}
				//if this is marked current and isn't actually current, uncheck it and update it
				if (a.Current__c && w.currentAddress.id != a.id) {
					a.Default__c = false;
					addressForUpdate.add(a);
				}
			}
		}

		//prevent recursion, update records
		isRunning = true;
		if (!householdForUpdate.isEmpty())
			update householdForUpdate;
		if (!contactForUpdate.isEmpty())
			update contactForUpdate;
		if (addressForUpdate.isEmpty())
			update addressForUpdate;
		isRunning = false;
	}

	//future method to update addresses after undelete, as DML is not allowed on records that are part of an undelete trigger
	//I'm using a map with codes here as sObjects are not allowed as parameters to @future methods
	@future
  	private static void updUndeletedAddresses(map<id,string> codeMap) {

		list<Address__c> aList = new list<Address__c>();
		for (id i : codeMap.keySet()) {
			Address__c a = new Address__c(id = i);
			if (codeMap.get(i)=='notDefault') {
				a.Default__c = false;
			} else if (codeMap.get(i)=='notSeasonal') {
				a.Start_Day__c = null;
				a.Start_Month__c = null;
				a.End_Day__c = null;
				a.End_month__c = null;
			} else if (codeMap.get(i)=='isCurrent') {
				a.Current__c = true;
			}
			aList.add(a);
		}
		isRunning = true;
		update aList;
		isRunning = false;
  	}

	//checks if all seasonal fields are filled out
	private boolean isSeasonal(Address__c a) {
		return (a.Start_Month__c != null && a.Start_Day__c != null && a.End_Day__c != null && a.End_month__c != null);
	}

	//checks if all seasonal fields are blank
	private boolean isNotSeasonal(Address__c a) {
		return (a.Start_Month__c == null && a.Start_Day__c == null && a.End_Day__c == null && a.End_month__c == null);
	}

	//returns this year's start date for any given address object
	private Date getCurrentStart (Address__c a) {
		if (a==null || !isSeasonal(a)) return null;

		return date.newInstance(system.today().year(), integer.valueOf(a.Start_Month__c), integer.valueOf(a.Start_Day__c));
	}

	//returns this year's end date for any given address object, which could be next year in the case of an overlapping season
	private Date getCurrentEnd (Address__c a) {
		if (a==null || !isSeasonal(a)) return null;

		date thisStart = getCurrentStart(a);
		date thisEnd = date.newInstance(system.today().year(), integer.valueOf(a.End_Month__c), integer.valueOf(a.End_Day__c));

		if (thisStart <= thisEnd) {
			return thisEnd;
		} else {
			return thisEnd.addYears(1);
		}
	}

	//checks if any given date is within an addresses' season
	private boolean inSeason(Address__c a, Date d) {
		if (a==null || d==null || !isSeasonal(a)) return false;
		
		//two cases: the season is contained within a single year, in which case the calculation is trivial
		//or the season overlaps the end of the year, in which case we need to compare to this year's season
		//as well as last year's season
		
		//yearShift brings our dates into the year range of d
		integer thisYear = system.today().year();
		integer yearShift = d.year() - thisYear;

		//if this address doesn't have an overlapping season, i.e. it is contained within a single year,
		//then our date must be after or on the start date AND before the end date to be in season
		if (getCurrentEnd(a).year() == thisYear) {
			return (getCurrentStart(a).addYears(yearShift) <= d && d < getCurrentEnd(a).addYears(yearShift));
		
		//this address does have an overlapping season, i.e. the start and end dates are in different years,
		//then our date must be after this year's start date OR before last year's end date to be in season
		} else {
			return (getCurrentStart(a).addYears(yearShift) <= d || d < getCurrentEnd(a).addYears(yearShift-1));
		}
	}

	//checks if two addresses' seasons are overlapping
	private boolean isOverlapping(Address__c a1, Address__c a2) {
		if (a1 == null || a2 == null || !isSeasonal(a1) || !isSeasonal(a2))
			return false;

		//is overlapping:
		//start date of a1 is within the season of a2
		//OR the start date of a2 is within the season of a1
		return (inSeason(a1, getCurrentStart(a2)) || inSeason(a2, getCurrentStart(a1)));
	}

	//detects differences seasonal in dates between two addresses
	private boolean datesChanged (Address__c a1, Address__c a2) {
		if (a1 == null && a2 == null)
			return false;
		else if (a1 == null || a2 == null)
			return true;
		return (a1.Start_Day__c != a2.Start_Day__c || 
				a1.Start_Month__c != a2.Start_Month__c || 
				a1.End_Day__c != a2.End_Day__c || 
				a1.End_Month__c != a2.End_Month__c);
	}

	//detects differences between two addresses
	private boolean addressChanged (Address__c a1, Address__c a2) {
		if (a1 == null || a2 == null)
			return false;
		return (a1.Street__c != a2.Street__c || 
				a1.City__c != a2.City__c || 
				a1.State__c != a2.State__c || 
				a1.Postal_Code__c != a2.Postal_Code__c || 
				a1.Country__c != a2.Country__c || 
				a1.Address_Type__c != a2.Address_Type__c);
	}
    
    //ensures both dates on an address are valid
    public boolean datesAreValid (Address__c a) {
		if (a == null || !isSeasonal(a))
			return true;

        integer startMonth = integer.valueOf(a.Start_Month__c);
        integer startDay = integer.valueOf(a.Start_Day__c);
        integer endMonth = integer.valueOf(a.End_Month__c);
        integer endDay = integer.valueOf(a.End_Day__c);

        return (validDate(startMonth, startDay) && validDate(endMonth, endDay));
    }

    //method ensures a single month / day pair is valid
    public boolean validDate (integer month, integer day) {
    	if (month==null || day==null) return false;
    	//Not allowing Feb. 29th to prevent seasonal dates that only activate every fourth year.
    	if (month==2 && day>28) return false;
    	else return ( Date.daysInMonth(system.today().year(), month) >= day);
    }

    //method updates household address fields, and returns true if any fields were changed
    public boolean householdAddressChange(npo02__Household__c hh, Address__c a) {
    	if (hh.npo02__MailingStreet__c != a.Street__c ||
    		hh.npo02__MailingCity__c != a.City__c ||
    		hh.npo02__MailingState__c != a.State__c ||
    		hh.npo02__MailingPostalCode__c != a.Postal_Code__c ||
			hh.npo02__MailingCountry__c != a.Country__c) {

    		hh.npo02__MailingStreet__c = a.Street__c;
    		hh.npo02__MailingCity__c = a.City__c;
    		hh.npo02__MailingState__c = a.State__c;
    		hh.npo02__MailingPostalCode__c = a.Postal_Code__c;
			hh.npo02__MailingCountry__c = a.Country__c;
			return true;
    	} else return false;
    }

    //method updates contact address fields, and returns true if any fields were changed
    public boolean contactAddressChange(Contact c, Address__c a) {
    	if (c.MailingStreet != a.Street__c ||
    		c.MailingCity != a.City__c ||
    		c.MailingState != a.State__c ||
    		c.MailingPostalCode != a.Postal_Code__c ||
			c.MailingCountry != a.Country__c ||
			c.Active_Address__c != a.id) {

    		c.MailingStreet = a.Street__c;
    		c.MailingCity = a.City__c;
    		c.MailingState = a.State__c;
    		c.MailingPostalCode = a.Postal_Code__c;
			c.MailingCountry = a.Country__c;
			return true;
    	} else return false;
    }
}