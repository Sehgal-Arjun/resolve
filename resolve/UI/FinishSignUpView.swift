import SwiftUI

struct FinishSignUpView: View {
    @EnvironmentObject private var authManager: AuthManager

    private enum DetailsStep: Equatable {
        case phone
        case password
    }

    private struct CountryDialCode: Identifiable, Hashable {
        let id: String
        let name: String
        let dialCode: String // includes leading +

        init(name: String, dialCode: String) {
            self.name = name
            self.dialCode = dialCode
            self.id = "\(name)|\(dialCode)"
        }

        var digitsOnly: String {
            dialCode.replacingOccurrences(of: "+", with: "")
        }
    }

    @State private var detailsStep: DetailsStep = .phone

    @State private var selectedCountry: CountryDialCode = CountryDialCode(name: "United States", dialCode: "+1")
    @State private var nationalNumber = ""
    @State private var password = ""
    @State private var phoneCode = ""
    @State private var attemptedContinue = false

    private let cardWidth: CGFloat = 520
    private var cardHeight: CGFloat {
        switch stateKind {
        case .details:
            return detailsStep == .phone ? 360 : 430
        case .phoneCode:
            return 360
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10))
                )
                .shadow(radius: 16)

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 18)

                VStack(spacing: 12) {
                    switch stateKind {
                    case .details:
                        detailsFields
                        primaryDetailsButton
                    case .phoneCode:
                        phoneCodeFields
                        verifyCodeButton
                    }
                }

                if let footer = requirementsFooter {
                    Text(footer)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                }

                Spacer(minLength: 0)
            }
            .padding(40)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(width: cardWidth, height: cardHeight)
        .animation(.easeInOut(duration: 0.28), value: stateKind)
        .animation(.easeInOut(duration: 0.28), value: detailsStep)
        .onAppear {
            attemptedContinue = false
            syncDetailsStepFromState()
            applyPanelSize(animated: false)
        }
        .onChange(of: authManager.state) { oldValue, newValue in
            attemptedContinue = false

            if case .signUpNeedsDetails = newValue {
                if case .signUpNeedsDetails = oldValue {
                    // Staying in the same state; preserve the incremental step.
                } else {
                    detailsStep = .phone
                }
            }
            applyPanelSize(animated: true)
        }
        .onChange(of: detailsStep) { _, _ in
            applyPanelSize(animated: true)
        }
        .onChange(of: nationalNumber) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue {
                nationalNumber = filtered
            }
        }
    }

    private enum StateKind: Equatable {
        case details
        case phoneCode
    }

    private var stateKind: StateKind {
        switch authManager.state {
        case .signUpNeedsDetails:
            return .details
        case .signUpNeedsPhoneCode:
            return .phoneCode
        default:
            return .details
        }
    }

    private var title: String {
        switch stateKind {
        case .phoneCode:
            return "Enter the code"
        case .details:
            switch detailsStep {
            case .phone:
                return "What’s your phone number?"
            case .password:
                return "Create a password"
            }
        }
    }

    private var subtitle: String {
        switch stateKind {
        case .phoneCode:
            if let phone = requirements?.phoneNumber {
                return "We sent a text to \(phone)."
            }
            return "Enter the SMS code to verify your phone."
        case .details:
            switch detailsStep {
            case .phone:
                return "We’ll use this to verify your account."
            case .password:
                return "One more step to finish setting up your account."
            }
        }
    }

    private var requirementsFooter: String? {
        guard let req = requirements else { return nil }
        let missing = req.missingFields.joined(separator: ", ")
        let required = req.requiredFields.joined(separator: ", ")
        return "Missing: [\(missing)]. Required: [\(required)]."
    }

    private var requirements: AuthManager.SignUpRequirements? {
        switch authManager.state {
        case .signUpNeedsDetails(let req), .signUpNeedsPhoneCode(let req):
            return req
        default:
            return nil
        }
    }

    private var detailsFields: some View {
        VStack(spacing: 10) {
            phoneRow
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            attemptedContinue && !isPhoneValid
                                ? Color.red.opacity(0.5)
                                : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                )

            if detailsStep == .password {
                passwordRow
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                attemptedContinue && !isPasswordValid
                                    ? Color.red.opacity(0.5)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
                    .transition(.opacity.combined(with: .offset(y: -10)))
            }
        }
    }

    private var phoneRow: some View {
        HStack(spacing: 10) {
            Picker("Country", selection: $selectedCountry) {
                ForEach(countryDialCodes) { item in
                    Text("\(item.name) \(item.dialCode)").tag(item)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 170, alignment: .leading)

            TextField("Phone number", text: $nationalNumber)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var passwordRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            SecureField("Password (min 8 characters)", text: $password)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var primaryDetailsButton: some View {
        Button {
            attemptedContinue = true

            switch detailsStep {
            case .phone:
                guard isPhoneValid else { return }
                detailsStep = .password
                attemptedContinue = false
            case .password:
                guard isPhoneValid, isPasswordValid else { return }
                authManager.submitSignUpDetails(phoneNumber: e164PhoneNumber, password: password)
            }
        } label: {
            Text(detailsStep == .phone ? "Continue" : "Continue")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
        )
        .disabled(!canContinueDetails)
        .opacity(canContinueDetails ? 1.0 : 0.65)
    }

    private var phoneCodeFields: some View {
        HStack(spacing: 10) {
            Image(systemName: "message")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("SMS code", text: $phoneCode)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .regular))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    attemptedContinue && !isCodeValid
                        ? Color.red.opacity(0.5)
                        : Color.white.opacity(0.10),
                    lineWidth: 1
                )
        )
        .onChange(of: phoneCode) { _, newValue in
            let filtered = newValue.filter { $0.isNumber }
            if filtered != newValue {
                phoneCode = filtered
            }
        }
    }

    private var verifyCodeButton: some View {
        Button {
            attemptedContinue = true
            guard isCodeValid else { return }
            authManager.verifySignUpPhoneCode(phoneCode)
        } label: {
            Text("Verify")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
        )
        .disabled(!isCodeValid)
        .opacity(isCodeValid ? 1.0 : 0.65)
    }

    private var isPhoneValid: Bool {
        let digits = nationalNumber.filter { $0.isNumber }
        guard digits.count >= 4 else { return false }
        guard digits.count <= 14 else { return false }

        let combined = selectedCountry.digitsOnly + digits
        // E.164 max is 15 digits (excluding '+').
        guard combined.count <= 15 else { return false }
        // Avoid unrealistically short numbers.
        guard combined.count >= 7 else { return false }
        return true
    }

    private var e164PhoneNumber: String {
        "+" + selectedCountry.digitsOnly + nationalNumber.filter { $0.isNumber }
    }

    private var isPasswordValid: Bool {
        password.count >= 8
    }

    private var isCodeValid: Bool {
        let digits = phoneCode.filter { $0.isNumber }
        return (4...8).contains(digits.count)
    }

    private var canContinueDetails: Bool {
        switch detailsStep {
        case .phone:
            return isPhoneValid
        case .password:
            return isPhoneValid && isPasswordValid
        }
    }

    private func syncDetailsStepFromState() {
        if case .signUpNeedsDetails = authManager.state {
            detailsStep = .phone
        }
    }

    private func applyPanelSize(animated: Bool) {
        CommandPanelController.shared.setSize(width: cardWidth, height: cardHeight, animated: animated)
    }

    private var countryDialCodes: [CountryDialCode] {
        [
            CountryDialCode(name: "United States", dialCode: "+1"),
            CountryDialCode(name: "Canada", dialCode: "+1"),
            CountryDialCode(name: "United Kingdom", dialCode: "+44"),
            CountryDialCode(name: "Australia", dialCode: "+61"),
            CountryDialCode(name: "India", dialCode: "+91"),
            CountryDialCode(name: "Germany", dialCode: "+49"),
            CountryDialCode(name: "France", dialCode: "+33"),
            CountryDialCode(name: "Spain", dialCode: "+34"),
            CountryDialCode(name: "Netherlands", dialCode: "+31"),
            CountryDialCode(name: "Italy", dialCode: "+39"),
            CountryDialCode(name: "Sweden", dialCode: "+46"),
            CountryDialCode(name: "Switzerland", dialCode: "+41"),
            CountryDialCode(name: "Brazil", dialCode: "+55"),
            CountryDialCode(name: "Mexico", dialCode: "+52"),
            CountryDialCode(name: "Japan", dialCode: "+81"),
            CountryDialCode(name: "South Korea", dialCode: "+82"),
            CountryDialCode(name: "China", dialCode: "+86"),
            CountryDialCode(name: "Singapore", dialCode: "+65"),
            CountryDialCode(name: "New Zealand", dialCode: "+64"),
            CountryDialCode(name: "Ireland", dialCode: "+353")
        ]
    }
}
