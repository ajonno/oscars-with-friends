import Foundation
import StoreKit

@Observable
class StoreService {
    static let shared = StoreService()

    // Product ID - must match what you set up in App Store Connect
    static let competitionsProductId = "com.awardswithfriends.competitions"

    private(set) var products: [Product] = []
    private(set) var purchasedProductIds: Set<String> = []
    private(set) var isLoading = false

    var hasCompetitionsAccess: Bool {
        purchasedProductIds.contains(Self.competitionsProductId)
    }

    var competitionsProduct: Product? {
        products.first { $0.id == Self.competitionsProductId }
    }

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    @MainActor
    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: [Self.competitionsProductId])
        } catch {
            print("Failed to load products: \(error)")
        }
        isLoading = false
    }

    @MainActor
    func purchase() async throws -> Bool {
        guard let product = competitionsProduct else {
            throw StoreError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    @MainActor
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }

    @MainActor
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchased.insert(transaction.productID)
            }
        }

        purchasedProductIds = purchased
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: LocalizedError {
    case productNotFound
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "Product not found"
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}
