import XCTest
@testable import ExpiraCore

/// L'OCR de date est le composant le plus risqué du produit : une date fausse
/// enregistrée sans que l'utilisateur s'en aperçoive lui fait jeter de la
/// nourriture. Ces tests verrouillent le comportement attendu, y compris les
/// cas où le parseur **doit** refuser de répondre.
final class ExpiryDateParserTests: XCTestCase {
    private let calendar = Calendar.expira
    private let parser = ExpiryDateParser()

    private func reference(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date()
    }

    private func components(_ date: Date) -> (Int, Int, Int) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    // MARK: - Formats reconnus

    func testParsesFrenchSlashFormat() throws {
        let result = try XCTUnwrap(
            parser.parse("À CONSOMMER AVANT LE 12/03/2026", referenceDate: reference(2026, 1, 10))
        )
        XCTAssertEqual(components(result.date).0, 2026)
        XCTAssertEqual(components(result.date).1, 3)
        XCTAssertEqual(components(result.date).2, 12)
        XCTAssertEqual(result.confidence, .high, "La mention « à consommer avant » doit élever la confiance")
    }

    func testParsesTwoDigitYear() throws {
        let result = try XCTUnwrap(parser.parse("DLC 05.09.26", referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).0, 2026)
        XCTAssertEqual(components(result.date).1, 9)
        XCTAssertEqual(components(result.date).2, 5)
    }

    func testParsesISOFormat() throws {
        let result = try XCTUnwrap(parser.parse("EXP 2026-07-21", referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 7)
        XCTAssertEqual(components(result.date).2, 21)
    }

    func testParsesTextualFrenchMonth() throws {
        let result = try XCTUnwrap(
            parser.parse("A CONSOMMER DE PREFERENCE AVANT LE 14 MARS 2026", referenceDate: reference(2026, 1, 10))
        )
        XCTAssertEqual(components(result.date).1, 3)
        XCTAssertEqual(components(result.date).2, 14)
    }

    func testParsesAccentedTextualMonth() throws {
        let result = try XCTUnwrap(parser.parse("DLUO 03 FÉVRIER 2027", referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).0, 2027)
        XCTAssertEqual(components(result.date).1, 2)
    }

    func testMonthYearOnlyResolvesToEndOfMonth() throws {
        let result = try XCTUnwrap(parser.parse("DDM 04/2026", referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 4)
        XCTAssertEqual(components(result.date).2, 30, "Un mois sans jour doit se terminer le dernier jour du mois")
    }

    func testDayMonthWithoutYearUsesNextOccurrence() throws {
        let result = try XCTUnwrap(parser.parse("A CONSOMMER JUSQU AU 05/01", referenceDate: reference(2026, 11, 20)))
        XCTAssertEqual(components(result.date).0, 2027, "05/01 après le 20 novembre désigne l'année suivante")
        XCTAssertEqual(components(result.date).1, 1)
        XCTAssertEqual(components(result.date).2, 5)
    }

    // MARK: - Priorités et arbitrages

    func testExpiryKeywordWinsOverProductionDate() throws {
        let text = "FAB 01/01/2026  A CONSOMMER AVANT LE 15/06/2026"
        let result = try XCTUnwrap(parser.parse(text, referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 6)
        XCTAssertEqual(components(result.date).2, 15)
    }

    func testPrefersLatestDateWhenNoKeyword() throws {
        let text = "10/02/2026 18/08/2026"
        let result = try XCTUnwrap(parser.parse(text, referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 8, "Entre deux dates neutres, la péremption est la plus tardive")
    }

    func testAmericanOrderIsCorrected() throws {
        let result = try XCTUnwrap(parser.parse("EXP 03/26/2026", referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 3)
        XCTAssertEqual(components(result.date).2, 26)
    }

    // MARK: - Refus (aussi importants que les réussites)

    func testRejectsImplausiblyDistantDate() {
        XCTAssertNil(
            parser.parse("LOT 12/03/2099", referenceDate: reference(2026, 1, 10)),
            "Une date à 70 ans est un numéro de lot mal lu, pas une DLC"
        )
    }

    func testRejectsLongExpiredDate() {
        XCTAssertNil(
            parser.parse("12/03/2015", referenceDate: reference(2026, 1, 10)),
            "Une date vieille de plus d'un an ne peut pas être une DLC utile"
        )
    }

    func testRejectsInvalidCalendarDate() {
        XCTAssertNil(
            parser.parse("DLC 31/02/2026", referenceDate: reference(2026, 1, 10)),
            "Le 31 février ne doit pas être corrigé en 3 mars"
        )
    }

    func testRejectsTextWithoutAnyDate() {
        XCTAssertNil(parser.parse("LAIT DEMI ECREME 1L BIO", referenceDate: reference(2026, 1, 10)))
    }

    func testIgnoresAmbiguousPairWhenACompleteDateExists() throws {
        // « 250 g » ne doit pas être lu comme une date alors qu'une vraie date est présente.
        let text = "POIDS NET 25/03 ... A CONSOMMER AVANT LE 09/04/2026"
        let result = try XCTUnwrap(parser.parse(text, referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 4)
        XCTAssertEqual(components(result.date).2, 9)
    }

    func testParsesFromMultipleOCRLines() throws {
        let lines = ["A CONSOMMER", "AVANT LE", "22/05/2026", "LOT 4471"]
        let result = try XCTUnwrap(parser.parse(lines: lines, referenceDate: reference(2026, 1, 10)))
        XCTAssertEqual(components(result.date).1, 5)
        XCTAssertEqual(components(result.date).2, 22)
    }

    func testConfidenceRequiresConfirmationWhenNoKeyword() throws {
        let result = try XCTUnwrap(parser.parse("18/08/2026", referenceDate: reference(2026, 1, 10)))
        XCTAssertTrue(
            result.confidence.requiresConfirmation,
            "Sans mention explicite, l'interface doit demander confirmation"
        )
    }
}
