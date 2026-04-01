import Foundation

enum ShareLinkCodec {

    static let scheme = "cashew"
    static let inviteHost = "join"

    static func makeInviteURL(token: String) throws -> URL {
        let pathAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard
            let encodedToken = token.addingPercentEncoding(withAllowedCharacters: pathAllowed),
            let url = URL(string: "\(scheme)://\(inviteHost)/\(encodedToken)")
        else {
            throw ShareError.invalidToken
        }
        return url
    }

    static func parseInviteToken(from url: URL) -> String? {
        guard url.scheme == scheme, url.host == inviteHost else { return nil }
        guard let rawToken = url.pathComponents.dropFirst().first else { return nil }
        let token = rawToken.removingPercentEncoding ?? rawToken
        return token.isEmpty ? nil : token
    }
}
