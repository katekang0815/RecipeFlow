//
//  PhotoAddIcon.swift
//  RecipeFlow
//

import SwiftUI

/// A picture frame with a sun and mountains, open at the bottom right where a plus sits:
/// "add a photo". Drawn in the current foreground color, so it works at any size.
struct PhotoAddIcon: View {
    var body: some View {
        Canvas { context, size in
            let s = min(size.width, size.height)
            let originX = (size.width - s) / 2
            let originY = (size.height - s) / 2
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: originX + x * s, y: originY + y * s)
            }
            let line = 0.075 * s
            let stroke = StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round)

            // The frame, which stops short on the right and at the bottom to make room for the plus.
            let left: CGFloat = 0.035, top: CGFloat = 0.04, right: CGFloat = 0.816, bottom: CGFloat = 0.825
            let radius: CGFloat = 0.13
            var frame = Path()
            frame.move(to: point(right, 0.545))
            frame.addLine(to: point(right, top + radius))
            frame.addArc(tangent1End: point(right, top), tangent2End: point(right - radius, top), radius: radius * s)
            frame.addLine(to: point(left + radius, top))
            frame.addArc(tangent1End: point(left, top), tangent2End: point(left, top + radius), radius: radius * s)
            frame.addLine(to: point(left, bottom - radius))
            frame.addArc(tangent1End: point(left, bottom), tangent2End: point(left + radius, bottom), radius: radius * s)
            frame.addLine(to: point(0.54, bottom))
            context.stroke(frame, with: .foreground, style: stroke)

            // The sun.
            let sun = CGRect(x: originX + (0.321 - 0.09) * s, y: originY + (0.236 - 0.09) * s, width: 0.18 * s, height: 0.18 * s)
            context.fill(Path(ellipseIn: sun), with: .foreground)

            // The mountains.
            var mountains = Path()
            mountains.move(to: point(0.144, 0.717))
            mountains.addLine(to: point(0.144, 0.488))
            mountains.addLine(to: point(0.208, 0.434))
            mountains.addLine(to: point(0.325, 0.524))
            mountains.addLine(to: point(0.526, 0.335))
            mountains.addLine(to: point(0.708, 0.488))
            mountains.addLine(to: point(0.708, 0.717))
            mountains.closeSubpath()
            context.fill(mountains, with: .foreground)
            context.stroke(mountains, with: .foreground, style: StrokeStyle(lineWidth: 0.03 * s, lineCap: .round, lineJoin: .round))

            // The plus.
            var plus = Path()
            plus.move(to: point(0.668, 0.825))
            plus.addLine(to: point(0.974, 0.825))
            plus.move(to: point(0.821, 0.672))
            plus.addLine(to: point(0.821, 0.978))
            context.stroke(plus, with: .foreground, style: stroke)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        PhotoAddIcon().frame(width: 20, height: 20)
        PhotoAddIcon().frame(width: 60, height: 60)
        PhotoAddIcon().frame(width: 160, height: 160)
    }
    .foregroundStyle(.black)
    .padding()
}
