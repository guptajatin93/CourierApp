//
//  SignUpVerificationFlowView.swift
//  LoginApp
//
//  Shown after sign-up (from ContentView) to verify email then phone via OTP.
//

import SwiftUI

struct SignUpVerificationFlowView: View {
    @ObservedObject var auth: FirebaseAuthStore
    let email: String
    let phone: String
    let onComplete: () -> Void
    
    @State private var emailVerified = false
    @State private var phoneOTPSent = false
    @State private var phoneVerified = false
    
    var body: some View {
        NavigationStack {
            Group {
                if !emailVerified {
                    emailStep
                } else if !phoneVerified && !phoneOTPSent {
                    phoneSendStep
                } else {
                    phoneOTPStep
                }
            }
            .navigationTitle("Verify your account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip for now") {
                        onComplete()
                    }
                }
            }
        }
    }
    
    private var emailStep: some View {
        OTPVerificationView(
            auth: auth,
            context: .signUpEmail,
            email: email,
            phone: nil,
            onVerified: { emailVerified = true }
        )
    }
    
    private var phoneSendStep: some View {
        VStack(spacing: 20) {
            Text("Verify your phone")
                .font(.title2)
                .fontWeight(.semibold)
            Text("We'll send a 6-digit code to \(phone). You can use it to sign in or reset your password later.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Send code") {
                Task {
                    await auth.sendPhoneOTP(phone: phone)
                    if auth.errorMessage == nil { phoneOTPSent = true }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .disabled(auth.isLoading)
            if let msg = auth.errorMessage {
                Text(msg).font(.caption).foregroundColor(.red)
            }
            if auth.isLoading { ProgressView() }
        }
        .padding()
    }
    
    private var phoneOTPStep: some View {
        OTPVerificationView(
            auth: auth,
            context: .signUpPhone,
            email: nil,
            phone: phone,
            onVerified: {
                phoneVerified = true
                onComplete()
            },
            onSkip: { onComplete() }
        )
    }
}
