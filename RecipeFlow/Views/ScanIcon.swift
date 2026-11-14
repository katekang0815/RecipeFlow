//
//  ScanIcon.swift
//  RecipeFlow
//

import SwiftUI

/// Four corner brackets, like a camera's viewfinder: "add a photo". Plain lines in the current
/// foreground color, with no background, so it works at any size.
struct ScanIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let originX = (size.width - s) / 2
            let originY = (size.height - s) / 2
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: originX + x * s, y: originY + y * s)
            }

            // Proportions measured from the design: a square, a line about 7% of its width, corners with
            // a radius of about 9%, and arms that reach about a quarter of the way along each edge.
            let low: CGFloat = 0.034, high: CGFloat = 0.966
            let arm: CGFloat = 0.23, radius: CGFloat = 0.095

            var brackets = Path()
            // top left
            brackets.move(to: point(low, low + arm))
            brackets.addLine(to: point(low, low + radius))
            brackets.addArc(tangent1End: point(low, low), tangent2End: point(low + radius, low), radius: radius * s)
            brackets.addLine(to: point(low + arm, low))
            // top right
            brackets.move(to: point(high - arm, low))
            brackets.addLine(to: point(high - radius, low))
            brackets.addArc(tangent1End: point(high, low), tangent2End: point(high, low + radius), radius: radius * s)
            brackets.addLine(to: point(high, low + arm))
            // bottom right
            brackets.move(to: point(high, high - arm))
            brackets.addLine(to: point(high, high - radius))
            brackets.addArc(tangent1End: point(high, high), tangent2End: point(high - radius, high), radius: radius * s)
            brackets.addLine(to: point(high - arm, high))
            // bottom left
            brackets.move(to: point(low + arm, high))
            brackets.addLine(to: point(low + radius, high))
            brackets.addArc(tangent1End: point(low, high), tangent2End: point(low, high - radius), radius: radius * s)
            brackets.addLine(to: point(low, high - arm))

            context.stroke(
                brackets,
                with: .foreground,
                style: StrokeStyle(lineWidth: 0.068 * s, lineCap: .round, lineJoin: .round)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        ScanIcon().frame(width: 28, height: 28)
        ScanIcon().frame(width: 74, height: 74)
        ScanIcon().frame(width: 160, height: 160)
    }
    .foregroundStyle(Theme.ink)
    .padding()
}
