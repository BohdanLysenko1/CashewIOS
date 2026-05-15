import Foundation
import os
import Supabase

enum SupabaseManager {

    static let projectURL: URL = {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "<missing>"
        Log.config.error("SUPABASE_URL raw value from Info.plist: \(rawValue, privacy: .public)")
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL not set in Info.plist — see Secrets.xcconfig.example")
        }
        Log.config.error("SUPABASE_URL parsed → host=\(url.host ?? "<nil>", privacy: .public) scheme=\(url.scheme ?? "<nil>", privacy: .public) full=\(url.absoluteString, privacy: .public)")
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY not set in Info.plist — see Secrets.xcconfig.example")
        }
        let prefix = String(key.prefix(12))
        Log.config.error("SUPABASE_ANON_KEY prefix=\(prefix, privacy: .public) length=\(key.count, privacy: .public)")
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
