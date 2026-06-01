import UIKit
import SwiftData

@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private let modelContainer: ModelContainer = {
    let schema = Schema([PatientProfile.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: false)
    return try! ModelContainer(for: schema, configurations: config)
  }()

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let context = modelContainer.mainContext

    let qrNav = UINavigationController(
      rootViewController: QRCodeHostController(modelContext: context)
    )
    qrNav.tabBarItem = UITabBarItem(title: "通行碼", image: UIImage(systemName: "qrcode"), tag: 0)

    let hospitalNav = UINavigationController(
      rootViewController: HospitalListHostController(viewModel: .init())
    )
    hospitalNav.tabBarItem = UITabBarItem(title: "合作醫院", image: UIImage(systemName: "cross.case"), tag: 1)

    let profileNav = UINavigationController(
      rootViewController: ProfileHostController(modelContext: context)
    )
    profileNav.tabBarItem = UITabBarItem(title: "個人資料", image: UIImage(systemName: "person"), tag: 2)

    let tabBar = UITabBarController()
    tabBar.viewControllers = [qrNav, hospitalNav, profileNav]

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = tabBar
    window.backgroundColor = .systemBackground
    window.makeKeyAndVisible()
    self.window = window

    if let url = connectionOptions.urlContexts.first?.url,
       let deeplink = Deeplink(url: url) {
      AppRouter.shared.deeplink(deeplink.makeHostController())
    }
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url,
          let deeplink = Deeplink(url: url) else { return }
    AppRouter.shared.deeplink(deeplink.makeHostController())
  }
}
