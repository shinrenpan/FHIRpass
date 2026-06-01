import AuthenticationServices
import SwiftUI

@MainActor
final class HospitalDetailHostController: UIHostingController<HospitalDetailView> {
  private let viewModel: HospitalDetailViewModel
  private var authSession: ASWebAuthenticationSession?

  init(viewModel: HospitalDetailViewModel) {
    self.viewModel = viewModel
    super.init(rootView: HospitalDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] route in
      self?.handleRouter(route)
    }
  }
}

// MARK: - Router

private extension HospitalDetailHostController {
  func handleRouter(_ route: HospitalDetailViewModel.Router) {
    switch route {
    case let .startSMARTAuth(authURL, codeVerifier, config):
      launchAuthSession(authURL: authURL, codeVerifier: codeVerifier, config: config)
    }
  }

  func launchAuthSession(authURL: URL, codeVerifier: String, config: SMARTConfig) {
    let session = ASWebAuthenticationSession(
      url: authURL,
      callbackURLScheme: "fhirpass"
    ) { [weak self] callbackURL, error in
      guard let self else { return }
      if let error {
        Task { await self.viewModel.doAction(.view(.authResult(.failure(error)))) }
        return
      }
      guard let callbackURL,
            let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
        Task {
          await self.viewModel.doAction(
            .view(.authResult(.failure(APIError.message("無效的授權回調 URL"))))
          )
        }
        return
      }
      Task {
        do {
          let tokenResponse = try await SMARTAuth.exchangeToken(
            config: config,
            code: code,
            codeVerifier: codeVerifier
          )
          await self.viewModel.doAction(.view(.authResult(.success(tokenResponse.access_token))))
        } catch {
          await self.viewModel.doAction(.view(.authResult(.failure(error))))
        }
      }
    }
    session.presentationContextProvider = self
    session.prefersEphemeralWebBrowserSession = false
    authSession = session
    session.start()
  }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension HospitalDetailHostController: ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    view.window ?? UIWindow()
  }
}
