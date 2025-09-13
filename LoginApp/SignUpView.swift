//
//  SignUpView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-09-12.
//


import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var auth: AuthStore

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agree = false
    @State private var error: String?

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

                Section {
                    Toggle("I agree to Terms & Privacy", isOn: $agree)
                }

                if let e = error {
                    Section {
                        Text(e).foregroundColor(.red)
                    }
                }

                Section {
                    Button("Create Account") {
                        submit()
                    }
                    .disabled(!canSubmit)
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

    private func submit() {
        error = nil
        guard canSubmit else { return }
        do {
            try auth.register(fullName: fullName, email: email, phone: phone, password: password)
            dismiss()
        } catch {
            self.error = (error as NSError).localizedDescription
        }
    }
}
