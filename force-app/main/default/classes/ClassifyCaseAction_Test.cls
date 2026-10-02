@IsTest
private class ClassifyCaseAction_Test {
    private static ClassifyCaseAction.Request requestFor(Id caseId, String subject, String description) {
        ClassifyCaseAction.Request request = new ClassifyCaseAction.Request();
        request.caseId = caseId;
        request.subject = subject;
        request.description = description;
        return request;
    }

    @IsTest
    static void classifiesStoredCasesInBulk() {
        TriageTestSupport.useSyntheticRules();
        System.runAs(TriageTestSupport.createTriageUser()) {
            List<Case> cases = new List<Case>();
            for (Integer i = 0; i < 200; i++) {
                cases.add(new Case(Subject = 'Synthetic dispute ' + i, Description = 'Please process a refund'));
            }
            insert cases;
            List<ClassifyCaseAction.Request> requests = new List<ClassifyCaseAction.Request>();
            for (Case record : cases) {
                requests.add(requestFor(record.Id, null, null));
            }

            Test.startTest();
            List<ClassifyCaseAction.Result> results = ClassifyCaseAction.classify(requests);
            Integer queriesUsed = Limits.getQueries();
            Test.stopTest();

            Assert.areEqual(200, results.size(), 'One result per request');
            Assert.areEqual(1, queriesUsed, 'Bulk-safe: a single query');
            for (ClassifyCaseAction.Result result : results) {
                Assert.isTrue(result.isSuccess, 'Success');
                Assert.areEqual('Card Dispute', result.category, 'Category');
                Assert.areEqual('Low', result.urgency, 'Urgency');
                Assert.areEqual(new List<String>{ 'dispute', 'refund' }, result.matchedKeywords, 'Keywords');
            }
        }
    }

    @IsTest
    static void explicitTextOverridesStoredText() {
        TriageTestSupport.useSyntheticRules();
        System.runAs(TriageTestSupport.createTriageUser()) {
            Case record = new Case(Subject = 'Synthetic dispute', Description = 'refund');
            insert record;
            ClassifyCaseAction.Result result = ClassifyCaseAction.classify(
                new List<ClassifyCaseAction.Request>{ requestFor(record.Id, 'Need an appointment', null) }
            )[0];
            Assert.areEqual('Appointments', result.category, 'Supplied subject wins');
        }
    }

    @IsTest
    static void classifiesFreeTextWithoutCase() {
        TriageTestSupport.useSyntheticRules();
        ClassifyCaseAction.Result result = ClassifyCaseAction.classify(
            new List<ClassifyCaseAction.Request>{ requestFor(null, 'Locked out', 'urgent') }
        )[0];
        Assert.areEqual('Account Access', result.category, 'Category');
        Assert.areEqual('High', result.urgency, 'Urgency 4');
        Assert.areEqual(0, Limits.getQueries(), 'No query without caseId');
    }

    @IsTest
    static void returnsErrorsInsteadOfThrowing() {
        TriageTestSupport.useSyntheticRules();
        Case record = new Case(Subject = 'Synthetic');
        insert record;
        Id deletedId = record.Id;
        delete record;

        List<ClassifyCaseAction.Result> results = ClassifyCaseAction.classify(
            new List<ClassifyCaseAction.Request>{ requestFor(deletedId, null, null), requestFor(null, ' ', null) }
        );
        Assert.isFalse(results[0].isSuccess, 'Missing case');
        Assert.isTrue(results[0].errorMessage.contains('not found'), results[0].errorMessage);
        Assert.isTrue(results[0].requiresHumanReview, 'Failures route to a human');
        Assert.isFalse(results[1].isSuccess, 'No input text');
    }
}
