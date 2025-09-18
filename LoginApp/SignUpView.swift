//
//  SignUpView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-12.
//


import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: FirebaseAuthStore

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agree = false
    @State private var selectedRole: UserRole = .user

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Info") {
                    TextField("Full name", text: $fullName)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("Password") {
                    SecureField("Password (min 6 chars)", text: $password)
                    SecureField("Confirm password", text: $confirmPassword)
                }
                
                Section("Account Type") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(UserRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("I agree to Terms & Privacy", isOn: $agree)
                }

                if let errorMessage = auth.errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red)
                    }
                }

                Section {
                    Button("Create Account") {
                        Task {
                            await submit()
                        }
                    }
                    .disabled(!canSubmit || auth.isLoading)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var canSubmit: Bool {
        !fullName.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword &&
        agree
    }

    private func submit() async {
        guard canSubmit else { return }
        await auth.signUp(email: email, password: password, fullName: fullName, phone: phone, role: selectedRole)
        if auth.currentUser != nil {
            dismiss()
        }
    }
}
