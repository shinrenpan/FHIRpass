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
    case authResult(Result<SMARTTokenResponse, Error>)
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

    case let .authResult(.success(tokenResponse)):
      KeychainService.save(key: state.hospital.keychainKey, value: tokenResponse.access_token)
      if let patientID = tokenResponse.patient {
        KeychainService.save(key: state.hospital.keychainKey + ".patient", value: patientID)
      }
      state.authStatus = .connected(
        accessToken: tokenResponse.access_token,
        patientFhirID: tokenResponse.patient
      )

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
    guard let token = KeychainService.load(key: state.hospital.keychainKey) else { return }
    let patientID = KeychainService.load(key: state.hospital.keychainKey + ".patient")
    state.authStatus = .connected(accessToken: token, patientFhirID: patientID)
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
    let patientFhirID = state.authStatus.patientFhirID
    let idNumber = patientIdNumber() ?? ""
    guard patientFhirID != nil || !idNumber.isEmpty else {
      state.api.makeAppointment = .error("找不到病患識別資料")
      return
    }
    state.api.makeAppointment = .loading
    do {
      try await fhirMakeAppointment(accessToken: token, patientFhirID: patientFhirID, patientIdNumber: idNumber)
      state.api.makeAppointment = .success
    } catch {
      state.api.makeAppointment = .error(error.localizedDescription)
    }
  }

  func handleSyncRecords() async {
    guard let token = state.authStatus.accessToken else { return }
    let patientFhirID = state.authStatus.patientFhirID
    let idNumber = patientIdNumber() ?? ""
    guard patientFhirID != nil || !idNumber.isEmpty else {
      state.api.syncRecords = .error("找不到病患識別資料")
      return
    }
    state.api.syncRecords = .loading
    do {
      let count = try await fhirSyncMedications(accessToken: token, patientFhirID: patientFhirID, patientIdNumber: idNumber)
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
