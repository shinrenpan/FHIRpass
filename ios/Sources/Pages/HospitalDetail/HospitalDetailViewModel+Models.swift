import Foundation

// MARK: - State

extension HospitalDetailViewModel {
  struct State: Sendable {
    var isFirstAppear = true
    var hospital: Hospital
    var authStatus: AuthStatus = .notConnected
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
  }
}

// MARK: - Domain Models

extension HospitalDetailViewModel {
  struct Hospital: Sendable {
    let id: String
    let name: String
    let fhirBaseURL: String
  }
}
