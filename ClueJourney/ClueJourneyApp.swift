//
//  ClueJourneyApp.swift
//  ClueJourney
//
//  Created by Ruslan Abdulov on 31.08.26.
//

import SwiftUI

@main
struct ClueJourneyApp: App {
    private let container = try? AppContainer.live()

    var body: some Scene {
        WindowGroup {
            ContentView(journey: container?.journey)
        }
    }
}
