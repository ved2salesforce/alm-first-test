/**
 * @description Manages restaurant records and their associated accounts.
 *              Implements bulkified, security-enforced patterns per WI-000003.
 *              agentforce_ready: true
 *
 * Governance compliance:
 *  - No SOQL inside loops (queries are bulkified and executed once)
 *  - No DML inside loops (DML is performed in bulk after loop processing)
 *  - CRUD/FLS checks enforced via WITH USER_MODE (API v56+)
 *  - No hardcoded Salesforce IDs
 *  - No dynamic SOQL/SOSL injection vectors
 */
public with sharing class RestaurantManagerAgent {

    // ─── Custom Exception ────────────────────────────────────────────────────
    public class SecurityException extends Exception {}

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * @description Processes a list of Restaurant records: enriches each record
     *              with data from its parent Account and then persists the changes
     *              in a single bulk DML call.
     *
     * @param restaurants List of Restaurant__c records to process (must not be null)
     * @return Database.SaveResult[] Results of the bulk update operation
     * @throws SecurityException if the running user lacks update permission on Restaurant__c
     */
    public static Database.SaveResult[] processRestaurants(List<Restaurant__c> restaurants) {
        if (restaurants == null || restaurants.isEmpty()) {
            return new Database.SaveResult[0];
        }

        // Phase 2: CRUD check – verify update permission before any DML
        if (!Schema.sObjectType.Restaurant__c.isUpdateable()) {
            throw new SecurityException(
                'Insufficient permissions to update Restaurant records'
            );
        }

        // Phase 1a: Collect all Account IDs in one pass (eliminates nested loop)
        Set<Id> accountIds = new Set<Id>();
        for (Restaurant__c rest : restaurants) {
            if (rest.AccountId__c != null) {
                accountIds.add(rest.AccountId__c);
            }
        }

        // Phase 1b: Single bulkified SOQL query outside the loop
        //           WITH USER_MODE enforces FLS and object-level security (API v56+)
        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, Name, Phone, BillingCity
             FROM   Account
             WHERE  Id IN :accountIds
             WITH   USER_MODE]
        );

        // Phase 1c: Enrich restaurants using Map lookup (O(n) vs O(n²))
        List<Restaurant__c> toUpdate = new List<Restaurant__c>();
        for (Restaurant__c rest : restaurants) {
            Account parentAccount = (rest.AccountId__c != null)
                ? accountMap.get(rest.AccountId__c)
                : null;

            if (parentAccount != null) {
                rest.AccountName__c = parentAccount.Name;
                rest.AccountPhone__c = parentAccount.Phone;
                rest.AccountCity__c  = parentAccount.BillingCity;
            }
            rest.IsProcessed__c = true;
            toUpdate.add(rest);
        }

        // Phase 1d: Single bulk DML outside the loop
        Database.SaveResult[] results = Database.update(toUpdate, false);
        return results;
    }

    /**
     * @description Retrieves all active restaurants for a given set of Account IDs.
     *              Enforces FLS via WITH USER_MODE.
     *
     * @param accountIds Set of Account IDs to filter by (must not be null)
     * @return List of matching Restaurant__c records
     */
    public static List<Restaurant__c> getRestaurantsByAccounts(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new List<Restaurant__c>();
        }

        // Object-level read check
        if (!Schema.sObjectType.Restaurant__c.isAccessible()) {
            throw new SecurityException(
                'Insufficient permissions to read Restaurant records'
            );
        }

        // Bulkified query with USER_MODE for FLS enforcement
        return [
            SELECT Id, Name, AccountId__c, AccountName__c,
                   AccountPhone__c, AccountCity__c, IsProcessed__c
            FROM   Restaurant__c
            WHERE  AccountId__c IN :accountIds
            AND    IsActive__c  = TRUE
            WITH   USER_MODE
            ORDER BY Name ASC
        ];
    }

    /**
     * @description Marks a list of restaurants as inactive and deletes them in bulk.
     *
     * @param restaurantIds Set of Restaurant IDs to deactivate and delete
     * @return Database.DeleteResult[] Results of the bulk delete operation
     * @throws SecurityException if the running user lacks delete permission on Restaurant__c
     */
    public static Database.DeleteResult[] deactivateRestaurants(Set<Id> restaurantIds) {
        if (restaurantIds == null || restaurantIds.isEmpty()) {
            return new Database.DeleteResult[0];
        }

        // CRUD check for delete
        if (!Schema.sObjectType.Restaurant__c.isDeletable()) {
            throw new SecurityException(
                'Insufficient permissions to delete Restaurant records'
            );
        }

        List<Restaurant__c> toDelete = [
            SELECT Id
            FROM   Restaurant__c
            WHERE  Id IN :restaurantIds
            WITH   USER_MODE
        ];

        return Database.delete(toDelete, false);
    }
}
