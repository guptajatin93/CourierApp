//
//  ForgotPasswordView.swift
//  LoginApp
//
//  Password reset: by email (link) or by phone (OTP then set new password).
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: FirebaseAuthStore
    
    enum Step {
        case chooseMethod   // Email or Phone
        case emailSent      // We sent email
        case phoneEnter     // Enter phone, send OTP
        case phoneOTP       // Enter OTP
        case newPassword    // Set new password (after phone OTP sign-in)
    }
    
    @State private var step: Step = .chooseMethod
    @State private var emailInput: String = ""
    @State private var phoneInput: String = ""
    @State private var otpCode: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    
    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .chooseMethod:
                    chooseMethodView
                case .emailSent:
                    emailSentView
                case .phoneEnter:
                    phoneEnterView
                case .phoneOTP:
                    phoneOTPView
                case .newPassword:
                    newPasswordView
                }
            }
            .navigationTitle("Reset password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var chooseMethodView: some View {
        VStack(spacing: 24) {
            Text("How do you want to reset your password?")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Your email", text: $emailInput)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                Button("Send reset link") {
                    Task {
                        await auth.sendPasswordResetEmail(email: emailInput)
                        if auth.errorMessage == nil { step = .emailSent }
                    }
                }
                .disabled(emailInput.isEmpty || !emailInput.contains("@") || auth.isLoading)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            Text("— or —")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Phone (Canadian)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Your phone number", text: $phoneInput)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                Button("Send verification code") {
                    Task {
                        await auth.sendPhoneOTP(phone: phoneInput)
                        if auth.errorMessage == nil { step = .phoneOTP }
                    }
                }
                .disabled(phoneInput.count < 10 || auth.isLoading)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            if let msg = auth.errorMessage {
                Text(msg).font(.caption).foregroundColor(.red)
            }
            if auth.isLoading { ProgressView() }
        }
        .padding()
    }
    
    private var emailSentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            Text("Check your email")
                .font(.title2)
                .fontWeight(.semibold)
            Text("We sent a password reset link to \(emailInput). Tap the link in that email to set a new password.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
        }
        .padding()
    }
    
    private var phoneOTPView: some View {
        OTPVerificationView(
            auth: auth,
            context: .passwordResetPhone,
            email: nil,
            phone: phoneInput,
            onVerified: { step = .newPassword }
        )
    }
    
    private var phoneEnterView: some View {
        EmptyView()
    }
    
    private var newPasswordView: some View {
        VStack(spacing: 20) {
            Text("Set new password")
                .font(.title2)
                .fontWeight(.semibold)
            SecureField("New password (min 6 chars)", text: $newPassword)
                .textContentType(.newPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            SecureField("Confirm password", text: $confirmPassword)
                .textContentType(.newPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            Button("Update password") {
                Task {
                    guard newPassword.count >= 6, newPassword == confirmPassword else {
                        auth.errorMessage = "Password must be at least 6 characters and match."
                        return
                    }
                    await auth.updatePassword(newPassword: newPassword)
                    if auth.errorMessage == nil { dismiss() }
                }
            }
            .disabled(newPassword.count < 6 || newPassword != confirmPassword || auth.isLoading)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
            if let msg = auth.errorMessage {
                Text(msg).font(.caption).foregroundColor(.red)
            }
            if auth.isLoading { ProgressView() }
        }
        .padding()
    }
}
