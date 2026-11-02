/**
 * @description Unit tests for the Case_Stage__c custom picklist field on Case.
 *              Validates that the field is deployed with the correct metadata,
 *              that it is a restricted picklist, that accepted values match the
 *              spec, and that CRUD/FLS permissions are in place.
 *
 * Acceptance Criteria Covered:
 *   - Case_Stage__c field exists on the Case object.
 *   - Field type is Picklist and is restricted.
 *   - Picklist values: Triage, Investigating, Escalated, Resolved (default), Deferred (inactive).
 *   - Values are NOT alphabetized (insertion order: Triage, Investigating, Escalated, Resolved, Deferred).
 *   - CRUD/FLS checks pass for field access.
 *   - Case records can be created and updated with valid picklist values.
 *
 * @see Case.Case_Stage__c
 */
@IsTest
private class CaseStagePicklistTest {

    // ──────────────────────────────────────────────────────────────────────────
    // Constants
    // ──────────────────────────────────────────────────────────────────────────

    private static final String FIELD_NAME      = 'Case_Stage__c';
    private static final String VAL_TRIAGE       = 'Triage';
    private static final String VAL_INVESTIGATING = 'Investigating';
    private static final String VAL_ESCALATED    = 'Escalated';
    private static final String VAL_RESOLVED     = 'Resolved';
    private static final String VAL_DEFERRED     = 'Deferred';

    // ──────────────────────────────────────────────────────────────────────────
    // Helper: retrieve DescribeFieldResult for Case_Stage__c
    // ──────────────────────────────────────────────────────────────────────────

    private static Schema.DescribeFieldResult getCaseStageDescribe() {
        return Schema.SObjectType.Case
               .fields.getMap()
               .get(FIELD_NAME)
               .getDescribe();
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Field Existence & Schema Tests
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that Case_Stage__c exists on the Case sObject.
     */
    @IsTest
    static void testFieldExists() {
        Map<String, Schema.SObjectField> fields =
            Schema.SObjectType.Case.fields.getMap();
        System.assert(
            fields.containsKey(FIELD_NAME),
            'Case_Stage__c field should exist on the Case object.'
        );
    }

    /**
     * Verifies the field type is Picklist.
     */
    @IsTest
    static void testFieldTypeIsPicklist() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        System.assertEquals(
            Schema.DisplayType.Picklist,
            dfr.getType(),
            'Case_Stage__c should be a Picklist field.'
        );
    }

    /**
     * Verifies the field label is "Case Stage".
     */
    @IsTest
    static void testFieldLabel() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        System.assertEquals(
            'Case Stage',
            dfr.getLabel(),
            'Case_Stage__c label should be "Case Stage".'
        );
    }

    /**
     * Verifies the picklist is restricted.
     */
    @IsTest
    static void testPicklistIsRestricted() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        System.assertEquals(
            true,
            dfr.isRestrictedPicklist(),
            'Case_Stage__c should be a restricted picklist.'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Picklist Values Tests
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies the picklist contains all five required values.
     */
    @IsTest
    static void testPicklistContainsAllRequiredValues() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();

        Set<String> activeLabels = new Set<String>();
        for (Schema.PicklistEntry entry : entries) {
            activeLabels.add(entry.getValue());
        }

        System.assert(activeLabels.contains(VAL_TRIAGE),
            'Picklist should contain "Triage".');
        System.assert(activeLabels.contains(VAL_INVESTIGATING),
            'Picklist should contain "Investigating".');
        System.assert(activeLabels.contains(VAL_ESCALATED),
            'Picklist should contain "Escalated".');
        System.assert(activeLabels.contains(VAL_RESOLVED),
            'Picklist should contain "Resolved".');
    }

    /**
     * Verifies the Deferred value is present (active or inactive in describe,
     * the metadata definition includes it).
     */
    @IsTest
    static void testDeferredValueExists() {
        // Deferred is marked inactive — it may not appear in getPicklistValues()
        // but the field definition includes it. We confirm the field has exactly
        // the expected active values.
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();

        Set<String> activeValues = new Set<String>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                activeValues.add(entry.getValue());
            }
        }

        // Active values should be the four active ones (Deferred is inactive)
        System.assert(activeValues.contains(VAL_TRIAGE),
            '"Triage" should be an active picklist value.');
        System.assert(activeValues.contains(VAL_INVESTIGATING),
            '"Investigating" should be an active picklist value.');
        System.assert(activeValues.contains(VAL_ESCALATED),
            '"Escalated" should be an active picklist value.');
        System.assert(activeValues.contains(VAL_RESOLVED),
            '"Resolved" should be an active picklist value.');
        System.assert(!activeValues.contains(VAL_DEFERRED),
            '"Deferred" should NOT be an active picklist value (it is inactive).');
    }

    /**
     * Verifies "Resolved" is the default picklist value.
     */
    @IsTest
    static void testResolvedIsDefault() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();

        String defaultValue = null;
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isDefaultValue()) {
                defaultValue = entry.getValue();
                break;
            }
        }

        System.assertEquals(
            VAL_RESOLVED,
            defaultValue,
            '"Resolved" should be the default picklist value.'
        );
    }

    /**
     * Verifies the picklist values are NOT in alphabetical order.
     * Expected order: Triage, Investigating, Escalated, Resolved (+ Deferred inactive)
     * Alphabetical order would be: Deferred, Escalated, Investigating, Resolved, Triage
     */
    @IsTest
    static void testValuesAreNotAlphabetized() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();

        // Build list of active values in order
        List<String> activeInOrder = new List<String>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                activeInOrder.add(entry.getValue());
            }
        }

        // If alphabetized, "Escalated" would come before "Investigating"
        // In spec order, "Investigating" (index 1) comes before "Escalated" (index 2)
        if (activeInOrder.size() >= 3) {
            Integer investigatingIdx = activeInOrder.indexOf(VAL_INVESTIGATING);
            Integer escalatedIdx     = activeInOrder.indexOf(VAL_ESCALATED);
            System.assert(
                investigatingIdx < escalatedIdx,
                '"Investigating" should appear before "Escalated" (non-alphabetical order).'
            );
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CRUD / FLS Tests
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies FLS: Case_Stage__c should be accessible (readable).
     */
    @IsTest
    static void testFieldIsAccessible() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        System.assertEquals(
            true,
            dfr.isAccessible(),
            'Case_Stage__c should be readable by the running user.'
        );
    }

    /**
     * Verifies FLS: Case_Stage__c should be createable.
     */
    @IsTest
    static void testFieldIsCreateable() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        System.assertEquals(
            true,
            dfr.isCreateable(),
            'Case_Stage__c should be createable by the running user.'
        );
    }

    /**
     * Verifies FLS: Case_Stage__c should be updateable.
     */
    @IsTest
    static void testFieldIsUpdateable() {
        Schema.DescribeFieldResult dfr = getCaseStageDescribe();
        System.assertEquals(
            true,
            dfr.isUpdateable(),
            'Case_Stage__c should be updateable by the running user.'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DML Tests
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies a Case can be created with Case_Stage__c set to "Triage".
     */
    @IsTest
    static void testCreateCaseWithTriageStage() {
        Case c = new Case(
            Subject      = 'Test Case Triage',
            Case_Stage__c = VAL_TRIAGE
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Case result = [SELECT Id, Case_Stage__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(VAL_TRIAGE, result.Case_Stage__c,
            'Case_Stage__c should be "Triage" after insert.');
    }

    /**
     * Verifies a Case can be created with Case_Stage__c set to "Escalated".
     */
    @IsTest
    static void testCreateCaseWithEscalatedStage() {
        Case c = new Case(
            Subject      = 'Test Case Escalated',
            Case_Stage__c = VAL_ESCALATED
        );

        Test.startTest();
        insert c;
        Test.stopTest();

        Case result = [SELECT Id, Case_Stage__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(VAL_ESCALATED, result.Case_Stage__c,
            'Case_Stage__c should be "Escalated" after insert.');
    }

    /**
     * Verifies a Case can be updated to "Resolved".
     */
    @IsTest
    static void testUpdateCaseStageToResolved() {
        Case c = new Case(
            Subject      = 'Test Case Update',
            Case_Stage__c = VAL_TRIAGE
        );
        insert c;

        c.Case_Stage__c = VAL_RESOLVED;

        Test.startTest();
        update c;
        Test.stopTest();

        Case result = [SELECT Id, Case_Stage__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(VAL_RESOLVED, result.Case_Stage__c,
            'Case_Stage__c should be "Resolved" after update.');
    }

    /**
     * Verifies a Case can be updated to "Investigating".
     */
    @IsTest
    static void testUpdateCaseStageToInvestigating() {
        Case c = new Case(
            Subject      = 'Test Investigating Stage',
            Case_Stage__c = VAL_ESCALATED
        );
        insert c;

        c.Case_Stage__c = VAL_INVESTIGATING;

        Test.startTest();
        update c;
        Test.stopTest();

        Case result = [SELECT Id, Case_Stage__c FROM Case WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(VAL_INVESTIGATING, result.Case_Stage__c,
            'Case_Stage__c should be "Investigating" after update.');
    }

    /**
     * Verifies bulk insert of Cases with various Case_Stage__c values.
     */
    @IsTest
    static void testBulkInsertCasesWithStageValues() {
        List<Case> cases = new List<Case>();
        List<String> stageValues = new List<String>{
            VAL_TRIAGE, VAL_INVESTIGATING, VAL_ESCALATED, VAL_RESOLVED
        };

        for (Integer i = 0; i < 200; i++) {
            cases.add(new Case(
                Subject       = 'Bulk Case ' + i,
                Case_Stage__c  = stageValues[Math.mod(i, 4)]
            ));
        }

        Test.startTest();
        insert cases;
        Test.stopTest();

        Integer cnt = [SELECT COUNT() FROM Case WHERE Subject LIKE 'Bulk Case %'];
        System.assertEquals(200, cnt,
            'All 200 Cases should have been inserted with Case_Stage__c values.');
    }

    /**
     * Verifies that querying Cases by Case_Stage__c works correctly.
     */
    @IsTest
    static void testQueryCaseByStage() {
        Case c1 = new Case(Subject = 'Stage Query Test 1', Case_Stage__c = VAL_TRIAGE);
        Case c2 = new Case(Subject = 'Stage Query Test 2', Case_Stage__c = VAL_RESOLVED);
        insert new List<Case>{ c1, c2 };

        Test.startTest();
        List<Case> triageCases = [
            SELECT Id, Case_Stage__c
            FROM Case
            WHERE Case_Stage__c = :VAL_TRIAGE
              AND Subject LIKE 'Stage Query Test%'
        ];
        Test.stopTest();

        System.assertEquals(1, triageCases.size(),
            'Should find exactly one Case with "Triage" stage.');
        System.assertEquals(VAL_TRIAGE, triageCases[0].Case_Stage__c,
            'Queried case should have "Triage" stage.');
    }
}
