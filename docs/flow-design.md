# Flow-ready design: "Case - Triage on Create" (design document)

This is a **design**, not a deployed Flow. Hand-written Flow XML is brittle, so
the recommended path is to build it in Flow Builder from this specification,
then retrieve it (`sf project retrieve start --metadata Flow:Case_Triage_On_Create`).

## Trigger

- Record-triggered Flow on **Case**, *A record is created*.
- Optimise for **Actions and Related Records** (after save).
- Entry condition: `Origin` is not `Internal` (example). Run asynchronously
  ("Run Asynchronously" path) so triage never slows down case creation.

## Steps

```mermaid
flowchart TD
    S([Case created]) --> A1[Apex action: Classify Case<br/>input caseId = Record.Id]
    A1 --> D1{isSuccess?}
    D1 -- No --> F1[Update Case: Needs_Human_Review__c = true<br/>Triage_Rationale__c = errorMessage]
    D1 -- Yes --> A2[Apex action: Recommend Case Queue<br/>category, urgency]
    A2 --> U1[Update Case:<br/>AI_Category__c, AI_Urgency__c, AI_Confidence__c,<br/>Triage_Rationale__c, Needs_Human_Review__c]
    U1 --> D2{requiresHumanReview?}
    D2 -- Yes --> R1[Assign to queue General_Support<br/>or a review queue;<br/>do NOT auto-route]
    D2 -- No --> D3{Recommend Case Queue isSuccess?}
    D3 -- Yes --> R2[Update Case OwnerId = queueId]
    D3 -- No --> R1
    F1 --> E([End])
    R1 --> E
    R2 --> E
```

## Variable mapping

| Action output | Case field |
| --- | --- |
| Classify Case > Category | `AI_Category__c` |
| Classify Case > Urgency | `AI_Urgency__c` |
| Classify Case > Confidence | `AI_Confidence__c` |
| Classify Case > Rationale | `Triage_Rationale__c` |
| Classify Case > Requires Human Review | `Needs_Human_Review__c` |
| Recommend Case Queue > Queue Id | `OwnerId` (only when no review is required) |

## Notes

- All three Apex actions are **read-only**. The Flow owns every DML, so record
  changes are visible in Flow debug logs and can be paused or reviewed.
- The actions are bulkified: a Flow interview batch of 200 cases results in one
  SOQL query per action.
- The running user (or the Automated Process user for async paths) needs the
  `Case_Triage_Agent` permission set.
