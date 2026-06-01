import Foundation

// MARK: - State

extension HospitalDetailViewModel {
  struct State: Sendable {
    var isFirstAppear = true
    var hospital: Hospital
    var authStatus: AuthStatus = .notConnected
    var api: API = .init()
  }

  struct API: Sendable {
    var makeAppointment: APIStatus = .prepare
    var syncRecords: APIStatus = .prepare
  }

  enum AuthStatus: Sendable {
    case notConnected
    case connecting
    case connected(accessToken: String)
    case error(String)

    var isConnected: Bool {
      if case .connected = self { return true }
      return false
    }

    var accessToken: String? {
      if case let .connected(token) = self { return token }
      return nil
    }
  }
}

// MARK: - Domain Models

extension HospitalDetailViewModel {
  struct Hospital: Sendable {
    let id: String
    let name: String
    let fhirBaseURL: String

    var wellKnownURL: URL? {
      URL(string: "\(fhirBaseURL)/.well-known/smart-configuration")
    }

    var keychainKey: String { "token.\(id)" }
  }
}
