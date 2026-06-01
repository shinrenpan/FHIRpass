import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ProfileViewModel {
  enum Action: Sendable {
    case view(ViewAction)
  }

  var state: State = .init()

  private let modelContext: ModelContext

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action): await handleViewAction(action)
    }
  }
}

// MARK: - View Action

extension ProfileViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case editTap
    case cancelTap
    case saveTap
    case nameChanged(String)
    case idNumberChanged(String)
    case birthdayChanged(Date)
    case genderChanged(Gender)
    case phoneChanged(String)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      loadProfile()
    case .editTap:
      state.isEditing = true
      state.saveStatus = .prepare
    case .cancelTap:
      state.isEditing = false
      loadProfile()
    case .saveTap:
      await saveProfile()
    case let .nameChanged(value):
      state.name = value
    case let .idNumberChanged(value):
      state.idNumber = value
    case let .birthdayChanged(value):
      state.birthday = value
    case let .genderChanged(value):
      state.gender = value
    case let .phoneChanged(value):
      state.phone = value
    }
  }
}

// MARK: - Private

private extension ProfileViewModel {
  func loadProfile() {
    let descriptor = FetchDescriptor<PatientProfile>()
    guard let profile = try? modelContext.fetch(descriptor).first else {
      state.hasExistingProfile = false
      state.isEditing = true
      return
    }
    state.hasExistingProfile = true
    state.isEditing = false
    state.name = profile.name
    state.idNumber = profile.idNumber
    state.birthday = profile.birthday
    state.gender = profile.gender == "female" ? .female : .male
    state.phone = profile.phone
  }

  func saveProfile() async {
    state.saveStatus = .loading
    let descriptor = FetchDescriptor<PatientProfile>()
    if let existing = try? modelContext.fetch(descriptor).first {
      existing.name = state.name
      existing.idNumber = state.idNumber
      existing.birthday = state.birthday
      existing.gender = state.gender.rawValue
      existing.phone = state.phone
    } else {
      let profile = PatientProfile(
        name: state.name,
        idNumber: state.idNumber,
        birthday: state.birthday,
        gender: state.gender.rawValue,
        phone: state.phone
      )
      modelContext.insert(profile)
    }
    do {
      try modelContext.save()
      state.saveStatus = .success
      state.hasExistingProfile = true
      state.isEditing = false
    } catch {
      state.saveStatus = .error(error.localizedDescription)
    }
  }
}
