/**
 * Loads active Triage_Rule__mdt records as DTOs. Tests can inject rules via
 * mockRules so classification tests do not depend on deployed metadata.
 */
public inherited sharing class TriageRuleSelector {
    @TestVisible
    private static List<TriageRule> mockRules;
    private static List<TriageRule> cachedRules;

    public static List<TriageRule> getRules() {
        if (mockRules != null) {
            return mockRules;
        }
        if (cachedRules == null) {
            cachedRules = new List<TriageRule>();
            for (Triage_Rule__mdt record : Triage_Rule__mdt.getAll().values()) {
                if (record.Is_Active__c && String.isNotBlank(record.Keyword__c)) {
                    cachedRules.add(
                        new TriageRule(
                            record.Keyword__c,
                            record.Category__c,
                            record.Category_Weight__c,
                            record.Urgency_Weight__c
                        )
                    );
                }
            }
        }
        return cachedRules;
    }

    /** Plain DTO mirroring Triage_Rule__mdt. */
    public class TriageRule {
        public String keyword;
        public String category;
        public Decimal categoryWeight;
        public Decimal urgencyWeight;

        public TriageRule(String keyword, String category, Decimal categoryWeight, Decimal urgencyWeight) {
            this.keyword = keyword == null ? '' : keyword.toLowerCase().normalizeSpace();
            this.category = category;
            this.categoryWeight = categoryWeight == null ? 0 : categoryWeight;
            this.urgencyWeight = urgencyWeight == null ? 0 : urgencyWeight;
        }
    }
}
