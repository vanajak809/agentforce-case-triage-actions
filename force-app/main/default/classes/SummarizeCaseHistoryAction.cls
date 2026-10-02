/**
 * Invocable action: summarise a case and its recent comments into a compact,
 * structured payload suitable for grounding an Agentforce agent or a Prompt
 * Builder template.
 *
 * Data minimisation: only case-level fields and comment excerpts are included.
 * Contact/Account names, emails and phone numbers are never queried, and all
 * free text passes through PiiRedactor before it leaves this class.
 */
public with sharing class SummarizeCaseHistoryAction {
    @TestVisible
    private static final Integer DEFAULT_MAX_COMMENTS = 5;
    @TestVisible
    private static final Integer MAX_COMMENTS = 20;
    @TestVisible
    private static final Integer EXCERPT_LENGTH = 280;

    @InvocableMethod(
        label='Summarize Case History'
        description='Returns a structured, PII-redacted summary of a case and its most recent comments, including a deterministic triage classification. Read-only.'
        category='Case Triage'
    )
    public static List<Result> summarize(List<Request> requests) {
        Set<Id> caseIds = new Set<Id>();
        for (Request request : requests) {
            if (request.caseId != null) {
                caseIds.add(request.caseId);
            }
        }
        Map<Id, Case> casesById = new Map<Id, Case>();
        Map<Id, List<CaseComment>> commentsByCaseId = new Map<Id, List<CaseComment>>();
        Map<Id, Integer> commentCountByCaseId = new Map<Id, Integer>();
        if (!caseIds.isEmpty()) {
            casesById = new Map<Id, Case>(
                [
                    SELECT
                        Id,
                        CaseNumber,
                        Subject,
                        Description,
                        Status,
                        Priority,
                        Origin,
                        CreatedDate,
                        ClosedDate,
                        IsClosed
                    FROM Case
                    WHERE Id IN :caseIds
                    WITH USER_MODE
                ]
            );
            for (CaseComment comment : [
                SELECT ParentId, CommentBody, IsPublished, CreatedDate
                FROM CaseComment
                WHERE ParentId IN :caseIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 2000
            ]) {
                if (!commentsByCaseId.containsKey(comment.ParentId)) {
                    commentsByCaseId.put(comment.ParentId, new List<CaseComment>());
                }
                commentsByCaseId.get(comment.ParentId).add(comment);
            }
            for (AggregateResult row : [
                SELECT ParentId caseId, COUNT(Id) total
                FROM CaseComment
                WHERE ParentId IN :caseIds
                WITH USER_MODE
                GROUP BY ParentId
            ]) {
                commentCountByCaseId.put((Id) row.get('caseId'), (Integer) row.get('total'));
            }
        }

        List<Result> results = new List<Result>();
        for (Request request : requests) {
            Case record = request.caseId == null ? null : casesById.get(request.caseId);
            if (record == null) {
                results.add(newFailure('Case not found or not accessible to the running user.'));
                continue;
            }
            List<CaseComment> comments = commentsByCaseId.containsKey(record.Id)
                ? commentsByCaseId.get(record.Id)
                : new List<CaseComment>();
            Integer total = commentCountByCaseId.containsKey(record.Id) ? commentCountByCaseId.get(record.Id) : 0;
            results.add(buildResult(record, comments, total, clampMax(request.maxComments)));
        }
        return results;
    }

    @TestVisible
    private static Integer clampMax(Integer requested) {
        if (requested == null || requested < 1) {
            return DEFAULT_MAX_COMMENTS;
        }
        return Math.min(requested, MAX_COMMENTS);
    }

    private static Result buildResult(
        Case record,
        List<CaseComment> comments,
        Integer totalComments,
        Integer maxComments
    ) {
        CaseTriageClassifier.Classification classification = CaseTriageClassifier.classify(
            record.Subject,
            record.Description
        );
        Date openedOn = record.CreatedDate == null ? Date.today() : record.CreatedDate.date();
        Date endsOn = (record.IsClosed && record.ClosedDate != null) ? record.ClosedDate.date() : Date.today();

        SummaryPayload payload = new SummaryPayload();
        payload.caseNumber = record.CaseNumber;
        payload.subject = excerpt(record.Subject);
        payload.status = record.Status;
        payload.priority = record.Priority;
        payload.origin = record.Origin;
        payload.isClosed = record.IsClosed;
        payload.ageInDays = openedOn.daysBetween(endsOn);
        payload.commentCount = totalComments;
        payload.triageCategory = classification.category;
        payload.triageUrgency = classification.urgency;
        payload.requiresHumanReview = classification.requiresHumanReview;
        payload.recentComments = new List<CommentPayload>();
        for (Integer i = 0; i < comments.size() && i < maxComments; i++) {
            CommentPayload item = new CommentPayload();
            item.createdDate = comments[i].CreatedDate;
            item.isPublic = comments[i].IsPublished;
            item.excerpt = excerpt(comments[i].CommentBody);
            payload.recentComments.add(item);
        }

        Result result = new Result();
        result.isSuccess = true;
        result.caseNumber = payload.caseNumber;
        result.ageInDays = payload.ageInDays;
        result.commentCount = payload.commentCount;
        result.summaryJson = JSON.serialize(payload, true);
        result.plainTextSummary = toPlainText(payload);
        return result;
    }

    private static String toPlainText(SummaryPayload payload) {
        String text =
            'Case ' +
            payload.caseNumber +
            ' | Status: ' +
            payload.status +
            ' | Priority: ' +
            payload.priority +
            ' | ' +
            (payload.isClosed ? 'Closed after ' : 'Open for ') +
            payload.ageInDays +
            ' day(s) | ' +
            payload.commentCount +
            ' comment(s) | Triage: ' +
            payload.triageCategory +
            ' / ' +
            payload.triageUrgency +
            '.';
        if (!payload.recentComments.isEmpty()) {
            CommentPayload latest = payload.recentComments[0];
            text += ' Latest ' + (latest.isPublic ? 'public' : 'internal') + ' comment: ' + latest.excerpt;
        }
        return text;
    }

    private static String excerpt(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        return PiiRedactor.redact(value.normalizeSpace()).abbreviate(EXCERPT_LENGTH);
    }

    private static Result newFailure(String message) {
        Result result = new Result();
        result.isSuccess = false;
        result.errorMessage = message;
        return result;
    }

    /** Action input. */
    public class Request {
        @InvocableVariable(label='Case Id' description='Id of the case to summarise.' required=true)
        public Id caseId;

        @InvocableVariable(
            label='Max Comments'
            description='Number of most recent comments to include (1-20, default 5).'
        )
        public Integer maxComments;
    }

    /** Action output. */
    public class Result {
        @InvocableVariable(label='Success' description='False when the case could not be read.')
        public Boolean isSuccess;

        @InvocableVariable(label='Case Number' description='Case number of the summarised case.')
        public String caseNumber;

        @InvocableVariable(label='Age In Days' description='Days the case has been (or was) open.')
        public Integer ageInDays;

        @InvocableVariable(label='Comment Count' description='Total number of comments on the case.')
        public Integer commentCount;

        @InvocableVariable(
            label='Summary JSON'
            description='Structured, PII-redacted summary for grounding prompts and agent responses.'
        )
        public String summaryJson;

        @InvocableVariable(label='Plain Text Summary' description='One-paragraph, PII-redacted summary.')
        public String plainTextSummary;

        @InvocableVariable(label='Error Message' description='Populated when Success is false.')
        public String errorMessage;
    }

    /** Serialized shape of summaryJson. */
    public class SummaryPayload {
        public String caseNumber;
        public String subject;
        public String status;
        public String priority;
        public String origin;
        public Boolean isClosed;
        public Integer ageInDays;
        public Integer commentCount;
        public String triageCategory;
        public String triageUrgency;
        public Boolean requiresHumanReview;
        public List<CommentPayload> recentComments;
    }

    /** One comment inside SummaryPayload. */
    public class CommentPayload {
        public Datetime createdDate;
        public Boolean isPublic;
        public String excerpt;
    }
}
