import Foundation

// MARK: - State

extension HospitalDetailViewModel {
  struct State: Sendable {
    var isFirstAppear = true
    var hospital: Hospital
    var authStatus: AuthStatus = .notConnected
    var api: API = .init()
    var appointments: [Appointment] = []
    var appointmentsLoading = false
  }

  struct API: Sendable {
    var makeAppointment: APIStatus = .prepare
    var syncRecords: APIStatus = .prepare
  }

  enum AuthStatus: Sendable {
    case notConnected
    case connecting
    case connected(accessToken: String, patientFhirID: String?)
    case error(String)

    var isConnected: Bool {
      if case .connected = self { return true }
      return false
    }

    var accessToken: String? {
      if case let .connected(token, _) = self { return token }
      return nil
    }

    var patientFhirID: String? {
      if case let .connected(_, id) = self { return id }
      return nil
    }
  }
}

// MARK: - Domain Models

extension HospitalDetailViewModel {
  struct Appointment: Sendable, Identifiable {
    let id: String
    let status: String
    let start: Date?
    let description: String

    var statusDisplayName: String {
      switch status {
      case "booked":    return "已確認"
      case "proposed":  return "待確認"
      case "fulfilled": return "已就診"
      case "cancelled": return "已取消"
      default:          return status
      }
    }
  }

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
