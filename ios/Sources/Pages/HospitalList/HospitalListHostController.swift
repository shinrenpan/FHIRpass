import SwiftData
import SwiftUI

@MainActor
final class HospitalListHostController: UIHostingController<HospitalListView> {
  private let viewModel: HospitalListViewModel
  private let modelContext: ModelContext

  init(viewModel: HospitalListViewModel, modelContext: ModelContext) {
    self.viewModel = viewModel
    self.modelContext = modelContext
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
      let vm = HospitalDetailViewModel(hospital: hospital, modelContext: modelContext)
      AppRouter.shared.to(HospitalDetailHostController(viewModel: vm), from: self)
    }
  }
}
