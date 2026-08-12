import Foundation

/// Bilan d'une période — alimente la carte « Ce mois-ci » de l'écran Profil.
///
/// Toutes les valeurs monétaires sont des **estimations** et doivent être
/// présentées comme telles dans l'interface.
public struct PeriodSummary: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let savedCount: Int
    public let discardedCount: Int
    public let savedValueEUR: Double
    public let discardedValueEUR: Double

    public var totalResolved: Int { savedCount + discardedCount }

    /// Part des aliments effectivement consommés (0…1). `nil` si aucune donnée :
    /// on n'affiche pas « 0 % » à quelqu'un qui n'a encore rien fait.
    public var saveRate: Double? {
        guard totalResolved > 0 else { return nil }
        return Double(savedCount) / Double(totalResolved)
    }

    public var isEmpty: Bool { totalResolved == 0 }

    public init(
        start: Date,
        end: Date,
        savedCount: Int,
        discardedCount: Int,
        savedValueEUR: Double,
        discardedValueEUR: Double
    ) {
        self.start = start
        self.end = end
        self.savedCount = savedCount
        self.discardedCount = discardedCount
        self.savedValueEUR = savedValueEUR
        self.discardedValueEUR = discardedValueEUR
    }
}

/// Calcule les chiffres du bilan et la série sans gaspillage.
public struct InsightsEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .expira) {
        self.calendar = calendar
    }

    public func summary(events: [HistoryEvent], from start: Date, to end: Date) -> PeriodSummary {
        let lower = calendar.startOfDay(for: start)
        let upper = end
        let scoped = events.filter { $0.date >= lower && $0.date <= upper }

        let saved = scoped.filter { $0.kind == .consumed }
        let discarded = scoped.filter { $0.kind == .discarded }

        return PeriodSummary(
            start: lower,
            end: upper,
            savedCount: saved.count,
            discardedCount: discarded.count,
            savedValueEUR: round2(saved.reduce(0.0) { $0 + $1.estimatedValueEUR }),
            discardedValueEUR: round2(discarded.reduce(0.0) { $0 + $1.estimatedValueEUR })
        )
    }

    public func currentMonthSummary(events: [HistoryEvent], asOf date: Date = Date()) -> PeriodSummary {
        summary(events: events, from: calendar.startOfMonth(for: date), to: date)
    }

    /// Série de jours consécutifs sans aliment jeté, en terminant aujourd'hui.
    ///
    /// La série se construit passivement : ne rien jeter suffit. Elle démarre au
    /// premier jour d'utilisation, jamais avant — sinon le chiffre serait faux.
    public func wasteFreeStreak(
        events: [HistoryEvent],
        firstUseDate: Date,
        asOf date: Date = Date(),
        maxDays: Int = 365
    ) -> Int {
        let discardDays = Set(
            events
                .filter { $0.kind == .discarded }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let firstDay = calendar.startOfDay(for: firstUseDate)
        var streak = 0
        var cursor = calendar.startOfDay(for: date)

        while streak < maxDays, cursor >= firstDay {
            if discardDays.contains(cursor) { break }
            streak += 1
            cursor = calendar.adding(days: -1, to: cursor)
        }
        return streak
    }

    /// Nombre d'aliments sauvés depuis toujours — le chiffre le plus motivant.
    public func totalSaved(events: [HistoryEvent]) -> Int {
        events.filter { $0.kind == .consumed }.count
    }

    /// Projection annuelle à partir du rythme observé, arrondie à l'euro.
    /// Utilisée uniquement sur le paywall, avec la mention « estimation ».
    public func projectedAnnualSavingsEUR(events: [HistoryEvent], asOf date: Date = Date()) -> Double? {
        guard let earliest = events.map(\.date).min() else { return nil }
        let days = max(7, calendar.wholeDaysBetween(earliest, and: date))
        let saved = events.filter { $0.kind == .consumed }.reduce(0.0) { $0 + $1.estimatedValueEUR }
        guard saved > 0 else { return nil }
        return (saved / Double(days) * 365).rounded()
    }

    private func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

public extension Double {
    /// Formatage monétaire français, sans décimales inutiles : « 34 € », « 4,50 € ».
    var expiraEuroString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.maximumFractionDigits = self == self.rounded() ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self)) €"
    }
}
