import Foundation
import ExpiraCore

/// Client Open Food Facts — l'unique appel réseau d'EXPIRA en V1.
///
/// Ce qui part de l'appareil : **13 chiffres**. Aucun identifiant utilisateur,
/// aucun cookie, aucune donnée personnelle. Ce qui revient : un nom, une marque,
/// une catégorie, une vignette.
///
/// La requête ne doit jamais bloquer l'utilisateur : au-delà de 6 secondes on
/// abandonne et l'app bascule sur la saisie manuelle pré-remplie.
public struct OpenFoodFactsClient: ProductLookupService, @unchecked Sendable {
    private let session: URLSession

    /// Base de l'API v2 d'Open Food Facts.
    private static let baseURLString = "https://world.openfoodfacts.org/api/v2/product/"

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 6
            configuration.timeoutIntervalForResource = 8
            configuration.waitsForConnectivity = false
            configuration.requestCachePolicy = .returnCacheDataElseLoad
            self.session = URLSession(configuration: configuration)
        }
    }

    public func lookup(barcode: String) async throws -> ProductInfo? {
        let cleaned = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.allSatisfy(\.isNumber), cleaned.count >= 6 else {
            throw ProductLookupError.invalidBarcode
        }

        guard let baseURL = URL(string: Self.baseURLString) else {
            throw ProductLookupError.serverUnavailable
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(cleaned).json"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "product_name,product_name_fr,generic_name_fr,brands,categories_tags,image_front_small_url,quantity"
            )
        ]
        guard let url = components?.url else { throw ProductLookupError.invalidBarcode }

        var request = URLRequest(url: url)
        // Open Food Facts exige un User-Agent identifiant l'application.
        request.setValue("Expira/1.0 (iOS; contact@expira.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw ProductLookupError.offline
            case .timedOut:
                throw ProductLookupError.timedOut
            default:
                throw ProductLookupError.serverUnavailable
            }
        }

        guard let http = response as? HTTPURLResponse else { throw ProductLookupError.serverUnavailable }
        // 404 = produit absent de la base : ce n'est pas une erreur, c'est un cas nominal.
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw ProductLookupError.serverUnavailable }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let product = payload.product
        else { return nil }

        let name = [product.productNameFR, product.productName, product.genericNameFR]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        guard let resolvedName = name else { return nil }

        let brand = product.brands?
            .split(separator: ",")
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return ProductInfo(
            barcode: cleaned,
            name: resolvedName,
            brand: (brand?.isEmpty == false) ? brand : nil,
            category: CategoryClassifier.classify(name: resolvedName, offTags: product.categoriesTags ?? []),
            imageURLString: product.imageFrontSmallURL,
            quantityText: product.quantity,
            isLocal: false
        )
    }

    // MARK: - Décodage

    private struct Payload: Decodable {
        let product: Product?
    }

    private struct Product: Decodable {
        let productName: String?
        let productNameFR: String?
        let genericNameFR: String?
        let brands: String?
        let categoriesTags: [String]?
        let imageFrontSmallURL: String?
        let quantity: String?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case productNameFR = "product_name_fr"
            case genericNameFR = "generic_name_fr"
            case brands
            case categoriesTags = "categories_tags"
            case imageFrontSmallURL = "image_front_small_url"
            case quantity
        }
    }
}
