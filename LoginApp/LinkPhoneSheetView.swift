//
//  LinkPhoneSheetView.swift
//  LoginApp
//
//  Verify & link phone to account so user can use phone for login and password reset.
//

import SwiftUI

struct LinkPhoneSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: FirebaseAuthStore
    let phone: String
    let onSuccess: () -> Void
    
    @State private var code: String = ""
    @State private var resendCooldown = 0
    
    private var phoneDigits: String {
        phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }
    
    private var canSendCode: Bool {
        phoneDigits.count >= 10
    }
    
    private var canVerify: Bool {
        code.count == 6
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Link phone number")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("We'll send a 6-digit code to \(phone). After verifying, you can use this number to sign in and reset your password.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if auth.phoneVerificationID == nil {
                    Button("Send verification code") {
                        Task {
                            await auth.sendPhoneOTP(phone: phone)
                            if auth.errorMessage == nil { startCooldown() }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSendCode ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!canSendCode || auth.isLoading)
                } else {
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
                            code = filtered.count <= 6 ? filtered : String(filtered.prefix(6))
                        }
                    
                    if resendCooldown > 0 {
                        Text("Resend code in \(resendCooldown)s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Button("Resend code") {
                            Task {
                                await auth.sendPhoneOTP(phone: phone)
                                if auth.errorMessage == nil { startCooldown() }
                            }
                        }
                        .disabled(auth.isLoading)
                    }
                    
                    Button("Verify & link") {
                        Task {
                            await auth.verifyAndLinkPhoneOTP(code: code)
                            if auth.errorMessage == nil {
                                onSuccess()
                                dismiss()
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canVerify ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(!canVerify || auth.isLoading)
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
                
                Spacer()
            }
            .padding()
            .navigationTitle("Verify phone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        auth.phoneVerificationID = nil
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            auth.phoneVerificationID = nil
        }
    }
    
    private func startCooldown() {
        resendCooldown = 60
        Task { @MainActor in
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if resendCooldown > 0 { resendCooldown -= 1 }
            }
        }
    }
}
