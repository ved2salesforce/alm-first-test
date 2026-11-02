/**
 * @description Utility class for diagnosing and validating Named Credential
 *              configurations used by DevOps Center pipeline promotion callouts.
 *
 *              WI-000030: Remediate Bad OAuth Token Causing Promotion Failure
 *
 *              When a DevOps Center promotion fails with:
 *                {"errorType":"UNKNOWN","errorMessage":"Error while resuming
 *                promotion: Unexpected response from named credential
 *                callout: Bad_OAuth_Token"}
 *
 *              This class provides helper methods to:
 *              1. Query and report on NamedCredential records visible to the
 *                 running user.
 *              2. Verify that the running user has permissions to manage
 *                 Named Credentials (Customize Application permission).
 *              3. Validate pre-requisites required to remediate the issue.
 *              4. Log a structured health-check report to aid remediation.
 *
 * Governance compliance:
 *  - with sharing enforced (respects org sharing rules)
 *  - No SOQL inside loops
 *  - No DML inside loops
 *  - CRUD/FLS checks enforced before all object/field access
 *  - No hardcoded Salesforce IDs
 *  - No dynamic SOQL/SOSL injection vectors
 *
 * @author  Builder Agent
 * @since   2026-11-02
 */
public with sharing class NamedCredentialHealthCheck {

    // ─── Custom Exception ────────────────────────────────────────────────────

    /** Thrown when a required permission or configuration is missing. */
    public class HealthCheckException extends Exception {}

    // ─── Inner DTO ───────────────────────────────────────────────────────────

    /**
     * @description Lightweight data-transfer object representing the health
     *              status of a single Named Credential record.
     */
    public class CredentialStatus {
        /** Developer name (API name) of the Named Credential. */
        public String developerName;
        /** Human-readable label of the Named Credential. */
        public String masterLabel;
        /** Endpoint URL stored on the Named Credential. */
        public String endpoint;
        /** Authentication protocol (e.g. OAuth, Password). */
        public String authProvider;
        /**
         * Whether the credential appears reachable based on metadata
         * (true = metadata found and readable; false = record missing or
         * inaccessible).
         */
        public Boolean isConfigured;

        /** Default constructor. */
        public CredentialStatus() {
            this.isConfigured = false;
        }
    }

    // ─── Public Methods ──────────────────────────────────────────────────────

    /**
     * @description Returns a list of {@link CredentialStatus} objects for all
     *              Named Credential records visible to the running user.
     *
     *              Performs a CRUD check before querying and maps each record
     *              to a {@link CredentialStatus} DTO.
     *
     * @return  List of CredentialStatus (may be empty; never null).
     * @throws  HealthCheckException if the running user cannot read
     *          NamedCredential records.
     */
    public static List<CredentialStatus> getCredentialStatuses() {

        // CRUD: verify read access to NamedCredential before querying
        if (!Schema.sObjectType.NamedCredential.isAccessible()) {
            throw new HealthCheckException(
                'Insufficient privileges: cannot read NamedCredential records. '
                + 'Ensure the running user has the "Customize Application" or '
                + '"Manage Named Credentials" permission.'
            );
        }

        List<NamedCredential> credentials = [
            SELECT Id, DeveloperName, MasterLabel, Endpoint, PrincipalType
            FROM   NamedCredential
            WITH   USER_MODE
            ORDER  BY MasterLabel ASC
        ];

        List<CredentialStatus> statuses = new List<CredentialStatus>();

        for (NamedCredential nc : credentials) {
            CredentialStatus cs = new CredentialStatus();
            cs.developerName    = nc.DeveloperName;
            cs.masterLabel      = nc.MasterLabel;
            cs.endpoint         = nc.Endpoint;
            cs.authProvider     = nc.PrincipalType;
            cs.isConfigured     = true;
            statuses.add(cs);
        }

        return statuses;
    }

    /**
     * @description Logs a structured health-check report for all Named
     *              Credentials to the debug log.
     *
     *              Intended to be called from an anonymous Apex script or a
     *              scheduled job to surface configuration issues after a
     *              promotion failure (e.g. Bad_OAuth_Token).
     *
     * @return  The number of Named Credential records found and reported.
     */
    public static Integer logHealthReport() {

        List<CredentialStatus> statuses;
        try {
            statuses = getCredentialStatuses();
        } catch (HealthCheckException ex) {
            System.debug(LoggingLevel.ERROR,
                'NamedCredentialHealthCheck.logHealthReport — access denied: '
                + ex.getMessage()
            );
            return 0;
        }

        System.debug(LoggingLevel.INFO,
            'NamedCredentialHealthCheck — found ' + statuses.size()
            + ' Named Credential(s).'
        );

        for (CredentialStatus cs : statuses) {
            System.debug(LoggingLevel.INFO,
                'Named Credential: [' + cs.developerName + '] '
                + 'label="'        + cs.masterLabel   + '" '
                + 'endpoint="'     + cs.endpoint       + '" '
                + 'authProvider="' + cs.authProvider   + '" '
                + 'isConfigured='  + cs.isConfigured
            );
        }

        if (statuses.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'NamedCredentialHealthCheck — no Named Credential records '
                + 'found. Verify that at least one Named Credential is '
                + 'configured for DevOps Center pipeline promotion callouts.'
            );
        }

        return statuses.size();
    }

    /**
     * @description Checks whether the running user has the
     *              "Customize Application" system permission, which is
     *              required to manage Named Credentials and re-authenticate
     *              OAuth flows.
     *
     * @return  true if the user has the required permission; false otherwise.
     */
    public static Boolean hasNamedCredentialManagementPermission() {
        return FeatureManagement.checkPermission('CustomizeApplication');
    }

    /**
     * @description Validates the pre-requisite access needed to perform the
     *              Named Credential remediation described in WI-000030 and
     *              returns a human-readable summary message.
     *
     *              Checks validated:
     *              1. NamedCredential CRUD read access.
     *              2. Customize Application permission (needed to re-auth).
     *
     * @return  A non-null, non-blank summary string describing the result.
     */
    public static String validateRemediationPrerequisites() {

        List<String> issues = new List<String>();
        List<String> passed = new List<String>();

        // Check 1 — NamedCredential read access
        if (Schema.sObjectType.NamedCredential.isAccessible()) {
            passed.add('NamedCredential read access: OK');
        } else {
            issues.add('NamedCredential read access: MISSING '
                + '(assign "Manage Named Credentials" permission)');
        }

        // Check 2 — Customize Application permission
        if (hasNamedCredentialManagementPermission()) {
            passed.add('Customize Application permission: OK');
        } else {
            issues.add('Customize Application permission: MISSING '
                + '(assign via Permission Set or Profile)');
        }

        String summary;
        if (issues.isEmpty()) {
            summary = 'All pre-requisite checks PASSED. '
                + String.join(passed, '; ');
        } else {
            summary = 'Pre-requisite check(s) FAILED: '
                + String.join(issues, ' | ')
                + '. Passed: ' + String.join(passed, '; ');
        }

        System.debug(LoggingLevel.INFO,
            'NamedCredentialHealthCheck.validateRemediationPrerequisites — '
            + summary
        );

        return summary;
    }
}
