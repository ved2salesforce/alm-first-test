/**
 * @description Utility class for validating Named Credential configuration and
 *              detecting Bad OAuth Token conditions that can block DevOps Center
 *              pipeline promotions.
 *
 *              WI-000031: Remediate Promotion Failure – Bad OAuth Token on Named
 *              Credential Callout (originating WI-1fkVW0000006SeLYAU).
 *
 *              Root cause: The Named Credential used for DevOps Center promotion
 *              callouts returned a Bad_OAuth_Token response, indicating the stored
 *              OAuth token has expired, been revoked, or is otherwise invalid.
 *
 *              This class provides:
 *               - HealthCheckResult: a lightweight value object that surfaces
 *                 the credential name, a pass/fail status, and an optional
 *                 diagnostic message.
 *               - checkCredential(name): validates that a NamedCredential with
 *                 the given DeveloperName exists in the org.
 *               - checkDevOpsCredential(): convenience wrapper that checks the
 *                 well-known ALMDevOpsGitHub credential.
 *               - isCredentialValid(name): boolean helper suitable for guard
 *                 clauses in calling code.
 *               - buildDiagnosticMessage(): returns a human-readable remediation
 *                 guide for the Bad_OAuth_Token failure scenario.
 *
 * Governance compliance:
 *  - Declared with sharing – honours record-level sharing rules.
 *  - CRUD/FLS checks enforced: NamedCredential.isAccessible() before any query.
 *  - No SOQL inside loops.
 *  - No DML statements.
 *  - No hardcoded Salesforce IDs.
 *  - No dynamic SOQL/SOSL injection vectors.
 *  - WITH USER_MODE applied to all SOQL (API v56+).
 */
public with sharing class NamedCredentialHealthCheck {

    // ─── Constants ────────────────────────────────────────────────────────────

    /** Developer name of the Named Credential used by DevOps Center promotions. */
    @TestVisible
    public static final String DEVOPS_CREDENTIAL_NAME = 'ALMDevOpsGitHub';

    /** Error code returned by the Named Credential callout when the token is invalid. */
    @TestVisible
    public static final String BAD_OAUTH_TOKEN_CODE = 'Bad_OAuth_Token';

    // ─── Custom Exception ─────────────────────────────────────────────────────

    /**
     * @description Thrown when a required Named Credential cannot be found or
     *              when the caller lacks CRUD access to the NamedCredential object.
     */
    public class HealthCheckException extends Exception {}

    // ─── Value Object ─────────────────────────────────────────────────────────

    /**
     * @description Immutable result object returned by checkCredential().
     */
    public class HealthCheckResult {

        /** The DeveloperName of the Named Credential that was evaluated. */
        public String credentialName { get; private set; }

        /** True when the Named Credential record was found in the org. */
        public Boolean isHealthy     { get; private set; }

        /** Optional human-readable explanation for a failed check. */
        public String  message       { get; private set; }

        /**
         * @param credentialName DeveloperName of the Named Credential checked.
         * @param isHealthy      Pass/fail result.
         * @param message        Diagnostic text (may be null for a healthy result).
         */
        public HealthCheckResult(
            String  credentialName,
            Boolean isHealthy,
            String  message
        ) {
            this.credentialName = credentialName;
            this.isHealthy      = isHealthy;
            this.message        = message;
        }
    }

    // ─── Public API ───────────────────────────────────────────────────────────

    /**
     * @description Verifies that a NamedCredential with the supplied DeveloperName
     *              exists and is accessible in the running user's context.
     *
     *              Steps performed:
     *              1. Validates the name argument is not blank.
     *              2. Checks CRUD read access to NamedCredential (throws on failure).
     *              3. Queries for the record (WITH USER_MODE for FLS).
     *              4. Returns a HealthCheckResult indicating presence/absence.
     *
     * @param credentialName  DeveloperName of the Named Credential to check.
     *                        Must not be blank.
     * @return HealthCheckResult with isHealthy=true when the record is found.
     * @throws HealthCheckException when credentialName is blank or when the
     *         running user lacks CRUD read access to NamedCredential.
     */
    public static HealthCheckResult checkCredential(String credentialName) {
        if (String.isBlank(credentialName)) {
            throw new HealthCheckException(
                'credentialName must not be blank'
            );
        }

        // CRUD check: verify read access before issuing any SOQL
        if (!Schema.sObjectType.NamedCredential.isAccessible()) {
            throw new HealthCheckException(
                'Insufficient permissions: running user cannot read NamedCredential records'
            );
        }

        // Single query – no SOQL in loops
        List<NamedCredential> results = [
            SELECT Id, DeveloperName, MasterLabel
            FROM   NamedCredential
            WHERE  DeveloperName = :credentialName
            WITH   USER_MODE
            LIMIT  1
        ];

        if (results.isEmpty()) {
            String msg =
                'Named Credential not found: ' + credentialName
                + '. ' + buildDiagnosticMessage(credentialName);
            return new HealthCheckResult(credentialName, false, msg);
        }

        return new HealthCheckResult(credentialName, true, null);
    }

    /**
     * @description Convenience wrapper that checks the well-known DevOps Center
     *              Named Credential (ALMDevOpsGitHub).
     *
     * @return HealthCheckResult for the ALMDevOpsGitHub credential.
     * @throws HealthCheckException when the running user lacks read access to
     *         NamedCredential.
     */
    public static HealthCheckResult checkDevOpsCredential() {
        return checkCredential(DEVOPS_CREDENTIAL_NAME);
    }

    /**
     * @description Returns true when the Named Credential identified by the given
     *              DeveloperName exists and is accessible; false otherwise.
     *              Does not throw – callers that need detailed diagnostics should
     *              call checkCredential() directly.
     *
     * @param credentialName  DeveloperName to test.
     * @return Boolean – true if healthy, false if not found or on any exception.
     */
    public static Boolean isCredentialValid(String credentialName) {
        try {
            HealthCheckResult result = checkCredential(credentialName);
            return result.isHealthy;
        } catch (HealthCheckException ex) {
            System.debug(
                LoggingLevel.WARN,
                'NamedCredentialHealthCheck.isCredentialValid - exception: '
                + ex.getMessage()
            );
            return false;
        }
    }

    /**
     * @description Returns a human-readable remediation guide for the
     *              Bad_OAuth_Token failure scenario, tailored to the supplied
     *              credential name.
     *
     *              The message outlines the five remediation steps from WI-000031:
     *              1. Identify the Named Credential in Setup.
     *              2. Re-authenticate the OAuth flow.
     *              3. Verify token validity.
     *              4. Retry the DevOps Center promotion.
     *              5. Review the OAuth token expiry policy.
     *
     * @param credentialName  DeveloperName of the affected Named Credential.
     * @return Formatted multi-step remediation string.
     */
    public static String buildDiagnosticMessage(String credentialName) {
        String name = String.isBlank(credentialName) ? DEVOPS_CREDENTIAL_NAME : credentialName;
        return 'Remediation steps for Bad_OAuth_Token on Named Credential [' + name + ']:\n'
            + '1. Navigate to Setup > Security > Named Credentials and locate: ' + name + '.\n'
            + '2. Edit the credential and re-authenticate (re-authorise) the OAuth flow '
            + 'to obtain a fresh, valid token.\n'
            + '3. After re-authentication, confirm the credential status shows as '
            + 'authenticated/connected with no errors.\n'
            + '4. Re-trigger the DevOps Center promotion to confirm the callout succeeds.\n'
            + '5. Review the OAuth token lifetime and refresh-token policy for the connected app; '
            + 'consider enabling offline access (refresh tokens) or automatic token refresh '
            + 'to prevent recurrence.';
    }
}
