/**
 * Invocable action: recommend the next-best queue for a triaged case.
 * Read-only. Ownership changes are left to the calling Flow or agent, after
 * any required human review.
 */
public with sharing class RecommendQueueAction {
    public static final String FALLBACK_QUEUE = 'General_Support';
    public static final String ESCALATION_QUEUE = 'Priority_Escalations';

    @TestVisible
    private static final Map<String, String> QUEUE_BY_CATEGORY = new Map<String, String>{
        'Fraud' => 'Fraud_Response',
        'Card Dispute' => 'Card_Disputes',
        'Account Access' => 'Digital_Banking_Support',
        'Loan Servicing' => 'Lending_Services',
        'Patient Billing' => 'Patient_Billing',
        'Appointments' => 'Care_Coordination',
        'General' => FALLBACK_QUEUE
    };

    @InvocableMethod(
        label='Recommend Case Queue'
        description='Recommends the queue a case should be routed to, based on its triage category and urgency. Read-only: does not change case ownership.'
        category='Case Triage'
    )
    public static List<Result> recommend(List<Request> requests) {
        Map<String, Group> queuesByDeveloperName = loadQueues();
        List<Result> results = new List<Result>();
        for (Request request : requests) {
            results.add(recommendOne(request, queuesByDeveloperName));
        }
        return results;
    }

    @TestVisible
    private static String targetQueue(String category, String urgency) {
        if (urgency == CaseTriageClassifier.URGENCY_CRITICAL && category != CaseTriageClassifier.CATEGORY_FRAUD) {
            return ESCALATION_QUEUE;
        }
        String mapped = category == null ? null : QUEUE_BY_CATEGORY.get(category);
        return mapped == null ? FALLBACK_QUEUE : mapped;
    }

    private static Result recommendOne(Request request, Map<String, Group> queuesByDeveloperName) {
        Result result = new Result();
        String target = targetQueue(request.category, request.urgency);
        Group queue = queuesByDeveloperName.get(target);
        result.fallbackUsed = false;
        if (queue == null && target != FALLBACK_QUEUE) {
            queue = queuesByDeveloperName.get(FALLBACK_QUEUE);
            result.fallbackUsed = true;
        }
        if (queue == null) {
            result.isSuccess = false;
            result.fallbackUsed = true;
            result.errorMessage = 'No matching queue is deployed. Deploy the queues in force-app/main/default/queues.';
            return result;
        }
        result.isSuccess = true;
        result.queueId = queue.Id;
        result.queueDeveloperName = queue.DeveloperName;
        result.queueName = queue.Name;
        result.reason = result.fallbackUsed
            ? 'Preferred queue ' + target + ' is unavailable; using ' + FALLBACK_QUEUE + '.'
            : buildReason(request, target);
        return result;
    }

    private static String buildReason(Request request, String target) {
        if (target == ESCALATION_QUEUE) {
            return 'Critical urgency outside fraud routes to ' + ESCALATION_QUEUE + '.';
        }
        return 'Category ' + (request.category == null ? 'unknown' : request.category) + ' maps to ' + target + '.';
    }

    private static Map<String, Group> loadQueues() {
        Set<String> names = new Set<String>(QUEUE_BY_CATEGORY.values());
        names.add(ESCALATION_QUEUE);
        Map<String, Group> result = new Map<String, Group>();
        for (Group queue : [
            SELECT Id, DeveloperName, Name
            FROM Group
            WHERE Type = 'Queue' AND DeveloperName IN :names
            WITH USER_MODE
        ]) {
            result.put(queue.DeveloperName, queue);
        }
        return result;
    }

    /** Action input. */
    public class Request {
        @InvocableVariable(
            label='Category'
            description='Triage category, typically the Category output of Classify Case.'
            required=true
        )
        public String category;

        @InvocableVariable(label='Urgency' description='Triage urgency: Critical, High, Medium or Low.')
        public String urgency;
    }

    /** Action output. */
    public class Result {
        @InvocableVariable(label='Success' description='False when no suitable queue exists in the org.')
        public Boolean isSuccess;

        @InvocableVariable(label='Queue Id' description='Id of the recommended queue (Group).')
        public Id queueId;

        @InvocableVariable(label='Queue Developer Name' description='Developer name of the recommended queue.')
        public String queueDeveloperName;

        @InvocableVariable(label='Queue Name' description='Display name of the recommended queue.')
        public String queueName;

        @InvocableVariable(label='Reason' description='Why this queue was recommended.')
        public String reason;

        @InvocableVariable(label='Fallback Used' description='True when the preferred queue was not available.')
        public Boolean fallbackUsed;

        @InvocableVariable(label='Error Message' description='Populated when Success is false.')
        public String errorMessage;
    }
}
