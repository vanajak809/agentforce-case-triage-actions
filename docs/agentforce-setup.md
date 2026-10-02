# Using the actions in Agentforce (requires an Agentforce-enabled org)

Nothing in this file is deployed by the project. It describes how the
invocable actions would be wired into an agent. Exact menu names change between
releases, so follow current Salesforce documentation for your org.

## Prerequisites

- An org with Agentforce (Einstein generative AI) enabled and licensed.
- This project deployed, and `Case_Triage_Agent` assigned to the agent user.

## Agent actions

Create agent actions from these Apex invocable methods. Their labels and
input/output descriptions come from `@InvocableMethod` / `@InvocableVariable`
and are written so an agent planner can choose and fill them correctly.

| Apex action | Suggested agent action instructions |
| --- | --- |
| Classify Case (Deterministic) | "Use when the user asks what kind of case this is or how urgent it is. Pass the case Id. Report category, urgency and rationale. If Requires Human Review is true, say a person must confirm." |
| Summarize Case History | "Use when the user asks for a summary or history of a case. Pass the case Id. Only describe what is in the returned summary." |
| Recommend Case Queue | "Use after classifying a case when the user asks where it should go. Pass category and urgency from Classify Case. Present the queue as a recommendation; never claim the case was moved." |

## Topic: "Case Triage" (example)

- **Classification description:** Questions about categorising, prioritising,
  summarising or routing existing service cases.
- **Scope:** Recommend only. Do not update records, do not contact customers.
- **Instructions (examples):**
  - "Always classify before recommending a queue."
  - "Never reveal or ask for personal data such as card numbers, account numbers, dates of birth or medical details."
  - "If an action returns Success = false, explain that a person needs to review the case."

## Guardrails checklist

- [ ] Einstein Trust Layer data masking enabled and reviewed.
- [ ] Agent user has only `Case_Triage_Agent` plus the minimum agent permissions.
- [ ] Actions remain read-only. Any routing change goes through Flow or a person.
- [ ] Test conversations run against synthetic data before enabling for users.
- [ ] Audit trail and feedback reviewed regularly.
