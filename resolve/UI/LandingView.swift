import SwiftUI

struct LandingView: View {
    @EnvironmentObject private var authManager: AuthManager

    enum LandingStep {
        case welcome
        case authChoice
        case name
        case email
    }

    enum AuthChoiceMode {
        case signUp
        case signIn
    }

    private let FEATURE_FLAG_enableManualAuth = false
    
    @State private var step: LandingStep = .welcome
    @State private var authChoiceMode: AuthChoiceMode = .signUp
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var birthDay = ""
    @State private var birthMonth = ""
    @State private var birthYear = ""
    @State private var showEmailField = false
    @State private var showPasswordFields = false
    @State private var showDateOfBirthFields = false
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var attemptedContinue = false
    
    private let cardWidth: CGFloat = 520
    private let welcomeHeight: CGFloat = 540
    private let authChoiceHeight: CGFloat = 320
    private let nameOnlyHeight: CGFloat = 280
    private let nameWithEmailHeight: CGFloat = 360
    private let nameWithEmailAndPasswordHeight: CGFloat = 460
    private let nameWithAllFieldsHeight: CGFloat = 520
    private let emailHeight: CGFloat = 280
    
    private var currentHeight: CGFloat {
        switch step {
        case .welcome: return welcomeHeight
        case .authChoice: return authChoiceHeight
        case .name:
            if !FEATURE_FLAG_enableManualAuth {
                return authChoiceHeight
            }
            if showDateOfBirthFields {
                return nameWithAllFieldsHeight
            } else if showPasswordFields {
                return nameWithEmailAndPasswordHeight
            } else if showEmailField {
                return nameWithEmailHeight
            } else {
                return nameOnlyHeight
            }
        case .email:
            if !FEATURE_FLAG_enableManualAuth {
                return authChoiceHeight
            }
            return emailHeight
        }
    }
    
    // Validation helpers
    private var canProceedFromName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var canProceedFromEmail: Bool {
        isValidEmail(email)
    }
    
    private var canProceedFromPassword: Bool {
        !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
    }
    
    private var canProceedFromDateOfBirth: Bool {
        !birthDay.isEmpty && !birthMonth.isEmpty && !birthYear.isEmpty &&
        birthDay.count == 2 && birthMonth.count == 2 && birthYear.count == 4
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        return emailPredicate.evaluate(with: email)
    }
    
    private var canContinue: Bool {
        if showDateOfBirthFields {
            return canProceedFromDateOfBirth && canProceedFromPassword
        } else if showPasswordFields {
            return canProceedFromPassword
        } else if showEmailField {
            return canProceedFromEmail
        } else {
            return canProceedFromName
        }
    }
    
    private var passwordsMatch: Bool {
        password == confirmPassword
    }

    private var isSignUpChoice: Bool {
        authChoiceMode == .signUp
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
            
            ZStack {
                if step == .welcome {
                    welcomeContent
                        .transition(.opacity.combined(with: .offset(y: -10)))
                }
                
                if step == .authChoice {
                    authChoiceContent
                        .transition(.opacity.combined(with: .offset(y: 10)))
                }
                
                if FEATURE_FLAG_enableManualAuth && step == .name {
                    nameContent
                        .transition(.opacity.combined(with: .offset(y: 10)))
                }
                
                if FEATURE_FLAG_enableManualAuth && step == .email {
                    emailContent
                        .transition(.opacity.combined(with: .offset(y: 10)))
                }
            }
            .padding(40)
        }
        .frame(width: cardWidth, height: currentHeight)
        .animation(.easeInOut(duration: 0.28), value: step)
    }
    
    // MARK: - Welcome Content
    
    private var welcomeContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Hero section
            heroSection
            
            // Explanation section
            explanationSection
            
            // CTA section
            ctaSection
            
            Spacer()
        }
    }
    
    // MARK: - Auth Choice Content
    
    private var authChoiceContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    step = .welcome
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                
                Spacer()
            }
            .padding(.bottom, 12)
            
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(isSignUpChoice ? "Get started" : "Continue")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(isSignUpChoice
                        ? "Create an account to sync your history and manage your plan."
                        : "Sign in to sync history and manage your plan."
                    )
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    // Sign in with Apple button
                    Button {
                        if isSignUpChoice {
                            print("Apple sign-up pressed")
                        } else {
                            print("Apple sign-in pressed")
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(isSignUpChoice ? "Sign up with Apple" : "Sign in with Apple")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    
                    if FEATURE_FLAG_enableManualAuth {
                        // Manual button
                        Button {
                            if isSignUpChoice {
                                step = .name
                            } else {
                                // No action for now
                            }
                        } label: {
                            Text(isSignUpChoice ? "Create an account manually" : "Sign in manually")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        
                        // Tertiary link
                        Button {
                            authChoiceMode = isSignUpChoice ? .signIn : .signUp
                        } label: {
                            Text(isSignUpChoice ? "I already have an account" : "I don't have an account")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .frame(width: 300)
            }
        }
    }
    
    // MARK: - Name Content
    
    private var nameContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    step = .welcome
                    showEmailField = false
                    showPasswordFields = false
                    showDateOfBirthFields = false
                    showPassword = false
                    showConfirmPassword = false
                    attemptedContinue = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                
                Spacer()
            }
            
            VStack(spacing: 20) {
                Text(showDateOfBirthFields ? "What's your date of birth?" : (showPasswordFields ? "Create a password" : (showEmailField ? "What's your email?" : "Enter your name")))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
                    .animation(.easeInOut(duration: 0.28), value: showEmailField)
                    .animation(.easeInOut(duration: 0.28), value: showPasswordFields)
                    .animation(.easeInOut(duration: 0.28), value: showDateOfBirthFields)
                
                // Name and email input fields
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        // First name field
                        TextField("First name", text: $firstName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(
                                        attemptedContinue && firstName.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? Color.red.opacity(0.5)
                                            : Color.white.opacity(0.10),
                                        lineWidth: 1
                                    )
                            )
                        
                        // Last name field
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .regular))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(
                                        attemptedContinue && lastName.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? Color.red.opacity(0.5)
                                            : Color.white.opacity(0.10),
                                        lineWidth: 1
                                    )
                            )
                    }
                    
                    // Email field (shown after first continue)
                    if showEmailField {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            
                            TextField("you@example.com", text: $email)
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
                                    attemptedContinue && !canProceedFromEmail
                                        ? Color.red.opacity(0.5)
                                        : Color.white.opacity(0.10),
                                    lineWidth: 1
                                )
                        )
                        .transition(.opacity.combined(with: .offset(y: -10)))
                    }
                    
                    // Password fields (shown after second continue)
                    if showPasswordFields {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, weight: .regular))
                                } else {
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, weight: .regular))
                                }
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
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
                                        attemptedContinue && password.isEmpty
                                            ? Color.red.opacity(0.5)
                                            : Color.white.opacity(0.10),
                                        lineWidth: 1
                                    )
                            )
                            
                            HStack(spacing: 10) {
                                Image(systemName: "lock")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                
                                if showConfirmPassword {
                                    TextField("Confirm password", text: $confirmPassword)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, weight: .regular))
                                } else {
                                    SecureField("Confirm password", text: $confirmPassword)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 14, weight: .regular))
                                }
                                
                                // Info icon when passwords don't match
                                if !confirmPassword.isEmpty && !passwordsMatch {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.red.opacity(0.8))
                                        .help("Passwords don't match")
                                }
                                
                                Button {
                                    showConfirmPassword.toggle()
                                } label: {
                                    Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
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
                                        attemptedContinue && (confirmPassword.isEmpty || !passwordsMatch)
                                            ? Color.red.opacity(0.5)
                                            : Color.white.opacity(0.10),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .transition(.opacity.combined(with: .offset(y: -10)))
                    }
                    
                    // Date of birth fields (shown after password fields)
                    if showDateOfBirthFields {
                        HStack(spacing: 10) {
                            // Day
                            TextField("DD", text: $birthDay)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .regular))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(
                                        attemptedContinue && (birthDay.isEmpty || birthDay.count != 2)
                                            ? Color.red.opacity(0.5)
                                            : Color.white.opacity(0.10),
                                        lineWidth: 1
                                    )
                                )
                                .onChange(of: birthDay) { oldValue, newValue in
                                    if newValue.count > 2 {
                                        birthDay = String(newValue.prefix(2))
                                    }
                                }
                            
                            // Month
                            TextField("MM", text: $birthMonth)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .regular))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(
                                            attemptedContinue && (birthMonth.isEmpty || birthMonth.count != 2)
                                                ? Color.red.opacity(0.5)
                                                : Color.white.opacity(0.10),
                                            lineWidth: 1
                                        )
                                )
                                .onChange(of: birthMonth) { oldValue, newValue in
                                    if newValue.count > 2 {
                                        birthMonth = String(newValue.prefix(2))
                                    }
                                }
                            
                            // Year
                            TextField("YYYY", text: $birthYear)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .regular))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(
                                            attemptedContinue && (birthYear.isEmpty || birthYear.count != 4)
                                                ? Color.red.opacity(0.5)
                                                : Color.white.opacity(0.10),
                                            lineWidth: 1
                                        )
                                )
                                .onChange(of: birthYear) { oldValue, newValue in
                                    if newValue.count > 4 {
                                        birthYear = String(newValue.prefix(4))
                                    }
                                }
                        }
                        .transition(.opacity.combined(with: .offset(y: -10)))
                    }
                    
                    // Continue button
                    Button {
                        if canContinue {
                            attemptedContinue = false
                            if showDateOfBirthFields {
                                print("Sign up completed: \(firstName) \(lastName) - \(email) - DOB: \(birthDay)/\(birthMonth)/\(birthYear)")
                            } else if showPasswordFields {
                                showDateOfBirthFields = true
                            } else if showEmailField {
                                showPasswordFields = true
                            } else {
                                showEmailField = true
                            }
                        } else {
                            attemptedContinue = true
                        }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(canContinue ? 0.12 : 0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(canContinue ? 0.15 : 0.08), lineWidth: 1)
                    )
                    .opacity(canContinue ? 1.0 : 0.5)
                }
                .frame(width: 360)
            }
        }
    }
    
    // MARK: - Email Content
    
    private var emailContent: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    step = .welcome
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                
                Spacer()
            }
            
            VStack(spacing: 20) {
                Text("Enter your email")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.primary)
                
                // Email input and button
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        
                        TextField("you@example.com", text: $email)
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
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    
                    // Continue button
                    Button {
                        print("Continue tapped with email: \(email)")
                    } label: {
                        Text("Continue")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .frame(width: 320)
            }
        }
    }
    
    // MARK: - Welcome Sections
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("Resolve")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("High-confidence answers under time pressure.")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var explanationSection: some View {
        Text("Resolve compares reasoning from multiple AI models, shows where they agree or disagree, and helps you decide when it matters most.")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.secondary.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: 420)
    }
    
    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                authManager.startSignIn()
            } label: {
                Text("Continue with Google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .frame(width: 280)
        }
    }
}

#Preview {
    LandingView()
    .environmentObject(AuthManager.shared)
        .preferredColorScheme(.dark)
}
