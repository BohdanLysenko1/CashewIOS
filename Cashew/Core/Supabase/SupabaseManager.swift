import Foundation
import Supabase

enum SupabaseManager {

    static let projectURL: URL = {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not set in Info.plist — see Secrets.xcconfig.example")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not set in Info.plist — see Secrets.xcconfig.example")
        }
        return key
    }()

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
