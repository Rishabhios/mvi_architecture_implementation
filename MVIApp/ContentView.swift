//
//  ContentView.swift
//  Emirates
//
//  Created by Rishabh Gupta on 10/04/2026.
//

import SwiftUI

struct ContentView: View {
    @State var store: ViewModel

    var body: some View {
        NavigationStack {
            main
                .navigationTitle("Flights")
        }
        .task {
            if store.state.viewState == .idle {
                store.send(intent: .loadFlightList)
            }
        }
    }

    @ViewBuilder
    var main: some View {
        switch store.state.viewState {
        case .loading:
            ProgressView("Loading flights...")

        case .failure(let message):
            VStack(spacing: 12) {
                Text(message)
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    store.send(intent: .loadFlightList)
                }
            }
            .padding()

        case .success:
            List(store.state.flights, id: \.id) { trip in
                NavigationLink {
                    FlightDetailView(trip: trip)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.passengerName ?? "N/A")
                            .font(.headline)

                        Text(trip.flightNumber ?? "Flight N/A")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(trip.departureCity ?? "N/A") → \(trip.arrivalCity ?? "N/A")")
                            .font(.subheadline)

                        Text(formatDate(trip.departureTime))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(trip.status ?? "N/A")
                            .padding(4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
            }

        case .idle:
            EmptyView()

        case .empty:
            VStack(spacing: 12) {
                Text("No flights found")
                Button("Reload") {
                    store.send(intent: .loadFlightList)
                }
            }
            .padding()
        }
    }

    private func formatDate(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "N/A" }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: value) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }

        return value
    }
}

struct FlightDetailView: View {
    let trip: Trip

    var body: some View {
        List {
            detailRow(title: "PNR", value: trip.pnr)
            detailRow(title: "Passenger Name", value: trip.passengerName)
            detailRow(title: "Flight Number", value: trip.flightNumber)
            detailRow(title: "Departure City", value: trip.departureCity)
            detailRow(title: "Arrival City", value: trip.arrivalCity)
            detailRow(title: "Departure Time", value: trip.departureTime)
            detailRow(title: "Arrival Time", value: trip.arrivalTime)
            detailRow(title: "Status", value: trip.status)
        }
        .navigationTitle("Flight Detail")
    }

    @ViewBuilder
    private func detailRow(title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value?.isEmpty == false ? value! : "N/A")
                .foregroundStyle(.secondary)
        }
    }
}

struct FlightState {
    var viewState: FlightViewState = .idle
    var flights: [Trip] = []
}

enum FlightViewState: Equatable {
    case loading
    case failure(String)
    case success
    case idle
    case empty
}

enum FlightListIntent {
    case loadFlightList
}

enum FlightListResult {
    case flightListLoaded([Trip])
    case failure(String)
    case setLoading
}

@MainActor
@Observable
final class ViewModel {

    let repository: FlightRepositoryProtocol

    init(repository: FlightRepositoryProtocol) {
        self.repository = repository
    }

    var state: FlightState = FlightState()

    func send(intent: FlightListIntent) {
        switch intent {
        case .loadFlightList:
            Task {
                await loadFlights()
            }
        }
    }

    func loadFlights() async {
        reducer(state: &state, result: .setLoading)

        do {
            let flights = try await repository.fetchFlight()
            reducer(state: &state, result: .flightListLoaded(flights))
        } catch {
            reducer(state: &state, result: .failure("Something went wrong"))
        }
    }

    func reducer(state: inout FlightState, result: FlightListResult) {
        switch result {
        case .flightListLoaded(let flights):
            state.flights = flights
            state.viewState = flights.isEmpty ? .empty : .success

        case .setLoading:
            state.viewState = .loading

        case .failure(let message):
            state.viewState = .failure(message)
        }
    }
}

// MARK: Model

struct TripsResponse: Decodable {
    let id: String?
    let record: Record?
    let metadata: Metadata?
}

struct Record: Decodable {
    let data: [Trip]?
}

struct Trip: Decodable {
    let pnr: String?
    let passengerName: String?
    let flightNumber: String?
    let departureCity: String?
    let arrivalCity: String?
    let departureTime: String?
    let arrivalTime: String?
    let status: String?

    var id: String {
        if let pnr, !pnr.isEmpty {
            return pnr
        }
        return [
            passengerName,
            flightNumber,
            departureTime
        ]
        .compactMap { $0 }
        .joined(separator: "-")
    }
}

struct Metadata: Decodable {
    let name: String?
    let readCountRemaining: Int?
    let timeToExpire: Int?
    let createdAt: String?
}

// MARK: Repository

protocol FlightRepositoryProtocol {
    func fetchFlight() async throws -> [Trip]
}

final class FlightRepositoryImplementation: FlightRepositoryProtocol {

    private let networkService: APIClient

    init(networkService: APIClient) {
        self.networkService = networkService
    }

    func fetchFlight() async throws -> [Trip] {
        let response: TripsResponse = try await self.networkService.offlineRequest(endPoint: FlightListEndPoint())
        return response.record?.data ?? []
    }
}

// MARK: Network Layer

enum HttpMethodType: String {
    case GET
}

enum NetworkError: Error {
    case invalidUrl
    case invalidStatusCode
    case authoriseAccess
    case serverError(Int)
}

protocol EndPoint {
    var baseUrl: String { get }
    var path: String { get }
    var httpMethod: HttpMethodType { get }
    var mockJsonName: String? { get }
    func createRequest() throws -> URLRequest
}

extension EndPoint {
    func createRequest() throws -> URLRequest {
        let component = URLComponents(string: baseUrl.appending(path))
        guard let finalUrl = component?.url else {
            throw NetworkError.invalidUrl
        }

        var request = URLRequest(url: finalUrl)
        request.httpMethod = httpMethod.rawValue
        return request
    }
}

struct FlightListEndPoint: EndPoint {

    var baseUrl: String {
        "https://api.jsonbin.io"
    }

    var path: String {
        "/v3/qs/69d7ada7856a68218915d86a"
    }

    var httpMethod: HttpMethodType {
        .GET
    }
    
    var mockJsonName: String? {
        "Mock"
    }
}

protocol APIClient {
    func request<T: Decodable>(endPoint: EndPoint) async throws -> T
    func offlineRequest<T: Decodable>(endPoint: EndPoint) async throws -> T
}

final class APIService: APIClient {
    
    func offlineRequest<T>(endPoint: EndPoint) async throws -> T where T: Decodable {
        try await Task.sleep(for: .milliseconds(1000))
        guard let url = Bundle.main.url(forResource: endPoint.mockJsonName, withExtension: "json") else {
            throw NetworkError.invalidUrl
        }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw error
        }
    }

    func request<T: Decodable>(endPoint: EndPoint) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: endPoint.createRequest())
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            throw NetworkError.invalidStatusCode
        }
        switch statusCode {
        case 200..<299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw NetworkError.authoriseAccess
        default:
            throw NetworkError.serverError(statusCode)
        }
    }
}
