//
//  ContentView.swift
//  ClueJourney
//
//  Created by Ruslan Abdulov on 31.08.26.
//

import PPApplication
import PPFeatures
import SwiftUI

struct ContentView: View {
    let journey: PuzzleJourney?

    var body: some View {
        Group {
            if let journey {
                JourneyFlowView(journey: journey)
            } else {
                ContentUnavailableView(
                    "Unable to start Clue Journey",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The bundled campaign or progress store could not be opened.")
                )
            }
        }
    }
}
