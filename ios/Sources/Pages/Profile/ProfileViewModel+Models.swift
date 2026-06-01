import Foundation

// MARK: - State

extension ProfileViewModel {
  struct State: Sendable {
    var isFirstAppear = true
    var name: String = ""
    var idNumber: String = ""
    var birthday: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    var gender: Gender = .male
    var phone: String = ""
    var isEditing: Bool = false
    var saveStatus: APIStatus = .prepare
    var hasExistingProfile: Bool = false
  }

  enum Gender: String, CaseIterable, Sendable {
    case male = "male"
    case female = "female"

    var displayName: String {
      switch self {
      case .male: "男"
      case .female: "女"
      }
    }
  }
}
