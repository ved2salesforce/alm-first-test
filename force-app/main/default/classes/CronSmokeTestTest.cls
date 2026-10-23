/**
 * @description Unit tests for CronSmokeTest.
 *              Covers the Schedulable execute path, scheduleJob helper,
 *              abortExistingJob helper, and all exception / edge-case paths.
 *              Target: >= 75% code coverage.
 *
 *              WI-000008: Cron smoke test 1812
 */
@IsTest
private class CronSmokeTestTest {

    // ─── Test Data / Constants ─────────────────────────────────────────────────

    /** A far-future cron expression so no job actually fires during tests. */
    private static final String TEST_CRON = '0 0 0 1 1 ? 2099';

    // ─── execute() via System.schedule ────────────────────────────────────────

    /**
     * Positive test: schedule CronSmokeTest via the platform scheduler.
     * Test.stopTest() forces the execute() method to run synchronously in test context.
     * Verifies no exception is thrown during the scheduled run.
     */
    @IsTest
    static void testExecuteViaSchedule() {
        Test.startTest();
        String jobId = System.schedule(
            'CronSmokeTestTest_execute',
            TEST_CRON,
            new CronSmokeTest()
        );
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Job ID should not be null after scheduling');
    }

    // ─── scheduleJob() ────────────────────────────────────────────────────────

    /**
     * Positive test: scheduleJob returns a non-null job ID for a valid cron expression.
     */
    @IsTest
    static void testScheduleJobSuccess() {
        Test.startTest();
        Id scheduledId = CronSmokeTest.scheduleJob(TEST_CRON);
        Test.stopTest();

        System.assertNotEquals(null, scheduledId,
            'scheduleJob should return a valid CronTrigger ID');
    }

    /**
     * Idempotency test: scheduling the same job name twice is safe.
     * The second call aborts the existing job then re-schedules cleanly.
     * We keep both calls outside a single startTest/stopTest pair to avoid
     * the platform constraint on scheduling the same class twice in one context.
     */
    @IsTest
    static void testScheduleJobIdempotent() {
        // First schedule
        Id firstId = CronSmokeTest.scheduleJob(TEST_CRON);
        System.assertNotEquals(null, firstId, 'First schedule should succeed');

        // Second schedule (aborts first, then re-schedules)
        Id secondId = CronSmokeTest.scheduleJob(TEST_CRON);
        System.assertNotEquals(null, secondId, 'Second schedule should succeed');
    }

    /**
     * Negative test: scheduleJob with a blank cron expression throws SmokeTestException.
     */
    @IsTest
    static void testScheduleJobBlankCronThrows() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            CronSmokeTest.scheduleJob('');
            Test.stopTest();
        } catch (CronSmokeTest.SmokeTestException ex) {
            exceptionThrown = true;
            System.assertEquals(
                'cronExpression must not be blank',
                ex.getMessage(),
                'Exception message should indicate blank cron expression'
            );
        }
        System.assert(exceptionThrown,
            'SmokeTestException should be thrown for a blank cron expression');
    }

    /**
     * Negative test: scheduleJob with a null cron expression throws SmokeTestException.
     */
    @IsTest
    static void testScheduleJobNullCronThrows() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            CronSmokeTest.scheduleJob(null);
            Test.stopTest();
        } catch (CronSmokeTest.SmokeTestException ex) {
            exceptionThrown = true;
            System.assertEquals(
                'cronExpression must not be blank',
                ex.getMessage(),
                'Exception message should indicate blank cron expression'
            );
        }
        System.assert(exceptionThrown,
            'SmokeTestException should be thrown for a null cron expression');
    }

    // ─── runSmokeTest() null-context guard ────────────────────────────────────

    /**
     * Negative test: runSmokeTest with a null SchedulableContext throws SmokeTestException.
     * Exercises the null-check guard at the top of runSmokeTest via @TestVisible access.
     */
    @IsTest
    static void testRunSmokeTestNullContextThrows() {
        CronSmokeTest instance = new CronSmokeTest();
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            instance.runSmokeTest(null);
            Test.stopTest();
        } catch (CronSmokeTest.SmokeTestException ex) {
            exceptionThrown = true;
            System.assertEquals(
                'SchedulableContext must not be null',
                ex.getMessage(),
                'Exception message should indicate null context'
            );
        }
        System.assert(exceptionThrown,
            'SmokeTestException should be thrown when SchedulableContext is null');
    }

    // ─── abortExistingJob() edge cases ────────────────────────────────────────

    /**
     * Edge case: abortExistingJob with a blank name performs no action and does not throw.
     */
    @IsTest
    static void testAbortExistingJobBlankName() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            CronSmokeTest.abortExistingJob('');
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        System.assert(!exceptionThrown,
            'abortExistingJob with blank name should not throw');
    }

    /**
     * Edge case: abortExistingJob with null name performs no action and does not throw.
     */
    @IsTest
    static void testAbortExistingJobNullName() {
        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            CronSmokeTest.abortExistingJob(null);
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        System.assert(!exceptionThrown,
            'abortExistingJob with null name should not throw');
    }

    /**
     * Positive test: abortExistingJob cleanly aborts a pre-scheduled job.
     * Schedule the job first, then call abortExistingJob to exercise the abort path.
     */
    @IsTest
    static void testAbortExistingJobWithExistingJob() {
        // Schedule the job outside startTest so it exists in the query scope
        System.schedule('CronSmokeTest', TEST_CRON, new CronSmokeTest());

        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            CronSmokeTest.abortExistingJob('CronSmokeTest');
            Test.stopTest();
        } catch (Exception ex) {
            exceptionThrown = true;
        }
        System.assert(!exceptionThrown,
            'abortExistingJob should not throw when a matching job exists');
    }

    // ─── SmokeTestException ───────────────────────────────────────────────────

    /**
     * Verifies that SmokeTestException is a proper Exception subclass and
     * its message is preserved.
     */
    @IsTest
    static void testSmokeTestExceptionMessage() {
        Boolean exceptionThrown = false;
        String msg = 'test exception message';
        try {
            throw new CronSmokeTest.SmokeTestException(msg);
        } catch (CronSmokeTest.SmokeTestException ex) {
            exceptionThrown = true;
            System.assertEquals(msg, ex.getMessage(),
                'SmokeTestException should preserve the message');
        }
        System.assert(exceptionThrown, 'SmokeTestException should be throwable');
    }

    // ─── JOB_NAME constant ────────────────────────────────────────────────────

    /**
     * Verifies that the @TestVisible JOB_NAME constant is accessible and correct.
     */
    @IsTest
    static void testJobNameConstant() {
        System.assertNotEquals(null, CronSmokeTest.JOB_NAME,
            'JOB_NAME should not be null');
        System.assertNotEquals('', CronSmokeTest.JOB_NAME,
            'JOB_NAME should not be empty');
        System.assertEquals('CronSmokeTest', CronSmokeTest.JOB_NAME,
            'JOB_NAME should equal CronSmokeTest');
    }
}
