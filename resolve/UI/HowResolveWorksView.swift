import SwiftUI

struct HowResolveWorksView: View {
    let onBack: () -> Void
    private let cardWidth: CGFloat = 520
    private let cardCornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(radius: 16)
                .frame(width: cardWidth)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Text("How Resolve Works")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("You ask a question")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Enter a prompt just as you would in any AI tool.")
                            Text("It can be analytical, strategic, technical, or open-ended.")
                            Text("Resolve sends the exact same prompt to multiple AI models.")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Multiple models respond independently")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Each model generates its own answer.")
                            Text("There is no blending or rewriting at this stage.")
                            Text("You can review each response directly.")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("The Arbiter compares reasoning")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Resolve analyzes the responses side by side.")
                            Text("If there is disagreement between the advocates, then the Arbiter performs a deeper comparison.")
                            Text("It looks for:")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Areas of agreement")
                            Text("• Meaningful disagreement")
                            Text("• Differences in assumptions")
                            Text("• Gaps or blind spots")
                            Text("• Strength of reasoning")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("If the advocates largely agree, the synthesis remains concise.")
                            Text("If they diverge, the analysis focuses on where and why the reasoning differs.")
                            Text("The goal is not to average answers, but to understand how they align — and where they do not.")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("A distilled summary is produced")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("The Arbiter generates a concise synthesis that highlights:")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("• What most models agree on")
                            Text("• Where they diverge")
                            Text("• The strongest reasoning paths")
                            Text("• Remaining uncertainty")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                        Text("This reduces noise and makes comparison easier.")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("You make the decision")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Resolve does not replace judgment.")
                            Text("It helps you see structured reasoning across multiple systems so you can make a more informed decision.")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                    }
                }
                .padding(.top, 24)
                .padding(.bottom, 22)
                .padding(.horizontal, 22)
                .frame(width: cardWidth, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        }
    }
}
