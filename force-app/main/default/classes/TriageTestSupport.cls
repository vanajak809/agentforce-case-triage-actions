/**
 * Synthetic users, cases and rules for the triage tests.
 */
@IsTest
public class TriageTestSupport {
    public static User createTriageUser() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String unique = String.valueOf(Math.abs(Crypto.getRandomInteger())) + '.' + UserInfo.getOrganizationId();
        User triageUser = new User(
            Alias = 'triage',
            Email = 'triage.' + unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'Triage',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'triage.' + unique + '@example.com'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert triageUser;
            PermissionSet permissionSet = [SELECT Id FROM PermissionSet WHERE Name = 'Case_Triage_Agent' LIMIT 1];
            insert new PermissionSetAssignment(AssigneeId = triageUser.Id, PermissionSetId = permissionSet.Id);
        }
        return triageUser;
    }

    /** Mirrors a subset of the shipped Triage_Rule records for deterministic tests. */
    public static void useSyntheticRules() {
        TriageRuleSelector.mockRules = new List<TriageRuleSelector.TriageRule>{
            new TriageRuleSelector.TriageRule('fraud', 'Fraud', 3, 3),
            new TriageRuleSelector.TriageRule('stolen card', 'Fraud', 3, 3),
            new TriageRuleSelector.TriageRule('suspicious', 'Fraud', 2, 1),
            new TriageRuleSelector.TriageRule('dispute', 'Card Dispute', 3, 0),
            new TriageRuleSelector.TriageRule('refund', 'Card Dispute', 1, 0),
            new TriageRuleSelector.TriageRule('locked out', 'Account Access', 3, 2),
            new TriageRuleSelector.TriageRule('medical bill', 'Patient Billing', 3, 0),
            new TriageRuleSelector.TriageRule('appointment', 'Appointments', 3, 0),
            new TriageRuleSelector.TriageRule('mortgage', 'Loan Servicing', 2, 0),
            new TriageRuleSelector.TriageRule('urgent', null, 0, 2),
            new TriageRuleSelector.TriageRule('emergency', null, 0, 3),
            new TriageRuleSelector.TriageRule('today', null, 0, 1)
        };
    }
}
