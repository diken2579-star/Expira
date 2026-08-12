// swift-tools-version: 5.9
import PackageDescription

// ExpiraKit — noyau modulaire de l'application EXPIRA.
//
// Règle de dépendance : tout dépend de `ExpiraCore`, `ExpiraCore` ne dépend de rien
// d'autre que Foundation. Les moteurs métier (urgence, estimation, recettes, plan
// de sauvetage, économies) sont des fonctions pures, testables sans simulateur.
let package = Package(
    name: "ExpiraKit",
    defaultLocalization: "fr",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ExpiraCore", targets: ["ExpiraCore"]),
        .library(name: "ExpiraDesignSystem", targets: ["ExpiraDesignSystem"]),
        .library(name: "ExpiraCatalog", targets: ["ExpiraCatalog"]),
        .library(name: "ExpiraData", targets: ["ExpiraData"]),
        .library(name: "ExpiraScanning", targets: ["ExpiraScanning"]),
        .library(name: "ExpiraNotifications", targets: ["ExpiraNotifications"]),
        .library(name: "ExpiraCommerce", targets: ["ExpiraCommerce"]),
        .library(name: "ExpiraAnalytics", targets: ["ExpiraAnalytics"]),
    ],
    targets: [
        .target(name: "ExpiraCore"),
        .target(name: "ExpiraDesignSystem", dependencies: ["ExpiraCore"]),
        .target(name: "ExpiraCatalog", dependencies: ["ExpiraCore"]),
        .target(name: "ExpiraData", dependencies: ["ExpiraCore"]),
        .target(name: "ExpiraScanning", dependencies: ["ExpiraCore"]),
        .target(name: "ExpiraNotifications", dependencies: ["ExpiraCore"]),
        .target(name: "ExpiraCommerce", dependencies: ["ExpiraCore"]),
        .target(name: "ExpiraAnalytics", dependencies: ["ExpiraCore"]),
        .testTarget(
            name: "ExpiraCoreTests",
            dependencies: ["ExpiraCore", "ExpiraCatalog"]
        ),
    ]
)
