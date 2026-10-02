/**
 * Invocable action: classify a case's category and urgency.
 *
 * Usable from Flow and as an Agentforce agent action. It is read-only: it
 * returns a recommendation and never updates the case, so a human (or a Flow
 * step after review) stays in control of any change.
 */
public with sharing class ClassifyCaseAction {
    @InvocableMethod(
        label='Classify Case (Deterministic)'
        description='Recommends a service category and urgency for a case using transparent keyword rules. Read-only: returns a recommendation and does not update the case.'
        category='Case Triage'
    )
    public static List<Result> classify(List<Request> requests) {
        Map<Id, Case> casesById = loadCases(requests);
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            results.add(classifyOne(request, casesById));
        }
        return results;
    }

    private static Result classifyOne(Request request, Map<Id, Case> casesById) {
        String subject = request.subject;
        String description = request.description;
        if (request.caseId != null) {
            Case record = casesById.get(request.caseId);
            if (record == null) {
                return newFailure('Case not found or not accessible to the running user.');
            }
            subject = String.isBlank(subject) ? record.Subject : subject;
            description = String.isBlank(description) ? record.Description : description;
        }
        if (String.isBlank(subject) && String.isBlank(description)) {
            return newFailure('Provide a caseId or subject/description text to classify.');
        }
        return fromClassification(CaseTriageClassifier.classify(subject, description));
    }

    private static Map<Id, Case> loadCases(List<Request> requests) {
        Set<Id> caseIds = new Set<Id>();
        for (Request request : requests) {
            if (request.caseId != null) {
                caseIds.add(request.caseId);
            }
        }
        if (caseIds.isEmpty()) {
            return new Map<Id, Case>();
        }
        return new Map<Id, Case>([SELECT Id, Subject, Description FROM Case WHERE Id IN :caseIds WITH USER_MODE]);
    }

    /** Action input. */
    public class Request {
        @InvocableVariable(
            label='Case Id'
            description='Id of the case to classify. Optional when subject or description text is supplied.'
        )
        public Id caseId;

        @InvocableVariable(label='Subject' description='Case subject text. Overrides the stored subject when provided.')
        public String subject;

        @InvocableVariable(
            label='Description'
            description='Case description text. Overrides the stored description when provided.'
        )
        public String description;
    }

    /** Action output. */
    public class Result {
        @InvocableVariable(label='Success' description='False when the case could not be read or no text was supplied.')
        public Boolean isSuccess = true;

        @InvocableVariable(
            label='Category'
            description='Recommended service category, e.g. Fraud, Card Dispute, General.'
        )
        public String category;

        @InvocableVariable(label='Urgency' description='Recommended urgency: Critical, High, Medium or Low.')
        public String urgency;

        @InvocableVariable(label='Confidence' description='Share of keyword evidence for the chosen category, 0 to 1.')
        public Decimal confidence;

        @InvocableVariable(label='Matched Keywords' description='Rule keywords that matched. Contains no case text.')
        public List<String> matchedKeywords;

        @InvocableVariable(
            label='Requires Human Review'
            description='True when confidence is low, the category is General or urgency is Critical.'
        )
        public Boolean requiresHumanReview;

        @InvocableVariable(label='Rationale' description='Plain-language explanation of the recommendation.')
        public String rationale;

        @InvocableVariable(label='Error Message' description='Populated when Success is false.')
        public String errorMessage;
    }

    private static Result fromClassification(CaseTriageClassifier.Classification classification) {
        Result result = new Result();
        result.category = classification.category;
        result.urgency = classification.urgency;
        result.confidence = classification.confidence;
        result.matchedKeywords = classification.matchedKeywords;
        result.requiresHumanReview = classification.requiresHumanReview;
        result.rationale = classification.rationale;
        return result;
    }

    private static Result newFailure(String message) {
        Result result = new Result();
        result.isSuccess = false;
        result.requiresHumanReview = true;
        result.errorMessage = message;
        return result;
    }
}
