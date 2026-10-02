@IsTest
private class PiiRedactor_Test {
    @IsTest
    static void redactsCommonPatterns() {
        // All values below are synthetic test fixtures.
        String input =
            'Reach me at test.member@example.com or (555) 010-0199. ' +
            'Card 4111 1111 1111 1111, SSN 000-12-3456, MRN: 0012345, born 01/02/1990.';
        String output = PiiRedactor.redact(input);
        Assert.isTrue(output.contains('[EMAIL]'), output);
        Assert.isTrue(output.contains('[PHONE]'), output);
        Assert.isTrue(output.contains('[CARD]'), output);
        Assert.isTrue(output.contains('[SSN]'), output);
        Assert.isTrue(output.contains('[MRN]'), output);
        Assert.isTrue(output.contains('[DATE]'), output);
        Assert.isFalse(output.contains('example.com'), output);
        Assert.isFalse(output.contains('4111'), output);
    }

    @IsTest
    static void leavesOrdinaryTextAlone() {
        String input = 'Synthetic member asked about case 00001234 and a fee of 25 dollars.';
        Assert.areEqual(input, PiiRedactor.redact(input), 'No false positives on short numbers');
        Assert.isNull(PiiRedactor.redact(null), 'Null safe');
    }
}
