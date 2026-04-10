//
//  FlightAppApp.swift
//  FlightApp
//
//  Created by Rishabh Gupta on 10/04/2026.
//

import SwiftUI

@main
struct FlightAppApp: App {
    
    private let repository = FlightRepositoryImplementation(networkService: APIService())
    
    var body: some Scene {
        WindowGroup {
            let viewModel = ViewModel(repository: repository)
            ContentView(store: viewModel)
        }
    }
}
