import Foundation
import FirebaseFunctions

final class CloudFunctionsService {
    static let shared = CloudFunctionsService()

    private let functions: Functions

    private init() {
        functions = Functions.functions(region: "asia-south1")
    }

    // MARK: - Competition Management

    struct CreateCompetitionResponse: Decodable {
        let success: Bool
        let competitionId: String
        let inviteCode: String
    }

    func createCompetition(name: String, ceremonyYear: String, event: String) async throws -> CreateCompetitionResponse {
        let callable = functions.httpsCallable("createCompetition")
        let result = try await callable.call([
            "name": name,
            "ceremonyYear": ceremonyYear,
            "event": event
        ])

        guard let data = result.data as? [String: Any] else {
            throw CloudFunctionError.invalidResponse
        }

        return CreateCompetitionResponse(
            success: data["success"] as? Bool ?? false,
            competitionId: data["competitionId"] as? String ?? "",
            inviteCode: data["inviteCode"] as? String ?? ""
        )
    }

    struct JoinCompetitionResponse: Decodable {
        let success: Bool
        let competitionId: String
        let competitionName: String
    }

    func joinCompetition(code: String) async throws -> JoinCompetitionResponse {
        let callable = functions.httpsCallable("joinCompetition")
        let result = try await callable.call(["code": code.uppercased()])

        guard let data = result.data as? [String: Any] else {
            throw CloudFunctionError.invalidResponse
        }

        if let success = data["success"] as? Bool, !success {
            throw CloudFunctionError.operationFailed(data["message"] as? String ?? "Failed to join competition")
        }

        return JoinCompetitionResponse(
            success: data["success"] as? Bool ?? false,
            competitionId: data["competitionId"] as? String ?? "",
            competitionName: data["competitionName"] as? String ?? ""
        )
    }

    func leaveCompetition(competitionId: String) async throws {
        let callable = functions.httpsCallable("leaveCompetition")
        let result = try await callable.call(["competitionId": competitionId])

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool, success else {
            throw CloudFunctionError.operationFailed("Failed to leave competition")
        }
    }

    struct SetCompetitionInactiveResponse: Decodable {
        let success: Bool
        let status: String
    }

    func setCompetitionInactive(competitionId: String, inactive: Bool) async throws -> SetCompetitionInactiveResponse {
        let callable = functions.httpsCallable("setCompetitionInactive")
        let result = try await callable.call([
            "competitionId": competitionId,
            "inactive": inactive
        ])

        guard let data = result.data as? [String: Any] else {
            throw CloudFunctionError.invalidResponse
        }

        if let success = data["success"] as? Bool, !success {
            throw CloudFunctionError.operationFailed(data["message"] as? String ?? "Failed to update competition")
        }

        return SetCompetitionInactiveResponse(
            success: data["success"] as? Bool ?? false,
            status: data["status"] as? String ?? ""
        )
    }

    // MARK: - Voting

    struct CastVoteResponse: Decodable {
        let success: Bool
        let isUpdate: Bool
        let categoryName: String
        let nomineeName: String
    }

    func castVote(competitionId: String, categoryId: String, nomineeId: String) async throws -> CastVoteResponse {
        let callable = functions.httpsCallable("castVote")
        let result = try await callable.call([
            "competitionId": competitionId,
            "categoryId": categoryId,
            "nomineeId": nomineeId
        ])

        guard let data = result.data as? [String: Any] else {
            throw CloudFunctionError.invalidResponse
        }

        if let success = data["success"] as? Bool, !success {
            throw CloudFunctionError.operationFailed(data["message"] as? String ?? "Failed to cast vote")
        }

        return CastVoteResponse(
            success: data["success"] as? Bool ?? false,
            isUpdate: data["isUpdate"] as? Bool ?? false,
            categoryName: data["categoryName"] as? String ?? "",
            nomineeName: data["nomineeName"] as? String ?? ""
        )
    }

    // MARK: - Ceremony Voting

    struct CastCeremonyVoteResponse: Decodable {
        let success: Bool
        let categoryName: String
        let nomineeName: String
        let competitionsUpdated: Int
    }

    func castCeremonyVote(ceremonyYear: String, categoryId: String, nomineeId: String) async throws -> CastCeremonyVoteResponse {
        let callable = functions.httpsCallable("castCeremonyVote")
        let result = try await callable.call([
            "ceremonyYear": ceremonyYear,
            "categoryId": categoryId,
            "nomineeId": nomineeId
        ])

        guard let data = result.data as? [String: Any] else {
            throw CloudFunctionError.invalidResponse
        }

        if let success = data["success"] as? Bool, !success {
            throw CloudFunctionError.operationFailed(data["message"] as? String ?? "Failed to cast vote")
        }

        return CastCeremonyVoteResponse(
            success: data["success"] as? Bool ?? false,
            categoryName: data["categoryName"] as? String ?? "",
            nomineeName: data["nomineeName"] as? String ?? "",
            competitionsUpdated: data["competitionsUpdated"] as? Int ?? 0
        )
    }

    // MARK: - FCM Token

    func updateFcmToken(_ token: String) async throws {
        let callable = functions.httpsCallable("updateFcmToken")
        _ = try await callable.call(["token": token])
    }

    // MARK: - Account Management

    func deleteAccount() async throws {
        let callable = functions.httpsCallable("deleteAccount")
        let result = try await callable.call()

        guard let data = result.data as? [String: Any],
              let success = data["success"] as? Bool, success else {
            throw CloudFunctionError.operationFailed("Failed to delete account data")
        }
    }
}

// MARK: - Errors

enum CloudFunctionError: LocalizedError {
    case invalidResponse
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .operationFailed(let message):
            return message
        }
    }
}
