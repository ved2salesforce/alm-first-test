/**
 * @description Service class for managing Restaurant__c records.
 *              Implements bulkified patterns (no SOQL/DML inside loops) and
 *              enforces CRUD/FLS checks to comply with CWE-862 and governance
 *              policy Enforce_CRUD_FLS_Checks (a2Rxx000000002AAA).
 *
 * @author      Builder Agent
 * @since       2026-09-16
 * @agentforce_ready true
 */
public with sharing class RestaurantService {

    /**
     * @description Updates the AccountName__c and Status__c fields on a list
     *              of Restaurant__c records based on their linked Account.
     *              Fully bulkified: all SOQL and DML are performed outside any
     *              loop, and a Map-based lookup replaces the original nested
     *              loop (O(n) complexity instead of O(n²)).
     *
     * @param restaurants  The list of Restaurant__c records to process.
     * @throws SecurityException if the running user lacks CRUD/FLS permissions.
     */
    public static void updateRestaurantAccounts(List<Restaurant__c> restaurants) {

        if (restaurants == null || restaurants.isEmpty()) {
            return;
        }

        // ── CRUD / FLS checks (Policy a2Rxx000000002AAA) ─────────────────────
        // Verify object-level read permission on Account before SOQL.
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new SecurityException(
                'Insufficient privileges: cannot read Account records.'
            );
        }
        // Verify field-level read permission on Account.Name before SOQL.
        if (!Schema.sObjectType.Account.fields.Name.isAccessible()) {
            throw new SecurityException(
                'Insufficient privileges: cannot read Account.Name field.'
            );
        }
        // Verify object-level update permission on Restaurant__c before DML.
        if (!Schema.sObjectType.Restaurant__c.isUpdateable()) {
            throw new SecurityException(
                'Insufficient privileges: cannot update Restaurant__c records.'
            );
        }

        // ── Bulkification Phase 1: Collect Account Ids in a single pass ───────
        // Eliminates the nested loop (original line 8 anti-pattern) and the
        // SOQL-inside-loop anti-pattern by gathering all IDs first.
        Set<Id> accountIds = new Set<Id>();
        for (Restaurant__c rest : restaurants) {
            if (rest.AccountId__c != null) {
                accountIds.add(rest.AccountId__c);
            }
        }

        // ── Bulkification Phase 2: Single SOQL query outside any loop ─────────
        // WITH USER_MODE enforces FLS at the query-engine level (API v56+),
        // satisfying policy Enforce_CRUD_FLS_Checks (a2Rxx000000002AAA).
        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, Name FROM Account WHERE Id IN :accountIds WITH USER_MODE]
        );

        // ── Bulkification Phase 3: Map lookup replaces inner loop ─────────────
        // Collect records that need saving so we can perform a single bulk DML.
        List<Restaurant__c> toUpdate = new List<Restaurant__c>();

        for (Restaurant__c rest : restaurants) {
            if (rest.AccountId__c != null) {
                Account acc = accountMap.get(rest.AccountId__c);
                if (acc != null) {
                    rest.AccountName__c = acc.Name;
                    rest.Status__c      = RestaurantConstants.STATUS_ACTIVE;
                    toUpdate.add(rest);
                }
            }
        }

        // ── Bulkification Phase 4: Single bulk DML outside the loop ──────────
        // Replaces the original update-inside-loop anti-pattern (line 32).
        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(toUpdate, false);
            handleSaveResults(results);
        }
    }

    /**
     * @description Logs any DML errors from a list of SaveResult objects.
     *
     * @param results  The Database.SaveResult list to inspect.
     */
    @TestVisible
    private static void handleSaveResults(Database.SaveResult[] results) {
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(
                        LoggingLevel.ERROR,
                        'RestaurantService error: '
                            + err.getStatusCode()
                            + ' – '
                            + err.getMessage()
                    );
                }
            }
        }
    }
}
