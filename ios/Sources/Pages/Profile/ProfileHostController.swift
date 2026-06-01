import SwiftUI
import SwiftData

@MainActor
final class ProfileHostController: UIHostingController<ProfileView> {
  private let viewModel: ProfileViewModel

  init(modelContext: ModelContext) {
    let vm = ProfileViewModel(modelContext: modelContext)
    self.viewModel = vm
    super.init(rootView: ProfileView(viewModel: vm))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  override func viewDidLoad() {
    super.viewDidLoad()
  }
}
