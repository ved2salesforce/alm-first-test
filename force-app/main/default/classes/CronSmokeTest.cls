/**
 * CronSmokeTest
 *
 * Lightweight Apex class created by WI-000049 (scheduled orchestration smoke test).
 * Provides a simple utility method to verify that the Salesforce environment is
 * operational and that basic DML/query operations can execute without error.
 */
public with sharing class CronSmokeTest {
    /**
     * Returns a greeting string to verify Apex execution is working.
     *
     * @param name The name to greet.
     * @return A greeting string.
     */
    public static String greet(String name) {
        if (String.isBlank(name)) {
            return 'Hello, World!';
        }
        return 'Hello, ' + name + '!';
    }

    /**
     * Returns the current timestamp as an ISO-8601 string.
     * Used to verify that the Salesforce environment can return system time.
     *
     * @return The current UTC datetime as a string.
     */
    public static String currentTimestamp() {
        return String.valueOf(Datetime.now());
    }
}
