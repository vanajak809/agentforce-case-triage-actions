@IsTest
private class CaseTriageClassifier_Test {
    @IsTest
    static void classifiesFraudWithHighConfidence() {
        TriageTestSupport.useSyntheticRules();
        CaseTriageClassifier.Classification result = CaseTriageClassifier.classify(
            'Stolen card!',
            'I think there is fraud on my synthetic account.'
        );
        Assert.areEqual('Fraud', result.category, 'Category');
        Assert.areEqual('Critical', result.urgency, 'Urgency score 6 is Critical');
        Assert.areEqual(1.00, result.confidence, 'All evidence points to Fraud');
        Assert.isTrue(result.requiresHumanReview, 'Critical always needs review');
        Assert.areEqual(new List<String>{ 'fraud', 'stolen card' }, result.matchedKeywords, 'Keywords in rule order');
    }

    @IsTest
    static void fraudIsNeverBelowHigh() {
        TriageTestSupport.useSyntheticRules();
        CaseTriageClassifier.Classification result = CaseTriageClassifier.classify('Suspicious text message', null);
        Assert.areEqual('Fraud', result.category, 'Category');
        Assert.areEqual('High', result.urgency, 'Fraud floor');
    }

    @IsTest
    static void classifiesHealthcareBillingAsMediumWithUrgencyWord() {
        TriageTestSupport.useSyntheticRules();
        CaseTriageClassifier.Classification result = CaseTriageClassifier.classify(
            'Question about my medical bill',
            'Need an answer today please'
        );
        Assert.areEqual('Patient Billing', result.category, 'Category');
        Assert.areEqual('Medium', result.urgency, 'Urgency score 1');
        Assert.isFalse(result.requiresHumanReview, 'Confident, non-critical');
    }

    @IsTest
    static void matchesWholeWordsOnly() {
        TriageTestSupport.useSyntheticRules();
        CaseTriageClassifier.Classification result = CaseTriageClassifier.classify(
            'Refundable deposit',
            'disputed? no'
        );
        Assert.areEqual('General', result.category, 'Partial words do not match');
        Assert.areEqual(0, result.confidence, 'No evidence');
        Assert.isTrue(result.requiresHumanReview, 'General needs review');
        Assert.isTrue(result.rationale.startsWith('No triage keywords matched'), result.rationale);
    }

    @IsTest
    static void mixedSignalsLowerConfidenceAndRequireReview() {
        TriageTestSupport.useSyntheticRules();
        CaseTriageClassifier.Classification result = CaseTriageClassifier.classify(
            'Dispute and appointment',
            'mortgage too'
        );
        // Card Dispute 3, Appointments 3, Loan Servicing 2 -> tie broken by priority list.
        Assert.areEqual('Card Dispute', result.category, 'Tie-break by category priority');
        Assert.areEqual(0.38, result.confidence, '3 of 8 points');
        Assert.isTrue(result.requiresHumanReview, 'Low confidence');
    }

    @IsTest
    static void urgencyThresholds() {
        Assert.areEqual('Low', CaseTriageClassifier.toUrgency(0, 'General'), '0');
        Assert.areEqual('Medium', CaseTriageClassifier.toUrgency(1, 'General'), '1');
        Assert.areEqual('High', CaseTriageClassifier.toUrgency(3, 'General'), '3');
        Assert.areEqual('Critical', CaseTriageClassifier.toUrgency(5, 'General'), '5');
        Assert.areEqual('High', CaseTriageClassifier.toUrgency(0, 'Fraud'), 'Fraud floor');
    }

    @IsTest
    static void unknownCategoriesRankAfterKnownOnTies() {
        Map<String, Decimal> scores = new Map<String, Decimal>{ 'Custom Category' => 3, 'Appointments' => 3 };
        Assert.areEqual('Appointments', CaseTriageClassifier.pickCategory(scores), 'Known category wins tie');
        Assert.areEqual('General', CaseTriageClassifier.pickCategory(new Map<String, Decimal>()), 'Empty');
    }

    @IsTest
    static void shippedRulesAreDeployedAndUsable() {
        List<TriageRuleSelector.TriageRule> rules = TriageRuleSelector.getRules();
        Assert.isTrue(rules.size() >= 20, 'Triage_Rule records must be deployed');
        CaseTriageClassifier.Classification result = CaseTriageClassifier.classify(
            'Locked out of online banking',
            null
        );
        Assert.areEqual('Account Access', result.category, 'Shipped rule set works end to end');
    }
}
