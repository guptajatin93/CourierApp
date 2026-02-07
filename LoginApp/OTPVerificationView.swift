//
//  OTPVerificationView.swift
//  LoginApp
//
//  Reusable OTP entry: used after signup (email link + phone code) and for password reset.
//

import SwiftUI

enum OTPContext {
    case signUpEmail      // Waiting for user to tap email link
    case signUpPhone      // User enters SMS code
    case passwordResetPhone  // User enters SMS code to then set new password
}

struct OTPVerificationView: View {
    @ObservedObject var auth: FirebaseAuthStore
    let context: OTPContext
    let email: String?
    let phone: String?
    let onVerified: () -> Void
    let onSkip: (() -> Void)?
    
    @State private var code: String = ""
    @State private var resendCooldown = 0
    
    init(auth: FirebaseAuthStore, context: OTPContext, email: String? = nil, phone: String? = nil, onVerified: @escaping () -> Void, onSkip: (() -> Void)? = nil) {
        self.auth = auth
        self.context = context
        self.email = email
        self.phone = phone
        self.onVerified = onVerified
        self.onSkip = onSkip
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text(titleText)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(subtitleText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if context == .signUpPhone || context == .passwordResetPhone {
                TextField("Enter 6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .onChange(of: code) { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count <= 6 {
                            code = filtered
                        } else {
                            code = String(filtered.prefix(6))
                        }
                    }
                
                if resendCooldown > 0 {
                    Text("Resend code in \(resendCooldown)s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("Resend code") {
                        Task { await resendOTP() }
                    }
                    .disabled(auth.isLoading)
                }
                
                Button("Verify") {
                    Task { await verifyOTP() }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canVerify ? Color.blue : Color.gray)
                .cornerRadius(10)
                .disabled(!canVerify || auth.isLoading)
            }
            
            if context == .signUpEmail {
                Button("I've verified my email") {
                    Task { await checkEmailVerified() }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .disabled(auth.isLoading)
                
                Button("Resend verification email") {
                    Task { await auth.sendEmailVerification() }
                }
                .disabled(auth.isLoading)
            }
            
            if let skip = onSkip, context == .signUpPhone {
                Button("Skip for now") { skip() }
                    .foregroundColor(.secondary)
            }
            
            if let msg = auth.errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            if auth.isLoading {
                ProgressView()
            }
        }
        .padding()
        .onAppear {
            if context == .signUpPhone || context == .passwordResetPhone {
                startCooldown()
            }
        }
    }
    
    private var titleText: String {
        switch context {
        case .signUpEmail: return "Verify your email"
        case .signUpPhone: return "Verify your phone"
        case .passwordResetPhone: return "Enter verification code"
        }
    }
    
    private var subtitleText: String {
        switch context {
        case .signUpEmail:
            return "We sent a link to \(email ?? ""). Tap the link in that email, then come back here and tap below."
        case .signUpPhone:
            return "Enter the 6-digit code sent to \(phone ?? "")."
        case .passwordResetPhone:
            return "Enter the code we sent to \(phone ?? "")."
        }
    }
    
    private var canVerify: Bool {
        code.count == 6
    }
    
    private func resendOTP() async {
        guard let phone = phone else { return }
        await auth.sendPhoneOTP(phone: phone)
        startCooldown()
    }
    
    private func verifyOTP() async {
        if context == .signUpPhone {
            await auth.verifyAndLinkPhoneOTP(code: code)
            if auth.errorMessage == nil {
                onVerified()
            }
        } else if context == .passwordResetPhone {
            guard let vid = auth.phoneVerificationID else {
                auth.errorMessage = "Please request a new code."
                return
            }
            await auth.signInWithPhoneOTP(verificationID: vid, code: code)
            if auth.errorMessage == nil {
                onVerified()
            }
        }
    }
    
    private func checkEmailVerified() async {
        await auth.reloadUserEmailVerification()
        if auth.isEmailVerified {
            onVerified()
        } else {
            auth.errorMessage = "Email not verified yet. Check your inbox and tap the link."
        }
    }
    
    private func startCooldown() {
        resendCooldown = 60
        Task { @MainActor in
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if resendCooldown > 0 {
                    resendCooldown -= 1
                }
            }
        }
    }
}
