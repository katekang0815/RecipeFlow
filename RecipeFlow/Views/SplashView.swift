//
//  SplashView.swift
//  RecipeFlow
//

import SwiftUI
import Combine

/// The opening screen: a hot pot and its spoon, with steam that keeps changing shape.
/// It leaves by itself, or at a tap: the drawing fades away into the middle, then the recipes fade in.
struct SplashView: View {
    static let seconds = 2.5
    /// How long the drawing takes to go.
    private static let leavingSeconds = 0.6

    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var isLeaving = false

    /// The drawing is laid out in the points of the picture it was cut from: this part of it.
    private static let art = CGRect(x: 40, y: -30, width: 940, height: 925)
    private static let potFrame = CGRect(x: 185, y: 178, width: 790, height: 547)
    private static let spoonFrame = CGRect(x: 40, y: 690, width: 675, height: 202)
    private static let grainFrame = CGRect(x: 0, y: -90, width: 704, height: 850)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GeometryReader { screen in
                // As big as fits with a little room around it, then a sixth smaller.
                let fitted = min(screen.size.width * 0.92 / Self.art.width, screen.size.height * 0.7 / Self.art.height)
                let scale = fitted * 5 / 6
                drawing(scale: scale)
                    .frame(width: Self.art.width * scale, height: Self.art.height * scale)
                    // Going: the whole drawing draws back into its own middle as it fades.
                    // With less motion asked for, it only fades.
                    .scaleEffect(isLeaving && !reduceMotion ? 0.55 : 1)
                    .opacity(isLeaving ? 0 : 1)
                    .position(x: screen.size.width / 2, y: screen.size.height / 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { leave() }
        .accessibilityElement()
        .accessibilityLabel("RecipeFlow")
        .accessibilityIdentifier("splash")
        .task {
            try? await Task.sleep(for: .seconds(Self.seconds))
            if !Task.isCancelled { leave() }
        }
    }

    /// The drawing goes, and when it has gone the splash does, once.
    private func leave() {
        guard !isLeaving else { return }
        withAnimation(.easeInOut(duration: Self.leavingSeconds)) { isLeaving = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.leavingSeconds))
            onDone()
        }
    }

    private func drawing(scale: CGFloat) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            // With less motion asked for, everything holds still: at this moment nothing is shaking.
            let time = reduceMotion ? 1.4 : timeline.date.timeIntervalSince(start)
            // The boiling pot rattles its lid, and the spoon beside it answers a moment later.
            let lid = Self.shake(at: time)
            let spoon = Self.shake(at: time - 0.08)
            ZStack(alignment: .topLeading) {
                Color.clear
                placed(Image("SplashPotBody"), in: Self.potFrame, scale: scale)
                // The lid hops and tips about the middle of its lower edge.
                placed(
                    Image("SplashLid"), in: Self.potFrame, scale: scale,
                    angle: 3.5 * lid, about: UnitPoint(x: 0.494, y: 0.497), lift: 16 * abs(lid)
                )
                placed(
                    Image("SplashSpoon"), in: Self.spoonFrame, scale: scale,
                    angle: 2.5 * spoon, about: .center, lift: 8 * abs(spoon)
                )
                // The same grain as the picture's steam, seen through the moving shape.
                placed(Image("SplashSteamGrain"), in: Self.grainFrame, scale: scale)
                    // A moved view keeps its old place for layout, so the mask starts at the drawing's corner as it is.
                    .mask(alignment: .topLeading) {
                        Steam(time: time, scale: scale, origin: Self.art.origin)
                            .frame(width: Self.art.width * scale, height: Self.art.height * scale)
                    }
            }
        }
    }

    /// An image at its place in the drawing, turned by `angle` degrees about a point of it and raised by `lift`.
    private func placed(
        _ image: Image, in frame: CGRect, scale: CGFloat,
        angle: Double = 0, about anchor: UnitPoint = .center, lift: CGFloat = 0
    ) -> some View {
        image
            .resizable()
            .frame(width: frame.width * scale, height: frame.height * scale)
            .rotationEffect(.degrees(angle), anchor: anchor)
            .offset(x: (frame.minX - Self.art.minX) * scale, y: (frame.minY - Self.art.minY - lift) * scale)
    }

    /// When the one shake starts, and how long it lasts, in seconds.
    private static let shakeStart = 0.8
    private static let shakeLength = 0.45

    /// From -1 to 1: three quick swings that die away during the shake, and 0 before and after it.
    static func shake(at time: Double) -> Double {
        let along = (time - shakeStart) / shakeLength
        return along > 0 && along < 1 ? sin(along * 6 * .pi) * (1 - along) : 0
    }
}

/// The steam at one moment: a soft column whose bulges travel upward as it sways, and small puffs that
/// break off its top, grow and fade.
private struct Steam: View {
    let time: Double
    let scale: CGFloat
    let origin: CGPoint

    /// The middle of the column from the pot upward, and half its width there, as in the picture.
    private static let spine: [(x: Double, y: Double, half: Double)] = [
        (240, 408, 36), (228, 362, 30), (247, 300, 50), (248, 237, 38), (292, 176, 72), (308, 125, 78),
    ]

    /// How much the column's corners are rounded, in the picture's points.
    private static let rounding: CGFloat = 13

    var body: some View {
        Canvas { context, _ in
            // It rises out of the pot at the start.
            let risen = min(1, 0.25 + time / 0.9)

            // Where the column bends tightly its outline would come to a point, so the column is blurred and
            // then cut back to a firm edge, which rounds every corner, in or out. Filters work last one first:
            // blur, cut, and a hair of blur so the edge is not jagged.
            context.drawLayer { edge in
                edge.addFilter(.blur(radius: 0.5))
                edge.drawLayer { cut in
                    cut.addFilter(.alphaThreshold(min: 0.5, color: .black))
                    cut.addFilter(.blur(radius: Self.rounding * scale))
                    cut.drawLayer { shape in
                        place(&shape)
                        for part in column(risen: risen) { shape.fill(part, with: .color(.black)) }
                    }
                }
            }

            place(&context)

            for puff in 0..<2 {
                // How far along its short life this puff is, 0 to 1.
                let age = (time / 1.9 + Double(puff) * 0.5).truncatingRemainder(dividingBy: 1)
                let side = puff == 0 ? 1.0 : -1.0
                let center = CGPoint(
                    // Up and off the top of the column, one to each side.
                    x: 312 + side * 62 * age + 18 * sin(age * 5),
                    y: 96 - 112 * age
                )
                var faded = context
                faded.opacity = sin(.pi * age) * (risen >= 1 ? 0.9 : 0)
                faded.fill(blob(at: center, radius: 34 - 10 * age, wobble: time * 3 + Double(puff)), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
    }

    /// From the picture's points to the view's.
    private func place(_ context: inout GraphicsContext) {
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -origin.x, y: -origin.y)
    }

    private func column(risen: Double) -> [Path] {
        let count = 36
        var middle: [CGPoint] = []
        var halves: [Double] = []
        for index in 0...count {
            let up = Double(index) / Double(count)  // 0 at the pot, 1 at the top
            let point = Self.sample(up * risen)
            // Higher up it moves more.
            let sway = (6 + 22 * up) * sin(2 * .pi * (up * 1.1 - time * 0.55)) * up
            let swell = 1 + 0.26 * sin(2 * .pi * (up * 1.7 - time * 0.75)) + 0.1 * sin(2 * .pi * (up * 3.1 - time * 1.1))
            middle.append(CGPoint(x: point.x + sway, y: point.y + 6 * sin(time * 2.2 + up * 4) * up))
            halves.append(point.half * swell)
        }
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for index in 0...count {
            let before = middle[max(index - 1, 0)], after = middle[min(index + 1, count)]
            let dx = after.x - before.x, dy = after.y - before.y
            let length = max(hypot(dx, dy), 0.001)
            let across = CGVector(dx: -dy / length * halves[index], dy: dx / length * halves[index])
            left.append(CGPoint(x: middle[index].x + across.dx, y: middle[index].y + across.dy))
            right.append(CGPoint(x: middle[index].x - across.dx, y: middle[index].y - across.dy))
        }
        // The sides, then a round end at the bottom and at the top.
        let ends = [0, count].map { end in
            let radius = halves[end] * 0.98
            return Path(ellipseIn: CGRect(x: middle[end].x - radius, y: middle[end].y - radius, width: radius * 2, height: radius * 2))
        }
        return [Self.smooth(left + right.reversed())] + ends
    }

    /// The spine at a point along it, 0 to 1, curving smoothly through its marks.
    private static func sample(_ along: Double) -> (x: Double, y: Double, half: Double) {
        let position = along * Double(spine.count - 1)
        let i = min(Int(position), spine.count - 2)
        let t = position - Double(i)
        func curve(_ value: (Int) -> Double) -> Double {
            let a = value(max(i - 1, 0)), b = value(i), c = value(i + 1), d = value(min(i + 2, spine.count - 1))
            return 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
        }
        return (curve { spine[$0].x }, curve { spine[$0].y }, curve { spine[$0].half })
    }

    /// A closed shape rounded through the middles of its sides.
    private static func smooth(_ points: [CGPoint]) -> Path {
        func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var path = Path()
        path.move(to: middle(points[points.count - 1], points[0]))
        for index in points.indices {
            path.addQuadCurve(to: middle(points[index], points[(index + 1) % points.count]), control: points[index])
        }
        path.closeSubpath()
        return path
    }

    /// A small uneven round puff.
    private func blob(at center: CGPoint, radius: Double, wobble: Double) -> Path {
        Self.smooth((0..<10).map { index in
            let angle = Double(index) / 10 * 2 * .pi
            let r = radius * (1 + 0.2 * sin(angle * 3 + wobble))
            return CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
        })
    }
}

#Preview {
    SplashView(onDone: {})
}
