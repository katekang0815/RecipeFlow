//
//  StepRow.swift
//  RecipeFlow
//

import SwiftUI

/// One card in the cooking flow: icon, numbered title and instructions, joined to the
/// next card by a vertical connector.
struct StepRow: View {
    @Bindable var step: Step
    let number: Int
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                IconPicker(iconName: $step.iconName, options: IconCatalog.stepIcons)
                if !isLast {
                    Rectangle()
                        .fill(Color.orange.opacity(0.5))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(number).").font(.headline).foregroundStyle(.secondary)
                    TextField("Step title", text: $step.title)
                        .font(.headline)
                }
                TextField("Instructions", text: $step.detail, axis: .vertical)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
        .padding(.top, 8)
    }
}
