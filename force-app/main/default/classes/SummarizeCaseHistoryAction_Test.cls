@IsTest
private class SummarizeCaseHistoryAction_Test {
    private static SummarizeCaseHistoryAction.Request requestFor(Id caseId, Integer maxComments) {
        SummarizeCaseHistoryAction.Request request = new SummarizeCaseHistoryAction.Request();
        request.caseId = caseId;
        request.maxComments = maxComments;
        return request;
    }

    @IsTest
    static void summarisesCaseWithRedactedComments() {
        TriageTestSupport.useSyntheticRules();
        System.runAs(TriageTestSupport.createTriageUser()) {
            Case record = new Case(
                Subject = 'Medical bill question',
                Description = 'Synthetic patient says the copay looks wrong.',
                Status = 'New',
                Priority = 'Medium',
                Origin = 'Web'
            );
            insert record;
            List<CaseComment> comments = new List<CaseComment>();
            for (Integer i = 0; i < 7; i++) {
                comments.add(
                    new CaseComment(
                        ParentId = record.Id,
                        CommentBody = 'Synthetic note ' + i + ' - call back on 555-010-0199 or test.member@example.com',
                        IsPublished = Math.mod(i, 2) == 0
                    )
                );
            }
            insert comments;

            Test.startTest();
            SummarizeCaseHistoryAction.Result result = SummarizeCaseHistoryAction.summarize(
                new List<SummarizeCaseHistoryAction.Request>{ requestFor(record.Id, 3) }
            )[0];
            Test.stopTest();

            Assert.isTrue(result.isSuccess, 'Success');
            Assert.areEqual(7, result.commentCount, 'Total comment count');
            Assert.areEqual(0, result.ageInDays, 'Created today');
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(result.summaryJson);
            Assert.areEqual(3, ((List<Object>) payload.get('recentComments')).size(), 'Limited to maxComments');
            Assert.areEqual('Patient Billing', payload.get('triageCategory'), 'Classification embedded');
            Assert.isFalse(result.summaryJson.contains('example.com'), 'Email redacted: ' + result.summaryJson);
            Assert.isFalse(result.summaryJson.contains('555-010-0199'), 'Phone redacted');
            Assert.isFalse(result.plainTextSummary.contains('example.com'), 'Plain text redacted');
            Assert.isTrue(result.plainTextSummary.startsWith('Case '), result.plainTextSummary);
        }
    }

    @IsTest
    static void handlesMultipleCasesAndMissingOnes() {
        TriageTestSupport.useSyntheticRules();
        System.runAs(TriageTestSupport.createTriageUser()) {
            List<Case> cases = new List<Case>{
                new Case(Subject = 'Synthetic appointment change', Status = 'New'),
                new Case(Subject = 'Synthetic closed question', Status = 'Closed')
            };
            insert cases;

            Integer queriesBefore = Limits.getQueries();
            List<SummarizeCaseHistoryAction.Result> results = SummarizeCaseHistoryAction.summarize(
                new List<SummarizeCaseHistoryAction.Request>{
                    requestFor(cases[0].Id, null),
                    requestFor(cases[1].Id, 50),
                    requestFor(null, null)
                }
            );

            Assert.areEqual(3, results.size(), 'One result per request');
            Assert.areEqual(0, results[0].commentCount, 'No comments');
            Assert.isTrue(results[1].plainTextSummary.contains('Closed after'), results[1].plainTextSummary);
            Assert.isFalse(results[2].isSuccess, 'Null case id');
            Assert.areEqual(3, Limits.getQueries() - queriesBefore, 'Case, comments and counts: three queries total');
        }
    }

    @IsTest
    static void clampsMaxComments() {
        Assert.areEqual(
            SummarizeCaseHistoryAction.DEFAULT_MAX_COMMENTS,
            SummarizeCaseHistoryAction.clampMax(null),
            'Default'
        );
        Assert.areEqual(
            SummarizeCaseHistoryAction.DEFAULT_MAX_COMMENTS,
            SummarizeCaseHistoryAction.clampMax(0),
            'Zero'
        );
        Assert.areEqual(SummarizeCaseHistoryAction.MAX_COMMENTS, SummarizeCaseHistoryAction.clampMax(500), 'Capped');
        Assert.areEqual(2, SummarizeCaseHistoryAction.clampMax(2), 'In range');
    }
}
