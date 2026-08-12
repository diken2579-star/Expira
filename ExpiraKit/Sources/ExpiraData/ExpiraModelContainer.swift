import Foundation
import SwiftData

/// Construction du conteneur SwiftData.
///
/// Règle absolue : **l'app ne plante jamais au lancement**. Si le fichier de
/// base est corrompu ou illisible, on retombe sur un conteneur en mémoire pour
/// que l'utilisateur puisse au moins ouvrir l'app — et on le lui signale.
public enum ExpiraModelContainer {
    public static let schema = Schema([
        StoredFoodItem.self,
        StoredHistoryEvent.self,
    ])

    public struct Result {
        public let container: ModelContainer
        /// `true` quand on a dû basculer en mémoire : les données ne seront pas
        /// conservées et l'interface doit prévenir l'utilisateur.
        public let isFallback: Bool
    }

    public static func make(inMemory: Bool = false) -> Result {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return Result(container: container, isFallback: inMemory)
        }

        // Second essai, en mémoire : mieux vaut une app utilisable sans
        // persistance qu'un écran noir.
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [memoryConfiguration]) {
            return Result(container: container, isFallback: true)
        }

        // Ce cas ne devrait jamais se produire : le schéma est statique et validé
        // à la compilation. On préfère malgré tout un arrêt explicite ici plutôt
        // qu'un état incohérent qui produirait des bugs impossibles à diagnostiquer.
        fatalError("ExpiraModelContainer: impossible de créer un conteneur, même en mémoire.")
    }
}
