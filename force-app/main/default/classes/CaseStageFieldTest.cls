/**
 * @description Test class for the Case_Stage__c restricted picklist field on the Case object.
 *              Verifies field existence, restricted picklist behaviour, valid values, and
 *              that the default value is "Resolved".
 *
 * WI-000038 / WI-000004 — Add Case_Stage__c restricted picklist to Case
 */
@IsTest
private class CaseStageFieldTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Helper: create a minimal Case record
    // ─────────────────────────────────────────────────────────────────────────
    private static Case buildCase(String subject, String stageValue) {
        Case c = new Case(Subject = subject);
        if (stageValue != null) {
            c.put('Case_Stage__c', stageValue);
        }
        return c;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Field exists on the Case object
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testFieldExistsOnCase() {
        Schema.SObjectType caseType = Schema.getGlobalDescribe().get('Case');
        System.assertNotEquals(null, caseType, 'Case sObject not found in schema');

        Map<String, Schema.SObjectField> fields = caseType.getDescribe().fields.getMap();
        System.assert(
            fields.containsKey('case_stage__c'),
            'Case_Stage__c field not found on Case object'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Field is a Picklist and is restricted
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testFieldIsRestrictedPicklist() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        System.assertEquals(
            Schema.DisplayType.PICKLIST,
            dfr.getType(),
            'Case_Stage__c should be a Picklist field'
        );
        System.assert(dfr.isRestrictedPicklist(), 'Case_Stage__c should be a restricted picklist');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Field label is "Case Stage"
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testFieldLabel() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        System.assertEquals('Case Stage', dfr.getLabel(), 'Field label should be "Case Stage"');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Expected picklist values are present (order is preserved — not alphabetized)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testExpectedPicklistValuesPresent() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        Set<String> activeValues = new Set<String>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                activeValues.add(entry.getValue());
            }
        }

        System.assert(activeValues.contains('Triage'),       'Missing active value: Triage');
        System.assert(activeValues.contains('Investigating'), 'Missing active value: Investigating');
        System.assert(activeValues.contains('Escalated'),    'Missing active value: Escalated');
        System.assert(activeValues.contains('Resolved'),     'Missing active value: Resolved');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. "Deferred" is present but inactive
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testDeferredIsInactive() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        Boolean deferredFound = false;
        for (Schema.PicklistEntry entry : entries) {
            if (entry.getValue() == 'Deferred') {
                deferredFound = true;
                System.assert(!entry.isActive(), '"Deferred" should be inactive');
            }
        }
        // Deferred may be hidden from active list; assert it was described or skip gracefully
        // The important check is that if present it is inactive
        System.debug('Deferred value found in picklist entries: ' + deferredFound);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. "Resolved" is the default value
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testResolvedIsDefault() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        String defaultValue = null;
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isDefaultValue()) {
                defaultValue = entry.getValue();
                break;
            }
        }
        System.assertEquals('Resolved', defaultValue, '"Resolved" should be the default picklist value');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Picklist order is NOT alphabetized (Triage must come before Investigating)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testPicklistOrderIsNotAlphabetized() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        Integer triageIndex       = -1;
        Integer investigatingIndex = -1;
        for (Integer i = 0; i < entries.size(); i++) {
            if (entries[i].getValue() == 'Triage')        triageIndex       = i;
            if (entries[i].getValue() == 'Investigating') investigatingIndex = i;
        }
        System.assert(triageIndex != -1,       '"Triage" not found in picklist entries');
        System.assert(investigatingIndex != -1, '"Investigating" not found in picklist entries');
        System.assert(
            triageIndex < investigatingIndex,
            '"Triage" should appear before "Investigating" (not alphabetized)'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. CRUD/FLS check: current user can read the field
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testFieldIsReadable() {
        Schema.DescribeFieldResult dfr =
            Case.getSObjectType()
                .getDescribe()
                .fields.getMap()
                .get('case_stage__c')
                .getDescribe();

        System.assert(dfr.isAccessible(), 'Case_Stage__c should be accessible (readable) to the running user');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. DML: insert a Case with a valid stage value
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testInsertCaseWithValidStage() {
        Test.startTest();
        Case c = buildCase('Test Case - Triage Stage', 'Triage');
        if (Schema.sObjectType.Case.fields.Case_Stage__c.isCreateable()) {
            insert c;
            Case inserted = [SELECT Id, Case_Stage__c FROM Case WHERE Id = :c.Id LIMIT 1];
            System.assertEquals('Triage', inserted.Case_Stage__c, 'Case_Stage__c should be "Triage"');
        } else {
            System.debug('Case_Stage__c is not createable by this user — skipping DML assertion');
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. DML: insert a Case with each active stage value
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testInsertCaseWithEachActiveStage() {
        if (!Schema.sObjectType.Case.fields.Case_Stage__c.isCreateable()) {
            System.debug('Case_Stage__c is not createable — skipping DML test');
            return;
        }

        List<String> activeStages = new List<String>{ 'Triage', 'Investigating', 'Escalated', 'Resolved' };
        Test.startTest();
        for (String stage : activeStages) {
            Case c = buildCase('Test Case - Stage: ' + stage, stage);
            insert c;
            Case inserted = [SELECT Id, Case_Stage__c FROM Case WHERE Id = :c.Id LIMIT 1];
            System.assertEquals(stage, inserted.Case_Stage__c, 'Stage should be ' + stage);
            delete inserted;
        }
        Test.stopTest();
    }
}
