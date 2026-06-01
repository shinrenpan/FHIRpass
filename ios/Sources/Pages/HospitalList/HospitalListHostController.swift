import SwiftUI

@MainActor
final class HospitalListHostController: UIHostingController<HospitalListView> {
  private let viewModel: HospitalListViewModel

  init(viewModel: HospitalListViewModel) {
    self.viewModel = viewModel
    super.init(rootView: HospitalListView(viewModel: viewModel))
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

private extension HospitalListHostController {
  func handleRouter(_ router: HospitalListViewModel.Router) {
    switch router {
    case let .toHospitalDetail(hospital):
      AppRouter.shared.to(
        HospitalDetailHostController(viewModel: .init(hospital: hospital)),
        from: self
      )
    }
  }
}
