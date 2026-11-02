/**
 * @description Test class for {@link NamedCredentialHealthCheck}.
 *
 *              WI-000030: Remediate Bad OAuth Token Causing Promotion Failure
 *
 *              Coverage targets (>= 75 %):
 *              - getCredentialStatuses() — happy path and no-access path
 *              - logHealthReport()       — happy path and no-access path
 *              - hasNamedCredentialManagementPermission() — admin user path
 *              - validateRemediationPrerequisites()      — admin and restricted paths
 *
 * @author  Builder Agent
 * @since   2026-11-02
 */
@IsTest
private class NamedCredentialHealthCheckTest {

    // ──────────────────────────────────────────────────────────────────────────
    // Test data helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Creates a restricted (Minimum Access) test user with no special
     * permissions.  Used to simulate missing CRUD / system-permission
     * scenarios.
     */
    private static User createRestrictedUser() {
        Profile minAccess = [
            SELECT Id FROM Profile
            WHERE  Name = 'Minimum Access - Salesforce'
            LIMIT  1
        ];

        String unique = String.valueOf(System.currentTimeMillis());
        return new User(
            Alias             = 'rstd' + unique.right(4),
            Email             = 'nc.test.' + unique + '@example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'NCTestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = minAccess.Id,
            TimeZoneSidKey    = 'America/Los_Angeles',
            UserName          = 'nc.test.' + unique + '@example.com'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CredentialStatus DTO tests
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that a default-constructed CredentialStatus has
     * isConfigured = false and all other fields null.
     */
    @IsTest
    static void testCredentialStatus_defaultValues() {
        NamedCredentialHealthCheck.CredentialStatus cs =
            new NamedCredentialHealthCheck.CredentialStatus();

        System.assertEquals(false,  cs.isConfigured,   'Default isConfigured should be false.');
        System.assertEquals(null,   cs.developerName,  'Default developerName should be null.');
        System.assertEquals(null,   cs.masterLabel,    'Default masterLabel should be null.');
        System.assertEquals(null,   cs.endpoint,       'Default endpoint should be null.');
        System.assertEquals(null,   cs.authProvider,   'Default authProvider should be null.');
    }

    /**
     * Verifies that CredentialStatus fields can be set and read back.
     */
    @IsTest
    static void testCredentialStatus_fieldAssignment() {
        NamedCredentialHealthCheck.CredentialStatus cs =
            new NamedCredentialHealthCheck.CredentialStatus();
        cs.developerName = 'MyNCDev';
        cs.masterLabel   = 'My NC Label';
        cs.endpoint      = 'https://example.com';
        cs.authProvider  = 'NamedUser';
        cs.isConfigured  = true;

        System.assertEquals('MyNCDev',             cs.developerName, 'developerName mismatch.');
        System.assertEquals('My NC Label',         cs.masterLabel,   'masterLabel mismatch.');
        System.assertEquals('https://example.com', cs.endpoint,      'endpoint mismatch.');
        System.assertEquals('NamedUser',           cs.authProvider,  'authProvider mismatch.');
        System.assertEquals(true,                  cs.isConfigured,  'isConfigured mismatch.');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getCredentialStatuses() — happy path (admin / system context)
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that getCredentialStatuses() returns a non-null list when
     * the running user has NamedCredential access (admin context).
     * The list may be empty in a scratch/sandbox with no Named Credentials.
     */
    @IsTest
    static void testGetCredentialStatuses_adminContext() {
        Test.startTest();
        List<NamedCredentialHealthCheck.CredentialStatus> statuses =
            NamedCredentialHealthCheck.getCredentialStatuses();
        Test.stopTest();

        System.assertNotEquals(null, statuses,
            'getCredentialStatuses() must never return null.');
        // Each returned item must have isConfigured = true
        for (NamedCredentialHealthCheck.CredentialStatus cs : statuses) {
            System.assertEquals(true, cs.isConfigured,
                'Every returned CredentialStatus must have isConfigured = true.');
            System.assertNotEquals(null, cs.developerName,
                'developerName must not be null for a returned credential.');
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getCredentialStatuses() — no-access path
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that getCredentialStatuses() throws HealthCheckException when
     * the running user does not have NamedCredential CRUD read access.
     *
     * Uses a Minimum Access profile user to simulate missing permissions.
     */
    @IsTest
    static void testGetCredentialStatuses_noAccess() {
        User restricted = createRestrictedUser();
        insert restricted;

        Test.startTest();
        Boolean exceptionThrown = false;
        System.runAs(restricted) {
            try {
                NamedCredentialHealthCheck.getCredentialStatuses();
            } catch (NamedCredentialHealthCheck.HealthCheckException ex) {
                exceptionThrown = true;
                System.assert(
                    ex.getMessage().contains('Insufficient privileges'),
                    'Exception message should mention insufficient privileges.'
                );
            }
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown,
            'HealthCheckException must be thrown when user has no NamedCredential access.');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // logHealthReport() — happy path
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that logHealthReport() returns a non-negative integer and does
     * not throw in an admin context.
     */
    @IsTest
    static void testLogHealthReport_adminContext() {
        Test.startTest();
        Integer count = NamedCredentialHealthCheck.logHealthReport();
        Test.stopTest();

        System.assert(count >= 0,
            'logHealthReport() must return a non-negative count.');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // logHealthReport() — no-access path
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that logHealthReport() returns 0 and does not throw when the
     * running user cannot access NamedCredential records.
     */
    @IsTest
    static void testLogHealthReport_noAccess() {
        User restricted = createRestrictedUser();
        insert restricted;

        Test.startTest();
        Integer count = 999; // sentinel value
        System.runAs(restricted) {
            count = NamedCredentialHealthCheck.logHealthReport();
        }
        Test.stopTest();

        System.assertEquals(0, count,
            'logHealthReport() must return 0 when the user has no NamedCredential access.');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // hasNamedCredentialManagementPermission()
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that hasNamedCredentialManagementPermission() returns a boolean
     * and does not throw.
     */
    @IsTest
    static void testHasNamedCredentialManagementPermission_adminContext() {
        Test.startTest();
        Boolean result =
            NamedCredentialHealthCheck.hasNamedCredentialManagementPermission();
        Test.stopTest();

        System.assertNotEquals(null, result,
            'hasNamedCredentialManagementPermission() must not return null.');
    }

    /**
     * Verifies that a Minimum Access user does not have the Customize
     * Application permission.
     */
    @IsTest
    static void testHasNamedCredentialManagementPermission_restrictedUser() {
        User restricted = createRestrictedUser();
        insert restricted;

        Test.startTest();
        Boolean result = true; // sentinel
        System.runAs(restricted) {
            result =
                NamedCredentialHealthCheck.hasNamedCredentialManagementPermission();
        }
        Test.stopTest();

        System.assertEquals(false, result,
            'Minimum Access user must not have Customize Application permission.');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // validateRemediationPrerequisites()
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that validateRemediationPrerequisites() returns a non-blank
     * string in an admin context (all checks should pass).
     */
    @IsTest
    static void testValidateRemediationPrerequisites_adminContext() {
        Test.startTest();
        String result =
            NamedCredentialHealthCheck.validateRemediationPrerequisites();
        Test.stopTest();

        System.assertNotEquals(null,  result,
            'validateRemediationPrerequisites() must not return null.');
        System.assert(String.isNotBlank(result),
            'validateRemediationPrerequisites() must not return a blank string.');
        System.assert(result.contains('PASSED'),
            'Admin context should yield a PASSED result; got: ' + result);
    }

    /**
     * Verifies that validateRemediationPrerequisites() returns a FAILED
     * summary string when the running user lacks required permissions.
     */
    @IsTest
    static void testValidateRemediationPrerequisites_restrictedUser() {
        User restricted = createRestrictedUser();
        insert restricted;

        Test.startTest();
        String result = '';
        System.runAs(restricted) {
            result =
                NamedCredentialHealthCheck.validateRemediationPrerequisites();
        }
        Test.stopTest();

        System.assertNotEquals(null, result,
            'validateRemediationPrerequisites() must not return null for restricted user.');
        System.assert(String.isNotBlank(result),
            'validateRemediationPrerequisites() must not return blank for restricted user.');
        System.assert(result.contains('FAILED') || result.contains('MISSING'),
            'Restricted user should get a FAILED/MISSING result; got: ' + result);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // HealthCheckException test
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that HealthCheckException can be instantiated and thrown with
     * a message.
     */
    @IsTest
    static void testHealthCheckException_throwAndCatch() {
        Test.startTest();
        Boolean caught = false;
        try {
            throw new NamedCredentialHealthCheck.HealthCheckException(
                'test error message'
            );
        } catch (NamedCredentialHealthCheck.HealthCheckException ex) {
            caught = true;
            System.assertEquals('test error message', ex.getMessage(),
                'Exception message should match what was thrown.');
        }
        Test.stopTest();

        System.assertEquals(true, caught,
            'HealthCheckException must be caught by its specific type.');
    }
}
