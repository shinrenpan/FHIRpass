import Observation
import SwiftData

@MainActor
@Observable
final class QRCodeViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  @ObservationIgnored var onRoute: (@MainActor (Router) -> Void)?

  private let modelContext: ModelContext

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension QRCodeViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case refresh
    case setupProfileTap
  }

  private func handleViewAction(_ action: ViewAction) {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      loadProfile()
    case .refresh:
      loadProfile()
    case .setupProfileTap:
      onRoute?(.toProfile)
    }
  }
}

// MARK: - Router

extension QRCodeViewModel {
  enum Router: Sendable {
    case toProfile
  }
}

// MARK: - Private

private extension QRCodeViewModel {
  func loadProfile() {
    let descriptor = FetchDescriptor<PatientProfile>()
    guard let record = try? modelContext.fetch(descriptor).first else {
      state.profile = nil
      state.qrPayload = nil
      return
    }
    let summary = PatientSummary(
      name: record.name,
      idNumber: record.idNumber,
      birthday: record.birthday,
      gender: record.gender,
      phone: record.phone
    )
    state.profile = summary
    state.qrPayload = summary.qrPayload
  }
}
