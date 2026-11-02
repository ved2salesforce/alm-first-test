/**
 * @description Unit tests for the Car__c custom object.
 *              Validates that the Car__c object supports basic CRUD operations
 *              and that FLS is respected when accessing the Name field.
 *
 * Acceptance Criteria Covered:
 *   - Car__c custom object is present and active in the org.
 *   - Records can be created, read, updated, and deleted.
 *   - CRUD/FLS checks pass for standard operations.
 *
 * @see Car__c
 */
@IsTest
private class CarObjectTest {

    // ──────────────────────────────────────────────────────────────────────────
    // CRUD Tests
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Verifies that a Car__c record can be created (insert) and read (query).
     */
    @IsTest
    static void testCreateAndReadCar() {
        Car__c car = new Car__c(Name = 'Test Car 1');

        Test.startTest();
        insert car;
        Test.stopTest();

        Car__c result = [SELECT Id, Name FROM Car__c WHERE Id = :car.Id LIMIT 1];
        System.assertNotEquals(null, result, 'Car record should have been inserted.');
        System.assertEquals('Test Car 1', result.Name, 'Car Name should match the inserted value.');
    }

    /**
     * Verifies that an existing Car__c record can be updated.
     */
    @IsTest
    static void testUpdateCar() {
        Car__c car = new Car__c(Name = 'Original Car Name');
        insert car;

        car.Name = 'Updated Car Name';

        Test.startTest();
        update car;
        Test.stopTest();

        Car__c result = [SELECT Id, Name FROM Car__c WHERE Id = :car.Id LIMIT 1];
        System.assertEquals('Updated Car Name', result.Name, 'Car Name should reflect the updated value.');
    }

    /**
     * Verifies that a Car__c record can be deleted.
     */
    @IsTest
    static void testDeleteCar() {
        Car__c car = new Car__c(Name = 'Car To Delete');
        insert car;

        Test.startTest();
        delete car;
        Test.stopTest();

        List<Car__c> results = [SELECT Id FROM Car__c WHERE Id = :car.Id];
        System.assertEquals(0, results.size(), 'Car record should have been deleted.');
    }

    /**
     * Verifies that bulk inserts of Car__c records succeed without hitting
     * governor limits (200 records to validate bulkification).
     */
    @IsTest
    static void testBulkCreateCars() {
        List<Car__c> cars = new List<Car__c>();
        for (Integer i = 0; i < 200; i++) {
            cars.add(new Car__c(Name = 'Bulk Car ' + i));
        }

        Test.startTest();
        insert cars;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Car__c WHERE Name LIKE 'Bulk Car %'];
        System.assertEquals(200, count, 'All 200 Car records should have been inserted.');
    }

    /**
     * Verifies that the Car__c object is accessible to the running user
     * (CRUD check: object-level access for create and read).
     */
    @IsTest
    static void testCarObjectCrudAccess() {
        Schema.DescribeSObjectResult objDescribe = Car__c.SObjectType.getDescribe();
        System.assertEquals(true, objDescribe.isCreateable(),
            'Running user should have Create access on Car__c.');
        System.assertEquals(true, objDescribe.isAccessible(),
            'Running user should have Read access on Car__c.');
        System.assertEquals(true, objDescribe.isUpdateable(),
            'Running user should have Update access on Car__c.');
        System.assertEquals(true, objDescribe.isDeletable(),
            'Running user should have Delete access on Car__c.');
    }

    /**
     * Verifies FLS on the Car__c Name field — it should be accessible and
     * createable for the running user.
     */
    @IsTest
    static void testCarNameFieldFls() {
        Schema.DescribeFieldResult fieldDescribe =
            Car__c.Name.getDescribe();
        System.assertEquals(true, fieldDescribe.isAccessible(),
            'Name field should be readable.');
        System.assertEquals(true, fieldDescribe.isCreateable(),
            'Name field should be createable.');
        System.assertEquals(true, fieldDescribe.isUpdateable(),
            'Name field should be updateable.');
    }

    /**
     * Verifies that querying Car__c records works correctly with a filter.
     */
    @IsTest
    static void testQueryCarByName() {
        Car__c car1 = new Car__c(Name = 'Toyota Corolla');
        Car__c car2 = new Car__c(Name = 'Honda Civic');
        insert new List<Car__c>{ car1, car2 };

        Test.startTest();
        List<Car__c> results = [SELECT Id, Name FROM Car__c WHERE Name = 'Toyota Corolla'];
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find exactly one Car with the given name.');
        System.assertEquals('Toyota Corolla', results[0].Name, 'Name should match the queried value.');
    }
}
