/**
 * Deterministic, explainable case classifier.
 *
 * This is intentionally NOT a machine learning model or an LLM call: it scores
 * synthetic keyword rules (Triage_Rule__mdt) so that results are reproducible,
 * testable and auditable. It is suitable as a first-pass recommendation that an
 * Agentforce agent or Flow can present to a human, or as a fallback when
 * generative features are unavailable.
 */
public inherited sharing class CaseTriageClassifier {
    public static final String CATEGORY_GENERAL = 'General';
    public static final String CATEGORY_FRAUD = 'Fraud';
    public static final String URGENCY_CRITICAL = 'Critical';
    public static final String URGENCY_HIGH = 'High';
    public static final String URGENCY_MEDIUM = 'Medium';
    public static final String URGENCY_LOW = 'Low';
    public static final Decimal REVIEW_CONFIDENCE_THRESHOLD = 0.6;

    /** Tie-break order when two categories score the same. */
    @TestVisible
    private static final List<String> CATEGORY_PRIORITY = new List<String>{
        CATEGORY_FRAUD,
        'Card Dispute',
        'Account Access',
        'Patient Billing',
        'Appointments',
        'Loan Servicing'
    };

    public static Classification classify(String subject, String description) {
        String text = normalize((subject == null ? '' : subject) + ' ' + (description == null ? '' : description));
        Map<String, Decimal> scoreByCategory = new Map<String, Decimal>();
        Decimal totalCategoryScore = 0;
        Decimal urgencyScore = 0;
        List<String> matchedKeywords = new List<String>();

        for (TriageRuleSelector.TriageRule rule : TriageRuleSelector.getRules()) {
            if (String.isBlank(rule.keyword) || !text.contains(' ' + rule.keyword + ' ')) {
                continue;
            }
            matchedKeywords.add(rule.keyword);
            urgencyScore += rule.urgencyWeight;
            if (String.isNotBlank(rule.category) && rule.categoryWeight > 0) {
                Decimal current = scoreByCategory.containsKey(rule.category) ? scoreByCategory.get(rule.category) : 0;
                scoreByCategory.put(rule.category, current + rule.categoryWeight);
                totalCategoryScore += rule.categoryWeight;
            }
        }

        Classification result = new Classification();
        result.category = pickCategory(scoreByCategory);
        result.confidence = totalCategoryScore == 0
            ? 0
            : (scoreByCategory.get(result.category) / totalCategoryScore).setScale(2, RoundingMode.HALF_UP);
        result.urgency = toUrgency(urgencyScore, result.category);
        result.matchedKeywords = matchedKeywords;
        result.requiresHumanReview =
            result.category == CATEGORY_GENERAL ||
            result.confidence < REVIEW_CONFIDENCE_THRESHOLD ||
            result.urgency == URGENCY_CRITICAL;
        result.rationale = buildRationale(result, scoreByCategory, totalCategoryScore);
        return result;
    }

    /** Lower-cases, strips punctuation and pads with spaces for word-boundary matching. */
    @TestVisible
    private static String normalize(String value) {
        return ' ' + value.toLowerCase().replaceAll('[^a-z0-9]+', ' ').normalizeSpace() + ' ';
    }

    @TestVisible
    private static String pickCategory(Map<String, Decimal> scoreByCategory) {
        String best = CATEGORY_GENERAL;
        Decimal bestScore = 0;
        Integer bestRank = 9999;
        for (String category : scoreByCategory.keySet()) {
            Decimal score = scoreByCategory.get(category);
            Integer rank = CATEGORY_PRIORITY.indexOf(category);
            rank = rank < 0 ? 999 : rank;
            if (score > bestScore || (score == bestScore && rank < bestRank)) {
                best = category;
                bestScore = score;
                bestRank = rank;
            }
        }
        return best;
    }

    @TestVisible
    private static String toUrgency(Decimal score, String category) {
        String urgency;
        if (score >= 5) {
            urgency = URGENCY_CRITICAL;
        } else if (score >= 3) {
            urgency = URGENCY_HIGH;
        } else if (score >= 1) {
            urgency = URGENCY_MEDIUM;
        } else {
            urgency = URGENCY_LOW;
        }
        // Fraud is never below High, whatever the wording.
        if (category == CATEGORY_FRAUD && (urgency == URGENCY_MEDIUM || urgency == URGENCY_LOW)) {
            urgency = URGENCY_HIGH;
        }
        return urgency;
    }

    private static String buildRationale(
        Classification result,
        Map<String, Decimal> scoreByCategory,
        Decimal totalCategoryScore
    ) {
        if (result.matchedKeywords.isEmpty()) {
            return 'No triage keywords matched; routed to General for human review.';
        }
        String rationale =
            'Matched keywords: ' +
            String.join(result.matchedKeywords, ', ') +
            '. ' +
            result.category +
            ' scored ' +
            (scoreByCategory.containsKey(result.category) ? scoreByCategory.get(result.category) : 0) +
            ' of ' +
            totalCategoryScore +
            ' category points; urgency ' +
            result.urgency +
            '.';
        return rationale.abbreviate(255);
    }

    /** Classification outcome. Contains rule keywords only, never case text. */
    public class Classification {
        public String category;
        public String urgency;
        public Decimal confidence;
        public List<String> matchedKeywords;
        public Boolean requiresHumanReview;
        public String rationale;
    }
}
