import Foundation

// MARK: - State

extension QRCodeViewModel {
  struct State: Sendable {
    var isFirstAppear = true
    var profile: PatientSummary? = nil
    var qrPayload: String? = nil
  }
}

// MARK: - Domain Models

extension QRCodeViewModel {
  struct PatientSummary: Sendable {
    let name: String
    let idNumber: String
    let birthday: Date
    let gender: String
    let phone: String

    // 緊湊格式：身分證|姓名|生日(YYYYMMDD)|性別(M/F)|電話
    // TODO: 加上 Gzip 壓縮以符合 Spec 要求 < 100 Bytes
    var qrPayload: String {
      let genderCode = gender == "male" ? "M" : "F"
      let compact = "\(idNumber)|\(name)|\(Self.birthdayFormatter.string(from: birthday))|\(genderCode)|\(phone)"
      return Data(compact.utf8).base64EncodedString()
    }

    private static let birthdayFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyyMMdd"
      return f
    }()
  }
}
