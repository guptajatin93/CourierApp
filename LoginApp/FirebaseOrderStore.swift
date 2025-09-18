//
//  FirebaseOrderStore.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import Foundation
import FirebaseAuth

@MainActor
final class FirebaseOrderStore: ObservableObject {
    @Published var orders: [Order] = []
    @Published var availableOrders: [Order] = []
    @Published var assignedOrders: [Order] = []
    @Published var completedOrders: [Order] = []
    @Published var allOrders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let firebaseService = FirebaseService.shared
    
    // Computed properties for statistics
    var totalEarnings: Double {
        completedOrders.reduce(0) { $0 + $1.cost }
    }
    
    var totalRevenue: Double {
        allOrders.filter { $0.status == .delivered }.reduce(0) { $0 + $1.cost }
    }
    
    init() {
        loadOrders()
    }
    
    func loadOrders() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            do {
                let fetchedOrders = try await firebaseService.fetchOrders(userId: userId)
                await MainActor.run {
                    self.orders = fetchedOrders
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func saveOrder(_ order: Order) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                var newOrder = order
                newOrder.userId = userId
                print("DEBUG: Saving order with userId: \(userId)")
                try await firebaseService.saveOrder(newOrder, userId: userId)
                print("DEBUG: Order saved successfully, refreshing list")
                // Refresh the list after successful save
                await MainActor.run {
                    loadOrders()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteOrder(_ orderId: String) {
        Task {
            do {
                try await firebaseService.deleteOrder(orderId)
                loadOrders() // Refresh the list
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func clearAllOrders() {
        Task {
            for order in orders {
                if let orderId = order.id {
                    try? await firebaseService.deleteOrder(orderId)
                }
            }
            loadOrders()
        }
    }
    
    // MARK: - Driver Methods
    
    func loadDriverOrders(driverId: String) {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                let allOrders = try await firebaseService.fetchAllOrders()
                await MainActor.run {
                    self.allOrders = allOrders
                    self.availableOrders = allOrders.filter { $0.status == .pending }
                    self.assignedOrders = allOrders.filter { $0.driverId == driverId && ($0.status == .assigned || $0.status == .pickedUp || $0.status == .inTransit) }
                    self.completedOrders = allOrders.filter { $0.driverId == driverId && $0.status == .delivered }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading driver orders: \(error)")
            }
        }
    }
    
    func loadAllOrders() {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                let allOrders = try await firebaseService.fetchAllOrders()
                await MainActor.run {
                    self.allOrders = allOrders
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading all orders: \(error)")
            }
        }
    }
    
    func acceptOrder(_ order: Order, driverId: String) {
        Task {
            do {
                var updatedOrder = order
                updatedOrder.driverId = driverId
                updatedOrder.status = .assigned
                updatedOrder.assignedAt = Date()
                
                try await firebaseService.updateOrderStatus(updatedOrder)
                loadDriverOrders(driverId: driverId)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateOrderStatus(_ order: Order, action: OrderAction) {
        Task {
            do {
                var updatedOrder = order
                
                switch action {
                case .pickedUp:
                    updatedOrder.status = .pickedUp
                    updatedOrder.pickedUpAt = Date()
                case .delivered:
                    updatedOrder.status = .delivered
                    updatedOrder.deliveredAt = Date()
                case .cancel:
                    updatedOrder.status = .cancelled
                }
                
                try await firebaseService.updateOrderStatus(updatedOrder)
                loadDriverOrders(driverId: order.driverId ?? "")
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateOrderStatusWithPhoto(_ order: Order, photoURL: String?, notes: String?) {
        Task {
            do {
                var updatedOrder = order
                updatedOrder.status = .delivered
                updatedOrder.deliveredAt = Date()
                updatedOrder.deliveryPhotoURL = photoURL
                updatedOrder.deliveryNotes = notes
                
                try await firebaseService.updateOrderStatus(updatedOrder)
                loadDriverOrders(driverId: order.driverId ?? "")
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
