import SwiftData
import Foundation

@Model
final class PatientProfile {
  var name: String
  var idNumber: String
  var birthday: Date
  var gender: String  // "male" | "female"
  var phone: String
  var createdAt: Date

  init(name: String, idNumber: String, birthday: Date, gender: String, phone: String) {
    self.name = name
    self.idNumber = idNumber
    self.birthday = birthday
    self.gender = gender
    self.phone = phone
    self.createdAt = Date()
  }
}
