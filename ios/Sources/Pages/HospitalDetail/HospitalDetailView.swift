import SwiftData
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
          apiActionRow(
            label: "線上預約掛號",
            icon: "calendar.badge.plus",
            status: viewModel.state.api.makeAppointment,
            action: .makeAppointmentTap
          )
          apiActionRow(
            label: "同步健康紀錄",
            icon: "arrow.triangle.2.circlepath",
            status: viewModel.state.api.syncRecords,
            action: .syncHealthRecordsTap
          )
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

  @ViewBuilder
  func apiActionRow(
    label: String,
    icon: String,
    status: APIStatus,
    action: HospitalDetailViewModel.ViewAction
  ) -> some View {
    switch status {
    case .prepare:
      Button {
        Task { await viewModel.doAction(.view(action)) }
      } label: {
        Label(label, systemImage: icon)
      }

    case .loading:
      HStack {
        ProgressView()
        Text(label)
          .foregroundStyle(.secondary)
      }

    case .success:
      Label(label + " 完成", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)

    case let .error(message):
      VStack(alignment: .leading, spacing: 4) {
        Label(label + " 失敗", systemImage: "xmark.circle")
          .foregroundStyle(.red)
        Text(message)
          .font(.caption)
          .foregroundStyle(.secondary)
        Button("重試") {
          Task { await viewModel.doAction(.view(action)) }
        }
        .font(.caption)
      }
    }
  }
}

#if DEBUG
#Preview("未授權") {
  let vm = HospitalDetailViewModel(
    hospital: .init(id: "LOGICA_DEMO", name: "FHIRpass 雲端模擬醫院", fhirBaseURL: "https://sandbox.logicahealth.org", isActive: true),
    modelContext: try! ModelContainer(for: PatientProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext
  )
  NavigationStack { HospitalDetailView(viewModel: vm) }
}

#Preview("已授權") {
  let vm: HospitalDetailViewModel = {
    let vm = HospitalDetailViewModel(
      hospital: .init(id: "LOGICA_DEMO", name: "FHIRpass 雲端模擬醫院", fhirBaseURL: "https://sandbox.logicahealth.org", isActive: true),
      modelContext: try! ModelContainer(for: PatientProfile.self, configurations: .init(isStoredInMemoryOnly: true)).mainContext
    )
    vm.state.authStatus = .connected(accessToken: "mock-token", patientFhirID: nil)
    return vm
  }()
  NavigationStack { HospitalDetailView(viewModel: vm) }
}
#endif
