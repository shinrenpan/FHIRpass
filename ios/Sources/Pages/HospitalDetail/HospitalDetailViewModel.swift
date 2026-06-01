import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class HospitalDetailViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State

  @ObservationIgnored private let modelContext: ModelContext
  @ObservationIgnored var onRoute: (@MainActor (Router) -> Void)?

  init(hospital: HospitalListViewModel.Hospital, modelContext: ModelContext) {
    self.modelContext = modelContext
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
    case authResult(Result<String, Error>)
    case makeAppointmentTap
    case syncHealthRecordsTap
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      restoreToken()

    case .connectTap:
      await startSMARTAuth()

    case let .authResult(.success(token)):
      KeychainService.save(key: state.hospital.keychainKey, value: token)
      state.authStatus = .connected(accessToken: token)

    case let .authResult(.failure(error)):
      state.authStatus = .error(error.localizedDescription)

    case .makeAppointmentTap:
      await handleMakeAppointment()

    case .syncHealthRecordsTap:
      await handleSyncRecords()
    }
  }
}

// MARK: - Router

extension HospitalDetailViewModel {
  enum Router: Sendable {
    case startSMARTAuth(authURL: URL, codeVerifier: String, config: SMARTConfig)
  }
}

// MARK: - Private

private extension HospitalDetailViewModel {
  func restoreToken() {
    if let token = KeychainService.load(key: state.hospital.keychainKey) {
      state.authStatus = .connected(accessToken: token)
    }
  }

  func startSMARTAuth() async {
    guard let wellKnownURL = state.hospital.wellKnownURL else {
      state.authStatus = .error("無效的 SMART 端點 URL")
      return
    }
    state.authStatus = .connecting
    do {
      let config = try await SMARTConfig.fetch(from: wellKnownURL)
      let (verifier, challenge) = SMARTAuth.generatePKCE()
      guard let authURL = SMARTAuth.authorizationURL(
        config: config,
        codeChallenge: challenge,
        state: UUID().uuidString
      ) else {
        state.authStatus = .error("無法建構授權 URL")
        return
      }
      onRoute?(.startSMARTAuth(authURL: authURL, codeVerifier: verifier, config: config))
    } catch {
      state.authStatus = .error(error.localizedDescription)
    }
  }

  func handleMakeAppointment() async {
    guard let token = state.authStatus.accessToken else { return }
    guard let idNumber = patientIdNumber() else {
      state.api.makeAppointment = .error("找不到本機個人資料，請先至「個人資料」Tab 建檔")
      return
    }
    state.api.makeAppointment = .loading
    do {
      try await fhirMakeAppointment(accessToken: token, patientIdNumber: idNumber)
      state.api.makeAppointment = .success
    } catch {
      state.api.makeAppointment = .error(error.localizedDescription)
    }
  }

  func handleSyncRecords() async {
    guard let token = state.authStatus.accessToken else { return }
    guard let idNumber = patientIdNumber() else {
      state.api.syncRecords = .error("找不到本機個人資料，請先至「個人資料」Tab 建檔")
      return
    }
    state.api.syncRecords = .loading
    do {
      let count = try await fhirSyncMedications(accessToken: token, patientIdNumber: idNumber)
      state.api.syncRecords = count > 0 ? .success : .error("此醫院尚無用藥紀錄")
    } catch {
      state.api.syncRecords = .error(error.localizedDescription)
    }
  }

  func patientIdNumber() -> String? {
    let descriptor = FetchDescriptor<PatientProfile>()
    return (try? modelContext.fetch(descriptor).first)?.idNumber
  }
}
