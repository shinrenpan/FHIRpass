import UIKit

enum Deeplink {
  case profile

  init?(url: URL) {
    guard url.scheme == "fhirpass" else { return nil }
    switch url.host {
    case "profile": self = .profile
    default: return nil
    }
  }

  @MainActor func makeHostController() -> UIViewController {
    switch self {
    case .profile:
      // SceneDelegate 的 ModelContainer 才是正確來源；
      // Deeplink 情境下暫不支援，後續搭配 AppContainer 實作
      fatalError("TODO: inject ModelContext via AppContainer")
    }
  }
}
