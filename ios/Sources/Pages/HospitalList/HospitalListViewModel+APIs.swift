import Foundation

// MARK: - API

enum HospitalListAPI {
  // 中台 Server 的 base URL，實際部署後換成真實位址
  private static let serverBaseURL = "http://localhost:8000"

  static func fetchHospitals() async throws -> [HospitalListViewModel.HospitalDTO] {
    guard let url = URL(string: "\(serverBaseURL)/hospitals") else {
      throw APIError.message("Invalid URL")
    }
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode) else {
      throw APIError.message("Server error")
    }
    return try JSONDecoder().decode([HospitalListViewModel.HospitalDTO].self, from: data)
  }
}
