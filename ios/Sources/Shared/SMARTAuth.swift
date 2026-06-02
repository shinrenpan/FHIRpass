import CryptoKit
import Foundation
import Security

// MARK: - SMART on FHIR Well-Known Config

struct SMARTConfig: Codable, Sendable {
  let authorization_endpoint: String
  let token_endpoint: String

  static func fetch(from wellKnownURL: URL) async throws -> SMARTConfig {
    let (data, response) = try await URLSession.shared.data(from: wellKnownURL)
    guard let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode) else {
      throw APIError.message("SMART 設定端點無法存取")
    }
    return try JSONDecoder().decode(SMARTConfig.self, from: data)
  }
}

// MARK: - SMART Token Response

struct SMARTTokenResponse: Codable, Sendable {
  let access_token: String
  let token_type: String?
  let expires_in: Int?
  let scope: String?
  let patient: String?
}

// MARK: - PKCE + Auth Helpers

enum SMARTAuth {
  static let clientID    = "fhirpass"
  static let redirectURI = "fhirpass://callback"
  static let scope       = "openid profile launch/patient patient/*.read patient/*.write offline_access"

  static func generatePKCE() -> (verifier: String, challenge: String) {
    var bytes = [UInt8](repeating: 0, count: 32)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    let verifier  = Data(bytes).base64URLEncoded()
    let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded()
    return (verifier, challenge)
  }

  static func authorizationURL(config: SMARTConfig, aud: String, codeChallenge: String, state: String) -> URL? {
    var components = URLComponents(string: config.authorization_endpoint)
    // 保留 endpoint 既有的 query params（如 launch context），再 append 我們的參數
    let existing = components?.queryItems ?? []
    components?.queryItems = existing + [
      .init(name: "response_type",          value: "code"),
      .init(name: "client_id",              value: clientID),
      .init(name: "redirect_uri",           value: redirectURI),
      .init(name: "aud",                    value: aud),
      .init(name: "scope",                  value: scope),
      .init(name: "state",                  value: state),
      .init(name: "code_challenge",         value: codeChallenge),
      .init(name: "code_challenge_method",  value: "S256"),
    ]
    return components?.url
  }

  static func exchangeToken(
    config: SMARTConfig,
    code: String,
    codeVerifier: String
  ) async throws -> SMARTTokenResponse {
    guard let tokenURL = URL(string: config.token_endpoint) else {
      throw APIError.message("Invalid token endpoint URL")
    }
    var request = URLRequest(url: tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    let body = [
      "grant_type=authorization_code",
      "code=\(code)",
      "redirect_uri=\(redirectURI)",
      "client_id=\(clientID)",
      "code_verifier=\(codeVerifier)",
    ].joined(separator: "&")
    request.httpBody = Data(body.utf8)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode) else {
      throw APIError.message("Token 交換失敗")
    }
    return try JSONDecoder().decode(SMARTTokenResponse.self, from: data)
  }
}

// MARK: - Data+Base64URL

private extension Data {
  func base64URLEncoded() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
