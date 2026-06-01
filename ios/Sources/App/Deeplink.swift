import UIKit

enum Deeplink {
  // 目前無已實作的 deeplink case。
  // 待 AppContainer 設計完成後，在此新增（例如 case profile）。

  init?(url: URL) {
    guard url.scheme == "fhirpass" else { return nil }
    return nil
  }

  @MainActor func makeHostController() -> UIViewController {
    fatalError("unreachable: Deeplink 目前無已實作的 case")
  }
}
