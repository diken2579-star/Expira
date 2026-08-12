import Foundation
import ExpiraCore

/// Suivi d'entonnoir **local**.
///
/// En V1, aucun SDK tiers n'est intégré : les événements sont agrégés sur
/// l'appareil et consultables depuis les réglages (« Données envoyées : aucune »).
/// Le protocole `AnalyticsTracking` permet de brancher un fournisseur plus tard
/// sans toucher à un seul écran.
///
/// Trois garde-fous, en dur :
/// 1. Les événements « premier … » ne sont émis qu'une fois par installation.
/// 2. Les jalons J1 / J7 / J30 sont dérivés de la date de première ouverture.
/// 3. Rien n'est enregistré si l'utilisateur a désactivé la mesure d'audience.
public final class LocalFunnelTracker: AnalyticsTracking, @unchecked Sendable {
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let maxStoredEvents = 500
    private let isEnabled: @Sendable () -> Bool

    private enum Keys {
        static let log = "expira.analytics.log.v1"
        static let firedOnce = "expira.analytics.once.v1"
        static let installDate = "expira.analytics.install"
    }

    public init(defaults: UserDefaults = .standard, isEnabled: @escaping @Sendable () -> Bool = { true }) {
        self.defaults = defaults
        self.isEnabled = isEnabled
        if defaults.object(forKey: Keys.installDate) == nil {
            defaults.set(Date(), forKey: Keys.installDate)
        }
    }

    public func track(_ event: AnalyticsEvent) {
        guard isEnabled() else { return }
        lock.lock()
        defer { lock.unlock() }

        if Self.isOneShot(event.name), hasFired(event.name) {
            return
        }
        markFired(event.name)
        append(event)
    }

    /// Émet `day1_active` / `day7_active` / `day30_active` si le jalon est atteint.
    /// À appeler une fois par lancement.
    public func trackRetentionMilestones(asOf date: Date = Date(), calendar: Calendar = .expira) {
        guard let install = defaults.object(forKey: Keys.installDate) as? Date else { return }
        let days = calendar.wholeDaysBetween(install, and: date)
        for milestone in [1, 7, 30] where days >= milestone {
            track(.dayActive(milestone))
        }
    }

    /// Journal local, consultable par l'utilisateur : la transparence est un
    /// argument produit, pas une contrainte.
    public func exportLog() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedLog().map { entry in
            let parameters = entry.parameters.isEmpty
                ? ""
                : " " + entry.parameters.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            return "\(entry.timestamp.ISO8601Format()) \(entry.name)\(parameters)"
        }
    }

    public func clearLog() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: Keys.log)
    }

    // MARK: - Interne

    private struct Entry: Codable {
        let name: String
        let parameters: [String: String]
        let timestamp: Date
    }

    private static let oneShotEvents: Set<String> = [
        "app_installed", "onboarding_started", "onboarding_completed",
        "first_item_added", "day1_active", "day7_active", "day30_active",
    ]

    private static func isOneShot(_ name: String) -> Bool {
        oneShotEvents.contains(name)
    }

    private func hasFired(_ name: String) -> Bool {
        (defaults.array(forKey: Keys.firedOnce) as? [String] ?? []).contains(name)
    }

    private func markFired(_ name: String) {
        guard Self.isOneShot(name) else { return }
        var fired = defaults.array(forKey: Keys.firedOnce) as? [String] ?? []
        guard !fired.contains(name) else { return }
        fired.append(name)
        defaults.set(fired, forKey: Keys.firedOnce)
    }

    private func append(_ event: AnalyticsEvent) {
        var log = storedLog()
        log.append(Entry(name: event.name, parameters: event.parameters, timestamp: Date()))
        if log.count > maxStoredEvents {
            log.removeFirst(log.count - maxStoredEvents)
        }
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: Keys.log)
        }
    }

    private func storedLog() -> [Entry] {
        guard let data = defaults.data(forKey: Keys.log),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return decoded
    }
}

/// Écrit les événements dans la console pendant le développement.
public struct ConsoleAnalyticsTracker: AnalyticsTracking {
    public init() {}

    public func track(_ event: AnalyticsEvent) {
        #if DEBUG
        let parameters = event.parameters.isEmpty
            ? ""
            : " " + event.parameters.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("📊 \(event.name)\(parameters)")
        #endif
    }
}

/// Diffuse un même événement vers plusieurs destinations.
public struct CompositeAnalyticsTracker: AnalyticsTracking {
    private let trackers: [AnalyticsTracking]

    public init(_ trackers: [AnalyticsTracking]) {
        self.trackers = trackers
    }

    public func track(_ event: AnalyticsEvent) {
        for tracker in trackers {
            tracker.track(event)
        }
    }
}
