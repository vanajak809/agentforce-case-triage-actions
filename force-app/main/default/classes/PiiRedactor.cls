/**
 * Best-effort redaction of common PII/PHI patterns before text is returned to
 * an agent, a prompt template or a Flow. Defence in depth only: it complements,
 * and does not replace, data minimisation and the Einstein Trust Layer.
 */
public inherited sharing class PiiRedactor {
    // Order matters: the most specific patterns run first.
    private static final List<List<String>> RULES = new List<List<String>>{
        new List<String>{ '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}', '[EMAIL]' },
        new List<String>{ '\\b\\d{3}-\\d{2}-\\d{4}\\b', '[SSN]' },
        new List<String>{ '(?i)\\bMRN[:#\\s]*\\d{5,}\\b', '[MRN]' },
        new List<String>{ '\\b\\d(?:[ -]?\\d){12,18}\\b', '[CARD]' },
        new List<String>{ '(?:\\+?1[ .-]?)?(?:\\(\\d{3}\\)|\\b\\d{3})[ .-]?\\d{3}[ .-]?\\d{4}\\b', '[PHONE]' },
        new List<String>{ '\\b\\d{1,2}/\\d{1,2}/\\d{2,4}\\b', '[DATE]' }
    };

    public static String redact(String value) {
        if (String.isBlank(value)) {
            return value;
        }
        String result = value;
        for (List<String> rule : RULES) {
            result = result.replaceAll(rule[0], rule[1]);
        }
        return result;
    }
}
