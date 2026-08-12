import Foundation

public extension Calendar {
    /// Calendrier de référence de l'app : grégorien, semaine commençant le lundi.
    /// Toutes les comparaisons de dates passent par lui pour éviter les écarts
    /// entre appareils.
    static var expira: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    /// Nombre de jours **calendaires** entre deux instants.
    ///
    /// On compare des débuts de journée, jamais des instants : « expire demain »
    /// doit rester vrai à 23 h 58 comme à 00 h 02.
    func wholeDaysBetween(_ from: Date, and to: Date) -> Int {
        let start = startOfDay(for: from)
        let end = startOfDay(for: to)
        return dateComponents([.day], from: start, to: end).day ?? 0
    }

    func adding(days: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Fixe une date au début de journée, puis lui applique une heure précise.
    /// Utilisé pour planifier le digest quotidien.
    func date(_ date: Date, atHour hour: Int, minute: Int = 0) -> Date {
        self.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    /// Dernier jour du mois donné — utile quand une étiquette ne porte que
    /// « 03/2026 » : la date de péremption est alors la fin du mois.
    func lastDayOfMonth(year: Int, month: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let first = self.date(from: components),
              let range = range(of: .day, in: .month, for: first)
        else { return nil }
        components.day = range.count
        return self.date(from: components)
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

public extension Date {
    /// Rendu court et lisible : « mar. 12 mars ».
    func expiraShortDateString(calendar: Calendar = .expira) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return formatter.string(from: self)
    }

    /// Rendu long : « 12 mars 2026 ».
    func expiraLongDateString(calendar: Calendar = .expira) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}
