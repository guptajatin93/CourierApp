//
//  DeliveryConfirmationView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import SwiftUI
import FirebaseStorage

struct DeliveryConfirmationView: View {
    let order: Order
    let onConfirm: (String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImage: UIImage?
    @State private var deliveryNotes = ""
    @State private var isUploading = false
    @State private var showImagePicker = false
    @State private var showActionSheet = false
    @State private var errorMessage: String?
    
    // Detect if running in simulator
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Order Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery Confirmation")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Order: \(order.pickup) → \(order.dropoff)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Customer: \(order.userId.suffix(6))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Photo Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery Photo")
                            .font(.headline)
                        
                        if let image = selectedImage {
                            VStack(spacing: 12) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                                
                                HStack {
                                    Button("Retake Photo") {
                                        showActionSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Spacer()
                                    
                                    Button("Remove Photo") {
                                        selectedImage = nil
                                    }
                                    .buttonStyle(.bordered)
                                    .foregroundColor(.red)
                                }
                            }
                        } else {
                            Button(action: {
                                showActionSheet = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                    
                                    Text("Take Delivery Photo")
                                        .font(.headline)
                                    
                                    Text("Required for delivery confirmation")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(40)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    // Delivery Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery Notes (Optional)")
                            .font(.headline)
                        
                        TextField("Add any notes about the delivery...", text: $deliveryNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Confirm Delivery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        confirmDelivery()
                    }
                    .disabled(selectedImage == nil || isUploading)
                }
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Select Photo Source"),
                buttons: [
                    .default(Text("Camera")) {
                        showImagePicker = true
                    },
                    .default(Text("Photo Library")) {
                        showImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: isSimulator ? .photoLibrary : .camera)
        }
    }
    
    private func confirmDelivery() {
        guard let image = selectedImage else { return }
        
        isUploading = true
        errorMessage = nil
        
        Task {
            do {
                let photoURL = try await uploadDeliveryPhoto(image)
                await MainActor.run {
                    onConfirm(photoURL, deliveryNotes.isEmpty ? nil : deliveryNotes)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }
    
    private func uploadDeliveryPhoto(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImagePicker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        
        let fileName = "delivery_\(order.id ?? UUID().uuidString)_\(Date().timeIntervalSince1970).jpg"
        let deliveryPhotosRef = storageRef.child("delivery_photos/\(fileName)")
        
        let _ = try await deliveryPhotosRef.putDataAsync(imageData)
        let downloadURL = try await deliveryPhotosRef.downloadURL()
        
        return downloadURL.absoluteString
    }
}
