import Foundation
import Supabase

/// Shared invocation helper for Supabase Edge Functions used by AI services.
///
/// Centralizes the `FunctionsError.httpError` body unwrapping so each AI service
/// only declares its function name and how to map errors into its own typed error.
enum AIServiceClient {

    /// Invokes a Supabase edge function with `body`, decoding the response as `Res`.
    /// - Parameters:
    ///   - functionName: name of the deployed edge function (e.g. `"generate-itinerary"`).
    ///   - body: encodable request payload.
    ///   - functionError: builds the service's typed error from a server-side message.
    ///   - decodingFailure: builds the service's typed error from a decoding/transport error.
    static func invoke<Req: Encodable, Res: Decodable>(
        _ functionName: String,
        body: Req,
        functionError: (String) -> Error,
        decodingFailure: (Error) -> Error
    ) async throws -> Res {
        do {
            let response: Res = try await SupabaseManager.client.functions.invoke(
                functionName,
                options: .init(body: body)
            )
            return response
        } catch let fnError as FunctionsError {
            if case .httpError(_, let body) = fnError,
               let envelope = try? JSONDecoder().decode([String: String].self, from: body),
               let message = envelope["error"] {
                throw functionError(message)
            }
            throw functionError(fnError.localizedDescription)
        } catch {
            throw decodingFailure(error)
        }
    }
}
