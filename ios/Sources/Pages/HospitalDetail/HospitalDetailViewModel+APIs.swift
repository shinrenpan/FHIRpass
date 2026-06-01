import Foundation

// MARK: - FHIR API Calls

extension HospitalDetailViewModel {
  func fhirMakeAppointment(accessToken: String, patientFhirID: String?, patientIdNumber: String) async throws {
    let resolvedID = try await resolvePatientID(accessToken: accessToken, patientFhirID: patientFhirID, idNumber: patientIdNumber)
    guard let url = URL(string: "\(state.hospital.fhirBaseURL)/Appointment") else {
      throw APIError.message("Invalid FHIR URL")
    }
    let formatter = ISO8601DateFormatter()
    let now = formatter.string(from: Date())
    let end = formatter.string(from: Date().addingTimeInterval(1800))
    let body: [String: Any] = [
      "resourceType": "Appointment",
      "status": "proposed",
      "start": now,
      "end": end,
      "participant": [[
        "actor": ["reference": "Patient/\(resolvedID)"],
        "status": "accepted",
      ]],
    ]
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/fhir+json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse,
          (200..<300).contains(http.statusCode) else {
      throw APIError.message("線上掛號失敗")
    }
  }

  func fhirSyncMedications(accessToken: String, patientFhirID: String?, patientIdNumber: String) async throws -> Int {
    let resolvedID = try await resolvePatientID(accessToken: accessToken, patientFhirID: patientFhirID, idNumber: patientIdNumber)
    guard let url = URL(string: "\(state.hospital.fhirBaseURL)/MedicationRequest?patient=\(resolvedID)") else {
      throw APIError.message("Invalid FHIR URL")
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
    let (data, _) = try await URLSession.shared.data(for: request)
    let bundle = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return (bundle?["entry"] as? [[String: Any]])?.count ?? 0
  }

  // 優先用 OAuth patient context，fallback 到台灣身分證搜尋
  private func resolvePatientID(accessToken: String, patientFhirID: String?, idNumber: String) async throws -> String {
    if let id = patientFhirID { return id }
    guard let url = URL(string: "\(state.hospital.fhirBaseURL)/Patient?identifier=http://moi.gov.tw|\(idNumber)") else {
      throw APIError.message("Invalid FHIR URL")
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/fhir+json", forHTTPHeaderField: "Accept")
    let (data, _) = try await URLSession.shared.data(for: request)
    let bundle = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let entries = bundle?["entry"] as? [[String: Any]],
          let resource = entries.first?["resource"] as? [String: Any],
          let id = resource["id"] as? String else {
      throw APIError.message("此醫院尚無您的病歷，請先至現場完成初診建檔")
    }
    return id
  }
}
