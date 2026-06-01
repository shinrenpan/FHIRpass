import SwiftUI

struct HospitalDetailView: View {
  let viewModel: HospitalDetailViewModel

  var body: some View {
    List {
      Section("醫院資訊") {
        LabeledContent("院所代碼", value: viewModel.state.hospital.id)
        LabeledContent("FHIR 端點", value: viewModel.state.hospital.fhirBaseURL)
          .font(.caption)
      }

      Section("授權狀態") {
        authStatusRow
      }

      if viewModel.state.authStatus.isConnected {
        Section("線上服務") {
          Button("線上預約掛號") {
            Task { await viewModel.doAction(.view(.makeAppointmentTap)) }
          }
          Button("同步健康紀錄") {
            Task { await viewModel.doAction(.view(.syncHealthRecordsTap)) }
          }
        }
      }
    }
    .navigationTitle(viewModel.state.hospital.name)
    .task {
      await viewModel.doAction(.view(.isFirstAppear))
    }
  }
}

// MARK: - Subviews

private extension HospitalDetailView {
  @ViewBuilder
  var authStatusRow: some View {
    switch viewModel.state.authStatus {
    case .notConnected:
      Button {
        Task { await viewModel.doAction(.view(.connectTap)) }
      } label: {
        Label("連結此醫院帳號", systemImage: "link")
      }

    case .connecting:
      HStack {
        ProgressView()
        Text("授權中…")
          .foregroundStyle(.secondary)
      }

    case .connected:
      Label("已完成授權", systemImage: "checkmark.seal.fill")
        .foregroundStyle(.green)

    case let .error(message):
      VStack(alignment: .leading, spacing: 4) {
        Label("授權失敗", systemImage: "xmark.circle")
          .foregroundStyle(.red)
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("重試") {
          Task { await viewModel.doAction(.view(.connectTap)) }
        }
        .font(.caption)
      }
    }
  }
}

#if DEBUG
#Preview("未授權") {
  let vm = HospitalDetailViewModel(
    hospital: .init(id: "LOGICA_DEMO", name: "FHIRpass 雲端模擬醫院", fhirBaseURL: "https://sandbox.logicahealth.org", isActive: true)
  )
  NavigationStack { HospitalDetailView(viewModel: vm) }
}

#Preview("已授權") {
  let vm: HospitalDetailViewModel = {
    let vm = HospitalDetailViewModel(
      hospital: .init(id: "LOGICA_DEMO", name: "FHIRpass 雲端模擬醫院", fhirBaseURL: "https://sandbox.logicahealth.org", isActive: true)
    )
    vm.state.authStatus = .connected(accessToken: "mock-token")
    return vm
  }()
  NavigationStack { HospitalDetailView(viewModel: vm) }
}
#endif
