import Foundation

// MARK: - State

extension HospitalListViewModel {
  struct State: Sendable {
    var isFirstAppear = true
    var hospitals: [Hospital] = []
    var api: API = .init()
  }

  struct API: Sendable {
    var fetchHospitals: APIStatus = .prepare
  }
}

// MARK: - Domain Models

extension HospitalListViewModel {
  struct Hospital: Identifiable, Sendable {
    let id: String
    let name: String
    let fhirBaseURL: String
    let isActive: Bool
  }
}

// MARK: - DTOs

extension HospitalListViewModel {
  struct HospitalDTO: Codable, Sendable {
    var fhir_id: String
    var hospital_name: String
    var fhir_base_url: String
    var is_active: Bool

    func toDomain() -> Hospital {
      .init(id: fhir_id, name: hospital_name, fhirBaseURL: fhir_base_url, isActive: is_active)
    }
  }
}
