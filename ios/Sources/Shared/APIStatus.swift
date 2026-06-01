import Foundation

enum APIError: LocalizedError, Sendable {
  case message(String)

  var errorDescription: String? {
    if case let .message(msg) = self { return msg }
    return nil
  }
}

enum APIStatus: Equatable, Sendable {
  case prepare
  case loading
  case success
  case error(String)

  var isLoading: Bool {
    if case .loading = self { return true }
    return false
  }
}
