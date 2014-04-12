trigger Address on Address__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	//only run trigger if it wasn't fired from inside the class
	if (!Address.isRunning) {
		Address a = new Address();
		a.addressTrigger(trigger.new, trigger.old, trigger.oldmap, trigger.isBefore, trigger.isAfter, trigger.isInsert, trigger.isUpdate, trigger.isDelete, trigger.isUndelete);
	}
}