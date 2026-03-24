import Foundation
import Supabase

enum SupabaseManager {

    static let projectURL = URL(string: "https://sjmeicdvnzismnmvjnro.supabase.co")!
    static let anonKey = "sb_publishable_XOp-tQduFHrUwH9eK7hJqQ_PDadlmAL"

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey,
        options: .init(
            auth: .init(
                storage: KeychainLocalStorage(service: "com.bohdanlysenko.Cashew", accessGroup: nil),
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}
