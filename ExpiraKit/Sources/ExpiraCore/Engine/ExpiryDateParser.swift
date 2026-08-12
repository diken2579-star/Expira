import Foundation

/// Date de péremption détectée dans un texte reconnu par OCR.
public struct DetectedExpiryDate: Equatable, Sendable {
    public enum Confidence: Int, Sendable, Hashable, Comparable {
        /// Une mention explicite (« À consommer avant », « DLC », « EXP ») accompagne la date.
        case high = 2
        /// Date complète et plausible, sans mention explicite.
        case medium = 1
        /// Date partielle (mois/année) ou fortement ambiguë.
        case low = 0

        public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        /// En dessous de `.high`, l'interface demande une confirmation explicite
        /// avant d'enregistrer.
        public var requiresConfirmation: Bool { self < .high }
    }

    public let date: Date
    public let confidence: Confidence
    public let matchedText: String

    public init(date: Date, confidence: Confidence, matchedText: String) {
        self.date = date
        self.confidence = confidence
        self.matchedText = matchedText
    }
}

/// Extrait une date de péremption d'un texte brut issu de l'OCR.
///
/// Conçu pour les emballages français et européens. Le principe directeur :
/// **ne jamais renvoyer une date douteuse**. Un « je n'ai pas lu » suivi d'une
/// roue de sélection coûte 3 secondes à l'utilisateur ; une date fausse
/// enregistrée sans qu'il s'en aperçoive lui fait jeter de la nourriture.
public struct ExpiryDateParser: Sendable {
    private let calendar: Calendar

    /// Fenêtre de plausibilité : on refuse tout ce qui est trop ancien ou trop
    /// lointain, ce sont presque toujours des numéros de lot mal lus.
    private let maxPastDays = 400
    private let maxFutureDays = 365 * 5

    public init(calendar: Calendar = .expira) {
        self.calendar = calendar
    }

    // MARK: - API

    public func parse(lines: [String], referenceDate: Date = Date()) -> DetectedExpiryDate? {
        parse(lines.joined(separator: " "), referenceDate: referenceDate)
    }

    public func parse(_ rawText: String, referenceDate: Date = Date()) -> DetectedExpiryDate? {
        let text = Self.normalizeForDates(rawText)
        guard !text.isEmpty else { return nil }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let hasExpiryKeyword = Self.containsExpiryKeyword(text)

        var candidates: [Candidate] = []
        // Zones de texte déjà interprétées comme une date complète.
        //
        // On y inscrit une correspondance **même quand la date est rejetée**
        // (année aberrante, 31 février…). Sans cela, « 12/03/2015 » serait
        // rejeté par la règle numérique puis relu par la règle jour/mois comme
        // « 12 mars de cette année » — exactement le genre de date fausse que
        // ce parseur existe pour éviter.
        var consumedRanges: [NSRange] = []

        // 1. ISO — 2026-03-12
        for match in Self.regex(Self.isoPattern)?.matches(in: text, range: fullRange) ?? [] {
            guard let year = nsText.intValue(match.range(at: 1)),
                  let month = nsText.intValue(match.range(at: 2)),
                  let day = nsText.intValue(match.range(at: 3))
            else { continue }
            consumedRanges.append(match.range)
            guard let date = makeDate(day: day, month: month, year: year, referenceDate: referenceDate) else { continue }
            candidates.append(makeCandidate(date: date, match: match, in: nsText, baseConfidence: .medium, referenceDate: referenceDate))
        }

        // 2. Numérique complet — 12/03/26, 12.03.2026, 12-03-26
        for match in Self.regex(Self.numericPattern)?.matches(in: text, range: fullRange) ?? [] {
            guard Self.isDisjoint(match.range, from: consumedRanges),
                  var day = nsText.intValue(match.range(at: 1)),
                  var month = nsText.intValue(match.range(at: 2)),
                  let year = nsText.intValue(match.range(at: 3))
            else { continue }
            consumedRanges.append(match.range)
            // Format américain occasionnel (03/26/2026) : on rétablit l'ordre.
            if month > 12, day <= 12 { swap(&day, &month) }
            guard let date = makeDate(day: day, month: month, year: year, referenceDate: referenceDate) else { continue }
            candidates.append(makeCandidate(date: date, match: match, in: nsText, baseConfidence: .medium, referenceDate: referenceDate))
        }

        // 3. Mois en toutes lettres — 12 MARS 2026, 12 MAR 26
        for match in Self.regex(Self.textualMonthPattern)?.matches(in: text, range: fullRange) ?? [] {
            guard Self.isDisjoint(match.range, from: consumedRanges),
                  let day = nsText.intValue(match.range(at: 1)),
                  let month = Self.month(fromName: nsText.substring(with: match.range(at: 2))),
                  let year = nsText.intValue(match.range(at: 3))
            else { continue }
            consumedRanges.append(match.range)
            guard let date = makeDate(day: day, month: month, year: year, referenceDate: referenceDate) else { continue }
            candidates.append(makeCandidate(date: date, match: match, in: nsText, baseConfidence: .medium, referenceDate: referenceDate))
        }

        // 4. Mois/année — 03/2026 → fin du mois.
        for match in Self.regex(Self.monthYearPattern)?.matches(in: text, range: fullRange) ?? [] {
            guard Self.isDisjoint(match.range, from: consumedRanges),
                  let month = nsText.intValue(match.range(at: 1)),
                  let year = nsText.intValue(match.range(at: 2))
            else { continue }
            consumedRanges.append(match.range)
            guard (1...12).contains(month),
                  let date = endOfMonth(month: month, year: year, referenceDate: referenceDate)
            else { continue }
            candidates.append(makeCandidate(date: date, match: match, in: nsText, baseConfidence: .low, referenceDate: referenceDate))
        }

        // 5. Jour/mois sans année — 12/03 (très fréquent sur les produits frais).
        //    Trop ambigu pour être accepté seul : réservé aux textes qui portent
        //    une mention de péremption, ou aux textes sans aucune date complète.
        let hasCompleteDate = !consumedRanges.isEmpty
        if hasExpiryKeyword || !hasCompleteDate {
            for match in Self.regex(Self.dayMonthPattern)?.matches(in: text, range: fullRange) ?? [] {
                guard Self.isDisjoint(match.range, from: consumedRanges),
                      let first = nsText.intValue(match.range(at: 1)),
                      let second = nsText.intValue(match.range(at: 2))
                else { continue }

                let resolved: Date?
                if second > 12 {
                    // MM/YY — 03/26
                    resolved = (1...12).contains(first)
                        ? endOfMonth(month: first, year: 2000 + second, referenceDate: referenceDate)
                        : nil
                } else {
                    // DD/MM sans année : on prend la prochaine occurrence.
                    resolved = nextOccurrence(day: first, month: second, referenceDate: referenceDate)
                }
                guard let date = resolved else { continue }
                candidates.append(makeCandidate(date: date, match: match, in: nsText, baseConfidence: .low, referenceDate: referenceDate))
            }
        }

        return Self.best(of: candidates)
    }

    // MARK: - Sélection

    private struct Candidate {
        let date: Date
        let confidence: DetectedExpiryDate.Confidence
        let matchedText: String
        let isFuture: Bool
    }

    private func makeCandidate(
        date: Date,
        match: NSTextCheckingResult,
        in nsText: NSString,
        baseConfidence: DetectedExpiryDate.Confidence,
        referenceDate: Date
    ) -> Candidate {
        let matchedText = nsText.substring(with: match.range)
        let context = Self.context(before: match.range, in: nsText)
        var confidence = baseConfidence
        if Self.containsExpiryKeyword(context) {
            confidence = .high
        } else if Self.containsProductionKeyword(context) {
            // « FAB », « LOT », « EMB » : c'est une date de fabrication, pas une DLC.
            confidence = .low
        }
        return Candidate(
            date: date,
            confidence: confidence,
            matchedText: matchedText,
            isFuture: date >= calendar.startOfDay(for: referenceDate)
        )
    }

    private static func best(of candidates: [Candidate]) -> DetectedExpiryDate? {
        guard !candidates.isEmpty else { return nil }
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
            if lhs.isFuture != rhs.isFuture { return lhs.isFuture }
            // Entre deux dates d'une même étiquette, la péremption est la plus tardive.
            return lhs.date > rhs.date
        }
        guard let winner = sorted.first else { return nil }
        return DetectedExpiryDate(
            date: winner.date,
            confidence: winner.confidence,
            matchedText: winner.matchedText
        )
    }

    // MARK: - Construction de dates

    private func makeDate(day: Int, month: Int, year rawYear: Int, referenceDate: Date) -> Date? {
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }
        let year = Self.normalizeYear(rawYear)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        // Le calendrier « corrige » le 31 février en 3 mars : on refuse ce cas.
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.day == day, check.month == month, check.year == year else { return nil }
        return isPlausible(date, referenceDate: referenceDate) ? calendar.startOfDay(for: date) : nil
    }

    private func endOfMonth(month: Int, year rawYear: Int, referenceDate: Date) -> Date? {
        let year = Self.normalizeYear(rawYear)
        guard let date = calendar.lastDayOfMonth(year: year, month: month) else { return nil }
        return isPlausible(date, referenceDate: referenceDate) ? calendar.startOfDay(for: date) : nil
    }

    /// Prochaine occurrence d'un jour/mois sans année : cette année si elle n'est
    /// pas déjà loin derrière, l'an prochain sinon.
    private func nextOccurrence(day: Int, month: Int, referenceDate: Date) -> Date? {
        let currentYear = calendar.component(.year, from: referenceDate)
        for year in [currentYear, currentYear + 1] {
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = calendar.date(from: components) else { continue }
            let check = calendar.dateComponents([.month, .day], from: date)
            guard check.day == day, check.month == month else { continue }
            if calendar.wholeDaysBetween(referenceDate, and: date) >= -31 {
                return calendar.startOfDay(for: date)
            }
        }
        return nil
    }

    private func isPlausible(_ date: Date, referenceDate: Date) -> Bool {
        let days = calendar.wholeDaysBetween(referenceDate, and: date)
        return days >= -maxPastDays && days <= maxFutureDays
    }

    private static func normalizeYear(_ year: Int) -> Int {
        year < 100 ? 2000 + year : year
    }

    // MARK: - Texte

    static func normalizeForDates(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "fr_FR"))
            .uppercased()
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static let expiryKeywords = [
        "CONSOMMER", "DLC", "DLUO", "DDM", "EXP", "BBE", "BEST BEFORE", "USE BY",
        "PEREMPTION", "PERIME", "JUSQU AU", "JUSQU'AU", "VALIDITE", "A CONSOMMER",
        "TE GEBRUIKEN", "VERBRAUCHEN", "CONSUMIR",
    ]

    private static let productionKeywords = [
        "FAB", "FABRIQUE", "EMB", "PROD", "LOT", "L :", "CONDITIONNE",
    ]

    static func containsExpiryKeyword(_ text: String) -> Bool {
        expiryKeywords.contains { text.contains($0) }
    }

    static func containsProductionKeyword(_ text: String) -> Bool {
        productionKeywords.contains { text.contains($0) }
    }

    /// Fenêtre de 44 caractères précédant la date : assez pour capter
    /// « À CONSOMMER DE PRÉFÉRENCE AVANT LE », pas assez pour capter du bruit.
    private static func context(before range: NSRange, in text: NSString) -> String {
        let windowLength = 44
        let start = max(0, range.location - windowLength)
        let length = range.location - start
        guard length > 0 else { return "" }
        return text.substring(with: NSRange(location: start, length: length))
    }

    private static func isDisjoint(_ range: NSRange, from ranges: [NSRange]) -> Bool {
        !ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    // MARK: - Motifs

    private static let isoPattern = "\\b(\\d{4})[-/.](\\d{1,2})[-/.](\\d{1,2})\\b"
    private static let numericPattern = "\\b(\\d{1,2})\\s*[/.\\-]\\s*(\\d{1,2})\\s*[/.\\-]\\s*(\\d{2,4})\\b"
    private static let textualMonthPattern = "\\b(\\d{1,2})\\s+([A-Z]{3,10})\\.?\\s+(\\d{2,4})\\b"
    private static let monthYearPattern = "\\b(\\d{1,2})\\s*[/.\\-]\\s*(\\d{4})\\b"
    private static let dayMonthPattern = "\\b(\\d{1,2})\\s*[/.\\-]\\s*(\\d{1,2})\\b"

    private static let regexCache = RegexCache()

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        regexCache.regex(for: pattern)
    }

    private static let frenchMonths = [
        "JANVIER", "FEVRIER", "MARS", "AVRIL", "MAI", "JUIN",
        "JUILLET", "AOUT", "SEPTEMBRE", "OCTOBRE", "NOVEMBRE", "DECEMBRE",
    ]

    private static let englishMonths = [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER",
    ]

    static func month(fromName raw: String) -> Int? {
        let name = raw.trimmingCharacters(in: .whitespaces).uppercased()
        guard name.count >= 3 else { return nil }
        for months in [frenchMonths, englishMonths] {
            for (index, month) in months.enumerated() where month.hasPrefix(name) || name.hasPrefix(month) {
                return index + 1
            }
        }
        return nil
    }
}

// MARK: - Aides

/// Les `NSRegularExpression` sont coûteuses à construire : on les met en cache.
/// La classe est protégée par un verrou pour rester utilisable depuis n'importe
/// quel contexte de concurrence.
private final class RegexCache: @unchecked Sendable {
    private var storage: [String: NSRegularExpression] = [:]
    private let lock = NSLock()

    func regex(for pattern: String) -> NSRegularExpression? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = storage[pattern] { return cached }
        guard let created = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        storage[pattern] = created
        return created
    }
}

private extension NSString {
    func intValue(_ range: NSRange) -> Int? {
        guard range.location != NSNotFound, range.length > 0 else { return nil }
        return Int(substring(with: range).trimmingCharacters(in: .whitespaces))
    }
}
