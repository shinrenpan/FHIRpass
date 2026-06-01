import SwiftUI

struct HospitalListView: View {
  let viewModel: HospitalListViewModel

  var body: some View {
    Group {
      switch viewModel.state.api.fetchHospitals {
      case .loading where viewModel.state.hospitals.isEmpty:
        ProgressView()
      case let .error(message):
        ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
      default:
        hospitalList
      }
    }
    .navigationTitle("合作醫院")
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }
}

// MARK: - Subviews

private extension HospitalListView {
  var hospitalList: some View {
    List(viewModel.state.hospitals) { hospital in
      HospitalRow(hospital: hospital) {
        Task { await viewModel.doAction(.view(.hospitalDidTap(hospital))) }
      }
    }
    .refreshable {
      await viewModel.doAction(.view(.pullToRefresh))
    }
    .overlay {
      if viewModel.state.hospitals.isEmpty {
        ContentUnavailableView("尚無合作醫院", systemImage: "cross.case")
      }
    }
  }

  struct HospitalRow: View {
    let hospital: HospitalListViewModel.Hospital
    let onTap: @MainActor () -> Void

    var body: some View {
      Button {
        onTap()
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(hospital.name)
              .font(.headline)
              .foregroundStyle(.primary)
            Text(hospital.id)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
    }
  }
}

#if DEBUG
#Preview("有資料") {
  let vm: HospitalListViewModel = {
    let vm = HospitalListViewModel()
    vm.state.hospitals = [
      .init(id: "LOGICA_DEMO", name: "FHIRpass 雲端模擬醫院", fhirBaseURL: "https://example.com", isActive: true),
      .init(id: "NTUH", name: "國立臺灣大學醫學院附設醫院", fhirBaseURL: "https://example.com", isActive: true),
    ]
    vm.state.api.fetchHospitals = .success
    return vm
  }()
  NavigationStack { HospitalListView(viewModel: vm) }
}

#Preview("載入中") {
  let vm: HospitalListViewModel = {
    let vm = HospitalListViewModel()
    vm.state.api.fetchHospitals = .loading
    return vm
  }()
  NavigationStack { HospitalListView(viewModel: vm) }
}
#endif
