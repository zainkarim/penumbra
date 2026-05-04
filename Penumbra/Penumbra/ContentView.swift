//
//  ContentView.swift
//  Penumbra
//
//  Created by Zain Karim on 3/28/26.
//

import SwiftUI

struct ContentView: View {
    @State private var hudState = HUDState()

    var body: some View {
        ZStack {
            ARViewContainer(hudState: hudState)
                .ignoresSafeArea()
            HUDOverlayView(hudState: hudState)
        }
    }
}
