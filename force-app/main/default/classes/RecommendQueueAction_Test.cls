@IsTest
private class RecommendQueueAction_Test {
    private static RecommendQueueAction.Request requestFor(String category, String urgency) {
        RecommendQueueAction.Request request = new RecommendQueueAction.Request();
        request.category = category;
        request.urgency = urgency;
        return request;
    }

    @IsTest
    static void mapsCategoriesToDeployedQueues() {
        System.runAs(TriageTestSupport.createTriageUser()) {
            Integer queriesBefore = Limits.getQueries();
            List<RecommendQueueAction.Result> results = RecommendQueueAction.recommend(
                new List<RecommendQueueAction.Request>{
                    requestFor('Fraud', 'Critical'),
                    requestFor('Card Dispute', 'Medium'),
                    requestFor('Patient Billing', 'Low'),
                    requestFor('Appointments', 'Critical'),
                    requestFor('Something Else', 'Low')
                }
            );
            Assert.areEqual('Fraud_Response', results[0].queueDeveloperName, 'Critical fraud stays with fraud team');
            Assert.areEqual('Card_Disputes', results[1].queueDeveloperName, 'Disputes');
            Assert.areEqual('Patient_Billing', results[2].queueDeveloperName, 'Healthcare billing');
            Assert.areEqual('Priority_Escalations', results[3].queueDeveloperName, 'Critical non-fraud escalates');
            Assert.areEqual('General_Support', results[4].queueDeveloperName, 'Unknown category falls back');
            for (RecommendQueueAction.Result result : results) {
                Assert.isTrue(result.isSuccess, 'Queue found');
                Assert.isNotNull(result.queueId, 'Queue id returned');
                Assert.isFalse(result.fallbackUsed, 'Preferred queue available');
                Assert.isTrue(String.isNotBlank(result.reason), 'Reason given');
            }
            Assert.areEqual(1, Limits.getQueries() - queriesBefore, 'Single queue query for the batch');
        }
    }

    @IsTest
    static void targetQueueLogic() {
        Assert.areEqual('Lending_Services', RecommendQueueAction.targetQueue('Loan Servicing', 'High'), 'Loans');
        Assert.areEqual('Digital_Banking_Support', RecommendQueueAction.targetQueue('Account Access', null), 'Access');
        Assert.areEqual('General_Support', RecommendQueueAction.targetQueue(null, null), 'Null category');
        Assert.areEqual('Priority_Escalations', RecommendQueueAction.targetQueue(null, 'Critical'), 'Critical');
    }
}
