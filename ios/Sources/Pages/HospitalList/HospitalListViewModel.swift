import Observation

@MainActor
@Observable
final class HospitalListViewModel {
  enum Action: Sendable {
    case view(ViewAction)
    case apiRequest(APIRequest)
    case apiResponse(APIResponse)
  }

  var state: State = .init()

  @ObservationIgnored var onRoute: (@MainActor (Router) -> Void)?

  func doAction(_ action: Action) async {
    switch action {
    case let .view(action):       await handleViewAction(action)
    case let .apiRequest(request): await handleAPIRequest(request)
    case let .apiResponse(response): handleAPIResponse(response)
    }
  }
}

// MARK: - View Action

extension HospitalListViewModel {
  enum ViewAction: Sendable {
    case isFirstAppear
    case pullToRefresh
    case hospitalDidTap(Hospital)
  }

  private func handleViewAction(_ action: ViewAction) async {
    switch action {
    case .isFirstAppear:
      guard state.isFirstAppear else { return }
      state.isFirstAppear = false
      await doAction(.apiRequest(.fetchHospitals))
    case .pullToRefresh:
      await doAction(.apiRequest(.fetchHospitals))
    case let .hospitalDidTap(hospital):
      onRoute?(.toHospitalDetail(hospital))
    }
  }
}

// MARK: - Router

extension HospitalListViewModel {
  enum Router: Sendable {
    case toHospitalDetail(Hospital)
  }
}

// MARK: - API Request

extension HospitalListViewModel {
  enum APIRequest: Sendable {
    case fetchHospitals
  }

  private func handleAPIRequest(_ request: APIRequest) async {
    switch request {
    case .fetchHospitals:
      guard !state.api.fetchHospitals.isLoading else { return }
      state.api.fetchHospitals = .loading
      do {
        let dtos = try await HospitalListAPI.fetchHospitals()
        await doAction(.apiResponse(.fetchHospitals(.success(dtos))))
      } catch {
        await doAction(.apiResponse(.fetchHospitals(.failure(.message(error.localizedDescription)))))
      }
    }
  }
}

// MARK: - API Response

extension HospitalListViewModel {
  enum APIResponse: Sendable {
    case fetchHospitals(Result<[HospitalDTO], APIError>)
  }

  private func handleAPIResponse(_ response: APIResponse) {
    switch response {
    case let .fetchHospitals(.success(dtos)):
      state.hospitals = dtos.map { $0.toDomain() }
      state.api.fetchHospitals = .success
    case let .fetchHospitals(.failure(.message(msg))):
      state.api.fetchHospitals = .error(msg)
    }
  }
}
