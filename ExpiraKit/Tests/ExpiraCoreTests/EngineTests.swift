import XCTest
@testable import ExpiraCore
import ExpiraCatalog

// MARK: - Aides

enum TestFixtures {
    static let calendar = Calendar.expira

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date()
    }

    static func item(
        _ name: String,
        category: FoodCategory = .other,
        expiresIn days: Int,
        from reference: Date,
        value: Double = 3,
        status: ItemStatus = .active
    ) -> FoodItem {
        FoodItem(
            name: name,
            category: category,
            expiryDate: calendar.adding(days: days, to: reference),
            estimatedValueEUR: value,
            status: status
        )
    }
}

// MARK: - Urgence

final class UrgencyTests: XCTestCase {
    private let now = TestFixtures.date(2026, 3, 10)

    func testUrgencyBuckets() {
        XCTAssertEqual(TestFixtures.item("a", expiresIn: -1, from: now).urgency(asOf: now), .expired)
        XCTAssertEqual(TestFixtures.item("b", expiresIn: 0, from: now).urgency(asOf: now), .today)
        XCTAssertEqual(TestFixtures.item("c", expiresIn: 1, from: now).urgency(asOf: now), .tomorrow)
        XCTAssertEqual(TestFixtures.item("d", expiresIn: 5, from: now).urgency(asOf: now), .thisWeek)
        XCTAssertEqual(TestFixtures.item("e", expiresIn: 20, from: now).urgency(asOf: now), .later)
    }

    func testUrgencyIgnoresTimeOfDay() {
        // « Expire demain » doit rester vrai à 23 h 58 comme à 00 h 02.
        let lateEvening = TestFixtures.calendar.date(now, atHour: 23, minute: 58)
        let item = TestFixtures.item("Lait", expiresIn: 1, from: now)
        XCTAssertEqual(item.urgency(asOf: lateEvening), .tomorrow)
    }

    func testBadgeLabelsAreHumanReadable() {
        XCTAssertEqual(UrgencyLevel.badgeLabel(daysRemaining: 0), "Aujourd'hui")
        XCTAssertEqual(UrgencyLevel.badgeLabel(daysRemaining: 1), "Demain")
        XCTAssertEqual(UrgencyLevel.badgeLabel(daysRemaining: 3), "Dans 3 jours")
        XCTAssertEqual(UrgencyLevel.badgeLabel(daysRemaining: -1), "Périmé depuis hier")
        XCTAssertEqual(UrgencyLevel.badgeLabel(daysRemaining: -3), "Périmé depuis 3 jours")
    }

    func testAttentionCoversExpiredTodayAndTomorrowOnly() {
        XCTAssertTrue(UrgencyLevel.expired.requiresAttention)
        XCTAssertTrue(UrgencyLevel.today.requiresAttention)
        XCTAssertTrue(UrgencyLevel.tomorrow.requiresAttention)
        XCTAssertFalse(UrgencyLevel.thisWeek.requiresAttention)
        XCTAssertFalse(UrgencyLevel.later.requiresAttention)
    }
}

// MARK: - Estimation de péremption

final class ExpiryEstimatorTests: XCTestCase {
    private let estimator = ExpiryEstimator(provider: ShelfLifeCatalog())
    private let now = TestFixtures.date(2026, 3, 10)

    func testPoultryInFridgeIsVeryShort() {
        let expiry = estimator.estimatedExpiry(category: .poultry, storage: .fridge, from: now)
        XCTAssertEqual(TestFixtures.calendar.wholeDaysBetween(now, and: expiry), 2)
    }

    func testFreezerExtendsShelfLifeDramatically() {
        let fridge = estimator.estimatedExpiry(category: .poultry, storage: .fridge, from: now)
        let freezer = estimator.estimatedExpiry(category: .poultry, storage: .freezer, from: now)
        XCTAssertGreaterThan(freezer, fridge)
    }

    func testOpenedProductsExpireSooner() {
        let sealed = estimator.estimatedExpiry(category: .dairy, storage: .fridge, isOpened: false, from: now)
        let opened = estimator.estimatedExpiry(category: .dairy, storage: .fridge, isOpened: true, from: now)
        XCTAssertLessThan(opened, sealed)
    }

    func testEveryCategoryHasAPositiveShelfLifeEverywhere() {
        let catalog = ShelfLifeCatalog()
        for category in FoodCategory.allCases {
            for storage in StorageLocation.allCases {
                let rule = catalog.rule(for: category, storage: storage)
                XCTAssertGreaterThan(rule.days, 0, "\(category)/\(storage) doit avoir une durée positive")
                XCTAssertLessThanOrEqual(
                    rule.daysWhenOpened,
                    rule.days,
                    "\(category)/\(storage) : un produit entamé ne peut pas durer plus longtemps"
                )
            }
        }
    }

    func testDefaultStoragesAreSensible() {
        let catalog = ShelfLifeCatalog()
        XCTAssertEqual(catalog.defaultStorage(for: .poultry), .fridge)
        XCTAssertEqual(catalog.defaultStorage(for: .bakery), .counter)
        XCTAssertEqual(catalog.defaultStorage(for: .frozen), .freezer)
        XCTAssertEqual(catalog.defaultStorage(for: .pantry), .pantry)
    }
}

// MARK: - Moteur de recettes

final class RecipeMatcherTests: XCTestCase {
    private let matcher = RecipeMatcher()
    private let now = TestFixtures.date(2026, 3, 10)

    func testMatchesRecipeFromStockNames() {
        let items = [
            TestFixtures.item("Blanc de poulet fermier", category: .poultry, expiresIn: 1, from: now),
            TestFixtures.item("Riz basmati", category: .pantry, expiresIn: 200, from: now),
            TestFixtures.item("Carottes bio", category: .vegetables, expiresIn: 4, from: now),
        ]
        let matches = matcher.matches(recipes: RecipeCatalog.all, items: items, asOf: now, limit: 3)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(
            matches.contains { $0.recipe.id == "riz-saute-poulet" },
            "Poulet + riz + carottes doit proposer le riz sauté au poulet"
        )
    }

    func testPrioritisesRecipesThatSaveTheMostUrgentItems() {
        let items = [
            TestFixtures.item("Courgettes", category: .vegetables, expiresIn: 0, from: now),
            TestFixtures.item("Crème fraîche", category: .dairy, expiresIn: 0, from: now),
            TestFixtures.item("Fromage râpé", category: .cheese, expiresIn: 1, from: now),
            TestFixtures.item("Pommes", category: .fruits, expiresIn: 25, from: now),
        ]
        let matches = matcher.matches(recipes: RecipeCatalog.all, items: items, asOf: now, limit: 3)
        let top = try? XCTUnwrap(matches.first)
        XCTAssertEqual(top?.recipe.id, "gratin-courgettes")
        XCTAssertGreaterThanOrEqual(top?.savedItemCount ?? 0, 3)
    }

    func testNeverSuggestsRecipeUsingNothingFromTheFridge() {
        let items = [TestFixtures.item("Papier toilette", category: .other, expiresIn: 300, from: now)]
        XCTAssertTrue(matcher.matches(recipes: RecipeCatalog.all, items: items, asOf: now).isEmpty)
    }

    func testIgnoresResolvedItems() {
        let items = [
            TestFixtures.item("Poulet", category: .poultry, expiresIn: 1, from: now, status: .consumed),
            TestFixtures.item("Riz", category: .pantry, expiresIn: 100, from: now, status: .consumed),
        ]
        XCTAssertTrue(matcher.matches(recipes: RecipeCatalog.all, items: items, asOf: now).isEmpty)
    }

    func testAnItemIsNeverCountedTwiceInTheSameRecipe() {
        let items = [TestFixtures.item("Courgettes", category: .vegetables, expiresIn: 1, from: now)]
        for match in matcher.matches(recipes: RecipeCatalog.all, items: items, asOf: now, limit: 10) {
            let ids = match.matchedItems.map(\.id)
            XCTAssertEqual(ids.count, Set(ids).count, "\(match.recipe.id) réutilise le même aliment")
        }
    }

    func testStaplesAreNeverListedAsMissing() {
        let items = [
            TestFixtures.item("Œufs", category: .eggs, expiresIn: 2, from: now),
            TestFixtures.item("Courgette", category: .vegetables, expiresIn: 1, from: now),
        ]
        let matches = matcher.matches(recipes: RecipeCatalog.all, items: items, asOf: now, limit: 10)
        for match in matches {
            XCTAssertFalse(
                match.missingIngredients.contains { $0.isStaple },
                "Le sel et l'huile ne doivent jamais apparaître comme manquants"
            )
        }
    }
}

// MARK: - Plan de sauvetage

final class RescuePlannerTests: XCTestCase {
    private let planner = RescuePlanner()
    private let now = TestFixtures.date(2026, 3, 10)

    func testEmptyPlanWhenNothingIsAtRisk() {
        let items = [TestFixtures.item("Conserve de thon", category: .pantry, expiresIn: 300, from: now)]
        let plan = planner.makePlan(items: items, recipes: RecipeCatalog.all, asOf: now)
        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(plan.totalItemsSaved, 0)
    }

    func testPlanSpansSeveralDaysAndNeverRepeatsARecipe() {
        let items = [
            TestFixtures.item("Poulet", category: .poultry, expiresIn: 0, from: now),
            TestFixtures.item("Riz", category: .pantry, expiresIn: 5, from: now),
            TestFixtures.item("Courgettes", category: .vegetables, expiresIn: 1, from: now),
            TestFixtures.item("Crème fraîche", category: .dairy, expiresIn: 2, from: now),
            TestFixtures.item("Fromage râpé", category: .cheese, expiresIn: 3, from: now),
            TestFixtures.item("Pain", category: .bakery, expiresIn: 1, from: now),
            TestFixtures.item("Œufs", category: .eggs, expiresIn: 4, from: now),
            TestFixtures.item("Lait", category: .dairy, expiresIn: 2, from: now),
        ]
        let plan = planner.makePlan(items: items, recipes: RecipeCatalog.all, asOf: now, dayCount: 3)

        XCTAssertFalse(plan.isEmpty)
        XCTAssertLessThanOrEqual(plan.days.count, 3)

        let recipeIDs = plan.days.compactMap { $0.recipe?.id }
        XCTAssertEqual(recipeIDs.count, Set(recipeIDs).count, "Le plan ne doit jamais proposer deux fois la même recette")
    }

    func testAnItemAppearsOnlyOnceInTheWholePlan() {
        let items = [
            TestFixtures.item("Poulet", category: .poultry, expiresIn: 0, from: now),
            TestFixtures.item("Riz", category: .pantry, expiresIn: 5, from: now),
            TestFixtures.item("Courgettes", category: .vegetables, expiresIn: 1, from: now),
            TestFixtures.item("Crème fraîche", category: .dairy, expiresIn: 2, from: now),
            TestFixtures.item("Œufs", category: .eggs, expiresIn: 2, from: now),
            TestFixtures.item("Fromage", category: .cheese, expiresIn: 3, from: now),
        ]
        let plan = planner.makePlan(items: items, recipes: RecipeCatalog.all, asOf: now, dayCount: 3)
        let allIDs = plan.days.flatMap { $0.items.map(\.id) }
        XCTAssertEqual(allIDs.count, Set(allIDs).count, "Un aliment ne peut pas être sauvé deux fois")
    }

    func testFallsBackToDirectConsumptionWhenNoRecipeFits() {
        let items = [
            TestFixtures.item("Yaourt nature", category: .dairy, expiresIn: 0, from: now),
            TestFixtures.item("Compote en gourde", category: .fruits, expiresIn: 1, from: now),
        ]
        let plan = planner.makePlan(items: items, recipes: [], asOf: now, dayCount: 3)
        XCTAssertFalse(plan.isEmpty, "Sans recette applicable, le plan doit quand même proposer une action")
        XCTAssertNil(plan.days.first?.recipe)
        XCTAssertFalse(plan.days.first?.items.isEmpty ?? true)
    }

    func testEstimatedSavingsSumsTheItemsInThePlan() {
        let items = [
            TestFixtures.item("Poulet", category: .poultry, expiresIn: 0, from: now, value: 6),
            TestFixtures.item("Riz", category: .pantry, expiresIn: 4, from: now, value: 2),
        ]
        let plan = planner.makePlan(items: items, recipes: RecipeCatalog.all, asOf: now)
        let expected = plan.days.flatMap(\.items).reduce(0.0) { $0 + $1.estimatedValueEUR }
        XCTAssertEqual(plan.estimatedSavingsEUR, expected, accuracy: 0.01)
    }
}

// MARK: - Bilan et série

final class InsightsEngineTests: XCTestCase {
    private let engine = InsightsEngine()
    private let now = TestFixtures.date(2026, 3, 10)

    private func event(_ kind: HistoryEvent.Kind, daysAgo: Int, value: Double = 3) -> HistoryEvent {
        HistoryEvent(
            itemID: UUID(),
            itemName: "Test",
            category: .other,
            kind: kind,
            date: TestFixtures.calendar.adding(days: -daysAgo, to: now),
            estimatedValueEUR: value,
            daysBeforeExpiry: 1
        )
    }

    func testMonthlySummaryCountsAndValues() {
        let events = [
            event(.consumed, daysAgo: 1, value: 4),
            event(.consumed, daysAgo: 3, value: 6),
            event(.discarded, daysAgo: 2, value: 5),
        ]
        let summary = engine.currentMonthSummary(events: events, asOf: now)
        XCTAssertEqual(summary.savedCount, 2)
        XCTAssertEqual(summary.discardedCount, 1)
        XCTAssertEqual(summary.savedValueEUR, 10, accuracy: 0.01)
        XCTAssertEqual(summary.discardedValueEUR, 5, accuracy: 0.01)
    }

    func testSummaryExcludesEventsOutsideThePeriod() {
        let events = [event(.consumed, daysAgo: 45)]
        let summary = engine.currentMonthSummary(events: events, asOf: now)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertNil(summary.saveRate, "Sans donnée, on n'affiche pas 0 %")
    }

    func testStreakCountsDaysWithoutDiscard() {
        let firstUse = TestFixtures.calendar.adding(days: -30, to: now)
        let events = [event(.consumed, daysAgo: 1), event(.consumed, daysAgo: 2)]
        XCTAssertEqual(engine.wasteFreeStreak(events: events, firstUseDate: firstUse, asOf: now), 31)
    }

    func testStreakBreaksOnDiscard() {
        let firstUse = TestFixtures.calendar.adding(days: -30, to: now)
        let events = [event(.discarded, daysAgo: 3)]
        XCTAssertEqual(engine.wasteFreeStreak(events: events, firstUseDate: firstUse, asOf: now), 3)
    }

    func testStreakNeverPredatesFirstUse() {
        let firstUse = TestFixtures.calendar.adding(days: -2, to: now)
        XCTAssertEqual(
            engine.wasteFreeStreak(events: [], firstUseDate: firstUse, asOf: now), 3,
            "La série ne peut pas commencer avant la première utilisation"
        )
    }

    func testEuroFormattingDropsUselessDecimals() {
        XCTAssertFalse(34.0.expiraEuroString.contains(","))
        XCTAssertTrue(4.5.expiraEuroString.contains("4,5"))
    }
}

// MARK: - Notifications

final class NotificationPlannerTests: XCTestCase {
    private let planner = NotificationPlanner()
    private let now = TestFixtures.date(2026, 3, 10)

    private var preferences: NotificationPreferences {
        NotificationPreferences(isEnabled: true, digestHour: 9, alertThresholdDays: 2, weeklySummaryEnabled: false)
    }

    func testNoNotificationWhenNothingIsUrgent() {
        let items = [TestFixtures.item("Conserve", category: .pantry, expiresIn: 300, from: now)]
        XCTAssertTrue(
            planner.plan(items: items, preferences: preferences, asOf: now).isEmpty,
            "Une app qui alerte dans le vide se fait désinstaller"
        )
    }

    func testNoNotificationWhenFridgeIsEmpty() {
        XCTAssertTrue(planner.plan(items: [], preferences: preferences, asOf: now).isEmpty)
    }

    func testDisabledPreferencesProduceNothing() {
        let items = [TestFixtures.item("Poulet", category: .poultry, expiresIn: 0, from: now)]
        var disabled = preferences
        disabled.isEnabled = false
        XCTAssertTrue(planner.plan(items: items, preferences: disabled, asOf: now).isEmpty)
    }

    func testAtMostOneDigestPerDay() {
        let items = (0..<10).map {
            TestFixtures.item("Aliment \($0)", category: .vegetables, expiresIn: $0 % 5, from: now)
        }
        let planned = planner.plan(items: items, preferences: preferences, asOf: now, horizonDays: 7)
        let days = planned.map { TestFixtures.calendar.startOfDay(for: $0.fireDate) }
        XCTAssertEqual(days.count, Set(days).count, "Plafond dur : une notification par jour")
    }

    func testNothingIsScheduledInThePast() {
        let items = [TestFixtures.item("Lait", category: .dairy, expiresIn: 1, from: now)]
        let evening = TestFixtures.calendar.date(now, atHour: 22)
        for notification in planner.plan(items: items, preferences: preferences, asOf: evening) {
            XCTAssertGreaterThan(notification.fireDate, evening)
        }
    }

    func testSingleItemDigestNamesTheItem() throws {
        let items = [TestFixtures.item("Fraises", category: .fruits, expiresIn: 1, from: now)]
        let planned = planner.plan(items: items, preferences: preferences, asOf: now)
        let first = try XCTUnwrap(planned.first)
        XCTAssertTrue(first.title.contains("Fraises"), "Une notification doit être concrète et nommée")
    }

    func testStaleItemsStopGeneratingNoise() {
        let items = [TestFixtures.item("Salade oubliée", category: .vegetables, expiresIn: -10, from: now)]
        XCTAssertTrue(
            planner.plan(items: items, preferences: preferences, asOf: now).isEmpty,
            "Un aliment périmé depuis 10 jours relève du nettoyage, pas de l'alerte"
        )
    }
}

// MARK: - Limites de la version gratuite

final class EntitlementTests: XCTestCase {
    func testFreeTierIsGenerousEnoughToBeUseful() {
        XCTAssertGreaterThanOrEqual(
            FreeTierLimits.maxActiveItems, 10,
            "Une version gratuite inutilisable ne convertit personne"
        )
    }

    func testEveryPaywallTriggerHasCopy() {
        for trigger in PaywallTrigger.allCases {
            XCTAssertFalse(trigger.headline.isEmpty)
            XCTAssertFalse(trigger.subheadline.isEmpty)
        }
    }

    func testEveryPremiumFeatureIsExplained() {
        for feature in PremiumFeature.allCases {
            XCTAssertFalse(feature.displayName.isEmpty)
            XCTAssertFalse(feature.explanation.isEmpty)
        }
    }
}

// MARK: - Classement de catégories

final class CategoryClassifierTests: XCTestCase {
    func testClassifiesFromProductName() {
        XCTAssertEqual(CategoryClassifier.classify(name: "Blanc de poulet"), .poultry)
        XCTAssertEqual(CategoryClassifier.classify(name: "Camembert de Normandie"), .cheese)
        XCTAssertEqual(CategoryClassifier.classify(name: "Baguette tradition"), .bakery)
        XCTAssertEqual(CategoryClassifier.classify(name: "Tomates grappe"), .vegetables)
    }

    func testCoconutMilkIsNotADairyProduct() {
        XCTAssertEqual(
            CategoryClassifier.classify(name: "Lait de coco bio"), .pantry,
            "Une catégorie fausse produit une date estimée fausse"
        )
    }

    func testOpenFoodFactsTagsWinOverTheName() {
        XCTAssertEqual(
            CategoryClassifier.classify(name: "Skyr vanille", offTags: ["en:dairies", "en:yogurts"]),
            .dairy
        )
    }

    func testUnknownProductFallsBackToOtherRatherThanGuessing() {
        XCTAssertEqual(CategoryClassifier.classify(name: "Zzzyx 3000"), .other)
    }
}
