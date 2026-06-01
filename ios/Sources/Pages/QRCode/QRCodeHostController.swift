import SwiftUI
import SwiftData

@MainActor
final class QRCodeHostController: UIHostingController<QRCodeView> {
  private let viewModel: QRCodeViewModel

  init(modelContext: ModelContext) {
    let vm = QRCodeViewModel(modelContext: modelContext)
    self.viewModel = vm
    super.init(rootView: QRCodeView(viewModel: vm))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    Task { await viewModel.doAction(.view(.refresh)) }
  }
}

// MARK: - Router

private extension QRCodeHostController {
  func handleRouter(_ router: QRCodeViewModel.Router) {
    switch router {
    case .toProfile:
      AppRouter.shared.tab(2, from: self)
    }
  }
}
