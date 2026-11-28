//
//  WelcomeView.swift
//  RecipeFlow
//

import SwiftUI
import Combine

/// Above the plus when there are no recipes yet: fruit and vegetables taking turns, and an invitation.
struct WelcomeView: View {
    private static let icons = [
        "WelcomeStrawberry", "WelcomeCarrot", "WelcomeBlueberries",
        "WelcomePomegranate", "WelcomeBeet", "WelcomeRaspberries",
    ]
    private static let secondsEach = 1.2

    @State private var shown = 0
    private let timer = Timer.publish(every: secondsEach, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image(Self.icons[shown])
                    .resizable()
                    .scaledToFit()
                    .id(shown)
                    .transition(.opacity)
            }
            .frame(width: 110, height: 110)
            .accessibilityHidden(true)

            Text("Add your first recipe!")
                .font(.system(size: 17))
                .foregroundStyle(Theme.ink)
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.35)) { shown = (shown + 1) % Self.icons.count }
        }
    }
}

#Preview {
    WelcomeView()
}
