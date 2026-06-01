import Observation

@MainActor
@Observable
final class HospitalDetailViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State

  @ObservationIgnored var onRoute: (@MainActor (Router) -> Void)?

  init(hospital: HospitalListViewModel.Hospital) {
    self.state = State(hospital: Hospital(
      id: hospital.id,
      name: hospital.name,
      fhirBaseURL: hospital.fhirBaseURL
    ))
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension HospitalDetailViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case connectTap
    case makeAppointmentTap
    case syncHealthRecordsTap
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
    case .connectTap:
      // TODO: 軌道二 — 啟動 ASWebAuthenticationSession + OAuth2 + PKCE 流程
      state.authStatus = .error("SMART on FHIR 授權流程尚未實作")
    case .makeAppointmentTap:
      // TODO: POST /Appointment
      break
    case .syncHealthRecordsTap:
      // TODO: GET /MedicationRequest
      break
    }
  }
}

// MARK: - Router

extension HospitalDetailViewModel {
  enum Router: Sendable {
    // 未來擴充導航用
  }
}
