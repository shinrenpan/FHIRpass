import SwiftUI

@MainActor
final class HospitalDetailHostController: UIHostingController<HospitalDetailView> {
  private let viewModel: HospitalDetailViewModel

  init(viewModel: HospitalDetailViewModel) {
    self.viewModel = viewModel
    super.init(rootView: HospitalDetailView(viewModel: viewModel))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
    viewModel.onRoute = { [weak self] router in
      self?.handleRouter(router)
    }
  }
}

// MARK: - Router

private extension HospitalDetailHostController {
  func handleRouter(_ router: HospitalDetailViewModel.Router) {
    // 未來擴充導航
  }
}
