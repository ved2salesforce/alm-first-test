/**
 * CronSmokeTestTest
 *
 * Unit tests for CronSmokeTest. Verifies that the smoke-test utility methods
 * behave correctly under normal and edge-case inputs.
 *
 * Coverage target: >= 75 %
 */
@IsTest
private class CronSmokeTestTest {
    @IsTest
    static void testGreetWithName() {
        String result = CronSmokeTest.greet('Alice');
        System.assertEquals('Hello, Alice!', result, 'Expected personalised greeting');
    }

    @IsTest
    static void testGreetWithNullName() {
        String result = CronSmokeTest.greet(null);
        System.assertEquals('Hello, World!', result, 'Expected default greeting for null');
    }

    @IsTest
    static void testGreetWithBlankName() {
        String result = CronSmokeTest.greet('   ');
        System.assertEquals('Hello, World!', result, 'Expected default greeting for blank string');
    }

    @IsTest
    static void testCurrentTimestamp() {
        String ts = CronSmokeTest.currentTimestamp();
        System.assertNotEquals(null, ts, 'Timestamp must not be null');
        System.assert(ts.length() > 0, 'Timestamp must not be empty');
    }
}
