# Sample Prompt Template: "Case Triage Summary" (documentation only)

> This file describes a Prompt Builder template that *could* be built on top of
> the actions in this repository. **It is not deployed by this project**, and no
> generative output from it is claimed or shown here. Prompt templates need an
> org with Einstein generative AI / Agentforce enabled.

## Purpose

Give a service agent a short, neutral briefing of a case before they pick it up,
grounded only in data already redacted by `SummarizeCaseHistoryAction`.

## Template type and inputs

| Item | Value |
| --- | --- |
| Template type | Flex |
| Input | `Case` (record) |
| Grounding | Apex: `SummarizeCaseHistoryAction` output `summaryJson` (PII-redacted), resolved through a Flow or an Apex-grounded resource |
| Output | 3 bullet points + suggested next step |

## Draft prompt text

```text
You are assisting a customer service agent at a fictional financial and healthcare
services organisation. Use ONLY the JSON below. Do not invent facts.
If information is missing, say "Not available".

Case data (already redacted, contains no personal identifiers):
{!$Flow:Get_Case_Summary.Prompt.summaryJson}

Write:
1. Three short bullet points describing the situation and what has been done so far.
2. One suggested next step for the agent, phrased as a recommendation.
Rules:
- Do not include names, emails, phone numbers, account or card numbers, or medical details.
- If "requiresHumanReview" is true, start with: "Review required before acting."
- Keep the total under 90 words. Neutral, professional tone.
```

## Guardrails applied

- **Data minimisation:** the grounding payload contains no Contact or Account names
  and is passed through `PiiRedactor` (emails, phones, card numbers, SSN-like and
  MRN-like values, dates).
- **Einstein Trust Layer (platform feature, configured in Setup, not by this repo):**
  data masking, zero-data-retention with the LLM provider, toxicity scoring and
  the audit trail should be enabled and reviewed by the org's admins.
- **Human in the loop:** the template only produces text for the agent to read.
  It does not change records. The `requiresHumanReview` flag is surfaced to the
  model and to the UI.
- **Evaluation:** before production use, test the template against a fixed set
  of synthetic cases and review the outputs for hallucination and tone.
