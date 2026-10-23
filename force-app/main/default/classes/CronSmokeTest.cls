/**
 * @description Schedulable Apex class implementing a cron smoke test.
 *              Verifies that the Salesforce scheduler infrastructure is operational
 *              by executing a lightweight, side-effect-free health check when invoked
 *              as a scheduled job.
 *
 *              WI-000008: Cron smoke test 1812
 *
 * Governance compliance:
 *  - No SOQL inside loops
 *  - No DML inside loops
 *  - CRUD/FLS checks enforced via WITH USER_MODE (API v56+)
 *  - No hardcoded Salesforce IDs
 *  - No dynamic SOQL/SOSL injection vectors
 */
public with sharing class CronSmokeTest implements Schedulable {

    // ─── Custom Exception ────────────────────────────────────────────────────
    public class SmokeTestException extends Exception {}

    // ─── Constants ───────────────────────────────────────────────────────────
    @TestVisible
    private static final String JOB_NAME = 'CronSmokeTest';

    // ─── Schedulable Interface ───────────────────────────────────────────────

    /**
     * @description Entry point called by the Salesforce scheduler.
     *              Performs a lightweight smoke-test assertion to confirm
     *              the scheduled execution context is healthy.
     *
     * @param ctx  The SchedulableContext provided by the platform
     */
    public void execute(SchedulableContext ctx) {
        runSmokeTest(ctx);
    }

    // ─── Core Logic ──────────────────────────────────────────────────────────

    /**
     * @description Runs the smoke test logic.
     *              Reads a minimal set of CronTrigger data (the job itself) to verify
     *              SOQL access and logs the outcome.
     *              Throws SmokeTestException if the job record cannot be located.
     *
     * @param ctx  The SchedulableContext for the current run
     */
    @TestVisible
    private void runSmokeTest(SchedulableContext ctx) {
        if (ctx == null) {
            throw new SmokeTestException('SchedulableContext must not be null');
        }

        Id jobId = ctx.getTriggerId();

        // Object-level read check before querying CronTrigger
        if (!Schema.sObjectType.CronTrigger.isAccessible()) {
            throw new SmokeTestException(
                'Insufficient permissions to read CronTrigger records'
            );
        }

        // Single bulkified query - no SOQL in loop
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetailId, State, NextFireTime
            FROM   CronTrigger
            WHERE  Id = :jobId
            WITH   USER_MODE
            LIMIT  1
        ];

        if (jobs.isEmpty()) {
            throw new SmokeTestException(
                'CronSmokeTest: scheduled job record not found for Id: ' + jobId
            );
        }

        CronTrigger job = jobs[0];
        System.debug(LoggingLevel.INFO,
            'CronSmokeTest passed - jobId=' + job.Id
            + ' state=' + job.State
            + ' nextFireTime=' + job.NextFireTime
        );
    }

    // ─── Schedule Helpers ────────────────────────────────────────────────────

    /**
     * @description Schedules a one-time run of CronSmokeTest using the supplied cron expression.
     *              Aborts any existing job with the same name before scheduling.
     *
     * @param cronExpression  A valid Salesforce cron expression (e.g. '0 12 18 * * ?')
     * @return The Id of the newly created CronTrigger
     */
    public static Id scheduleJob(String cronExpression) {
        if (String.isBlank(cronExpression)) {
            throw new SmokeTestException('cronExpression must not be blank');
        }

        // Abort any pre-existing job with the same name to avoid duplicates
        abortExistingJob(JOB_NAME);

        return System.schedule(JOB_NAME, cronExpression, new CronSmokeTest());
    }

    /**
     * @description Aborts any currently scheduled job that matches the given job name.
     *
     * @param jobName  The name of the scheduled job to abort
     */
    @TestVisible
    private static void abortExistingJob(String jobName) {
        if (String.isBlank(jobName)) {
            return;
        }

        // Object-level read check
        if (!Schema.sObjectType.CronTrigger.isAccessible()) {
            return; // Cannot query; skip abort silently
        }

        List<CronTrigger> existing = [
            SELECT Id
            FROM   CronTrigger
            WHERE  CronJobDetail.Name = :jobName
            AND    State NOT IN ('DELETED', 'COMPLETE')
            WITH   USER_MODE
            LIMIT  200
        ];

        for (CronTrigger ct : existing) {
            System.abortJob(ct.Id);
        }
    }
}
