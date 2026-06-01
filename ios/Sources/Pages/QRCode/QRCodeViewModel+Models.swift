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
    // 編碼：UTF-8 → zlib 壓縮 → Base64
    var qrPayload: String {
      let genderCode = gender == "male" ? "M" : "F"
      let compact = "\(idNumber)|\(name)|\(Self.birthdayFormatter.string(from: birthday))|\(genderCode)|\(phone)"
      let data = Data(compact.utf8)
      let payload = (try? (data as NSData).compressed(using: .zlib) as Data) ?? data
      return payload.base64EncodedString()
    }

    private static let birthdayFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateFormat = "yyyyMMdd"
      return f
    }()
  }
}
