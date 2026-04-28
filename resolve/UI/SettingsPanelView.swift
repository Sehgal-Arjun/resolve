import SwiftUI
import AppKit

struct SettingsPanelView: View {
    let onBack: () -> Void

    @ObservedObject private var settings = UserSettingsStore.shared
    @ObservedObject private var authManager = AuthManager.shared

    @State private var didCopyUserId = false

    private let panelWidth: CGFloat = 620
    private let panelHeight: CGFloat = 620
    private let cardWidth: CGFloat = 620
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

            VStack(alignment: .leading, spacing: 14) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        accountSection
                        defaultsSection
                        resolveSection
                        footerActions
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(22)
            .frame(width: cardWidth, height: panelHeight)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        }
        .frame(width: panelWidth, height: panelHeight)
        .onAppear {
            CommandPanelController.shared.setSize(width: panelWidth, height: panelHeight, animated: true)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )

            Text("Settings")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            if let user = authManager.currentUser {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsRow(
                        label: "Name",
                        value: user.name.isEmpty ? "—" : user.name
                    )
                    SettingsRow(
                        label: "Email",
                        value: user.email.isEmpty ? "—" : user.email
                    )

                    HStack(alignment: .center, spacing: 12) {
                        Text("User ID")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 110, alignment: .leading)

                        Text(user.id)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            copyUserId(user.id)
                        } label: {
                            Text(didCopyUserId ? "Copied" : "Copy")
                                .font(.system(size: 11.5, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    }
                }
            } else {
                Text("Not signed in.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func copyUserId(_ id: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(id, forType: .string)
        didCopyUserId = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didCopyUserId = false
        }
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
        SettingsSection(title: "Defaults") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default question mode")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $settings.defaultProblemType) {
                        Text("General").tag(ProblemType.generalQuestion)
                        Text("Single Select").tag(ProblemType.multipleChoiceSingle)
                        Text("Multi Select").tag(ProblemType.multipleChoiceMulti)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max resolve rounds")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("How many times you can press Resolve per question.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        Text("\(UserSettingsStore.freePlanResolveRounds)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)

                        Text("Free plan")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .opacity(0.6)
                    .help("Max resolve count is currently \(UserSettingsStore.freePlanResolveRounds) on the Free plan. Paid tiers will unlock more.")
                }
            }
        }
    }

    // MARK: - Resolve

    private var resolveSection: some View {
        SettingsSection(title: "Resolve") {
            VStack(alignment: .leading, spacing: 16) {
                advocateRosterRow
                arbiterToneRow
                stanceColorsRow
            }
        }
    }

    private var advocateRosterRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Active advocates")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text("\(settings.enabledAdvocates.count)/\(AdvocateProvider.allCases.count) on")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Text("At least \(UserSettingsStore.minimumActiveAdvocates) must be enabled. Disabled providers won't debate.")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                ForEach(AdvocateProvider.allCases) { provider in
                    AdvocateToggleRow(
                        provider: provider,
                        isEnabled: settings.enabledAdvocates.contains(provider),
                        canDisable: settings.enabledAdvocates.count > UserSettingsStore.minimumActiveAdvocates
                            || !settings.enabledAdvocates.contains(provider)
                    ) {
                        settings.toggle(provider)
                    }
                }
            }
        }
    }

    private var arbiterToneRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Arbiter tone")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("", selection: $settings.arbiterStyle) {
                ForEach(ArbiterStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(settings.arbiterStyle.helpText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
        }
    }

    private var stanceColorsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Stance colors")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Color advocate cards by which side they took.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $settings.showStanceColors)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 12) {
            Button {
                settings.resetToDefaults()
            } label: {
                Text("Reset to defaults")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )

            Spacer(minLength: 0)

            Button {
                authManager.signOut()
            } label: {
                Text("Sign out")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)

            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct SettingsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AdvocateToggleRow: View {
    let provider: AdvocateProvider
    let isEnabled: Bool
    let canDisable: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(provider.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Text("(\(provider.rawValue))")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .disabled(!canDisable)
            .opacity(canDisable ? 1.0 : 0.6)
        }
        .padding(.vertical, 4)
    }
}
