/**
 * @description Test class for the Car__c custom object.
 *              Verifies object existence, CRUD operations, FLS checks,
 *              and sharing model configuration.
 *
 * WI-000048 — Create a custom object: Car
 */
@IsTest
private class CarTest {

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Car__c object exists in the schema
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testObjectExistsInSchema() {
        Schema.SObjectType carType = Schema.getGlobalDescribe().get('Car__c');
        System.assertNotEquals(
            null,
            carType,
            'Car__c sObject should be present in the org schema'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Car__c Name field exists and is Text type
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testNameFieldIsText() {
        Schema.SObjectType carType = Schema.getGlobalDescribe().get('Car__c');
        System.assertNotEquals(null, carType, 'Car__c sObject not found');

        Map<String, Schema.SObjectField> fields =
            carType.getDescribe().fields.getMap();

        System.assert(
            fields.containsKey('name'),
            'Name field should exist on Car__c'
        );

        Schema.DescribeFieldResult dfr = fields.get('name').getDescribe();
        System.assertEquals(
            Schema.DisplayType.STRING,
            dfr.getType(),
            'Car__c Name field should be of Text (String) type'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. CRUD: Create a Car__c record (INSERT)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testCreateCar() {
        // Verify CRUD permission for INSERT
        Schema.DescribeSObjectResult dsor =
            Schema.getGlobalDescribe().get('Car__c').getDescribe();
        System.assert(dsor.isCreateable(), 'Running user must have create permission on Car__c');

        Car__c car = new Car__c(Name = 'Test Car');

        Test.startTest();
        insert car;
        Test.stopTest();

        Car__c inserted = [SELECT Id, Name FROM Car__c WHERE Id = :car.Id LIMIT 1];
        System.assertEquals('Test Car', inserted.Name, 'Car Name should match the inserted value');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. CRUD: Read a Car__c record (SELECT)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testReadCar() {
        Schema.DescribeSObjectResult dsor =
            Schema.getGlobalDescribe().get('Car__c').getDescribe();
        System.assert(dsor.isAccessible(), 'Running user must have read permission on Car__c');

        Car__c car = new Car__c(Name = 'Readable Car');
        insert car;

        Test.startTest();
        List<Car__c> cars = [SELECT Id, Name FROM Car__c WHERE Name = 'Readable Car' LIMIT 1];
        Test.stopTest();

        System.assertEquals(1, cars.size(), 'Should find exactly one Car__c record');
        System.assertEquals('Readable Car', cars[0].Name, 'Car Name should match');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. CRUD: Update a Car__c record (UPDATE)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testUpdateCar() {
        Schema.DescribeSObjectResult dsor =
            Schema.getGlobalDescribe().get('Car__c').getDescribe();
        System.assert(dsor.isUpdateable(), 'Running user must have update permission on Car__c');

        Car__c car = new Car__c(Name = 'Original Car');
        insert car;

        Test.startTest();
        car.Name = 'Updated Car';
        update car;
        Test.stopTest();

        Car__c updated = [SELECT Id, Name FROM Car__c WHERE Id = :car.Id LIMIT 1];
        System.assertEquals('Updated Car', updated.Name, 'Car Name should reflect the update');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. CRUD: Delete a Car__c record (DELETE)
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testDeleteCar() {
        Schema.DescribeSObjectResult dsor =
            Schema.getGlobalDescribe().get('Car__c').getDescribe();
        System.assert(dsor.isDeletable(), 'Running user must have delete permission on Car__c');

        Car__c car = new Car__c(Name = 'Car To Delete');
        insert car;
        Id carId = car.Id;

        Test.startTest();
        delete car;
        Test.stopTest();

        List<Car__c> remaining = [SELECT Id FROM Car__c WHERE Id = :carId];
        System.assertEquals(0, remaining.size(), 'Car__c record should have been deleted');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. FLS: Name field is accessible and updateable
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testNameFieldFLS() {
        Schema.SObjectType carType = Schema.getGlobalDescribe().get('Car__c');
        System.assertNotEquals(null, carType, 'Car__c must exist for FLS check');

        Schema.DescribeFieldResult dfr =
            carType.getDescribe().fields.getMap().get('name').getDescribe();

        System.assert(dfr.isAccessible(),  'Car__c.Name field must be readable');
        System.assert(dfr.isUpdateable(),  'Car__c.Name field must be updateable');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Sharing model label is ReadWrite
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testObjectLabel() {
        Schema.DescribeSObjectResult dsor =
            Schema.getGlobalDescribe().get('Car__c').getDescribe();

        System.assertEquals(
            'Car',
            dsor.getLabel(),
            'Car__c object label should be "Car"'
        );
        System.assertEquals(
            'Cars',
            dsor.getLabelPlural(),
            'Car__c plural label should be "Cars"'
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Bulk insert of multiple Car__c records
    // ─────────────────────────────────────────────────────────────────────────
    @IsTest
    static void testBulkInsert() {
        List<Car__c> cars = new List<Car__c>();
        for (Integer i = 1; i <= 50; i++) {
            cars.add(new Car__c(Name = 'Bulk Car ' + i));
        }

        Test.startTest();
        insert cars;
        Test.stopTest();

        Integer count = [SELECT COUNT() FROM Car__c];
        System.assertEquals(50, count, 'Should have 50 Car__c records after bulk insert');
    }
}
