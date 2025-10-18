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
    @Published var driverNames: [String: String] = [:] // Maps driverId to driver name
    @Published var customerNames: [String: String] = [:] // Maps userId to customer name
    
    /// Available payment methods
    @Published var paymentMethods: [PaymentMethod] = []
    
    /// Payment processing status
    @Published var isProcessingPayment = false
    
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
                // Load driver and customer names for orders
                await loadUserNames(for: fetchedOrders)
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
                try await firebaseService.saveOrder(newOrder, userId: userId)
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
                // Load driver and customer names for orders
                await loadUserNames(for: allOrders)
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading all orders: \(error)")
            }
        }
    }
    
    func acceptOrder(_ order: Order, driverId: String) {
        guard let orderId = order.id, !orderId.isEmpty else {
            errorMessage = "Cannot accept order - missing order ID"
            return
        }
        
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
        guard let orderId = order.id, !orderId.isEmpty else {
            errorMessage = "Cannot update order - missing order ID"
            return
        }
        
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
                case .collectPayment:
                    updatedOrder.paymentStatus = .paid
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
        guard let orderId = order.id, !orderId.isEmpty else {
            errorMessage = "Cannot update order - missing order ID"
            return
        }
        
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
    
    // MARK: - User Name Management
    
    private func loadUserNames(for orders: [Order]) async {
        let driverIds = Set(orders.compactMap { $0.driverId })
        let customerIds = Set(orders.map { $0.userId })
        
        // Load driver names
        for driverId in driverIds {
            // Skip if we already have this driver's name
            if driverNames[driverId] != nil { continue }
            
            do {
                let driver = try await firebaseService.fetchUser(uid: driverId)
                await MainActor.run {
                    self.driverNames[driverId] = driver.fullName
                }
            } catch {
                print("Error fetching driver name for ID \(driverId): \(error)")
                // Set a fallback name if we can't fetch the driver info
                await MainActor.run {
                    self.driverNames[driverId] = "Driver \(driverId.suffix(6))"
                }
            }
        }
        
        // Load customer names
        for customerId in customerIds {
            // Skip if we already have this customer's name
            if customerNames[customerId] != nil { continue }
            
            do {
                let customer = try await firebaseService.fetchUser(uid: customerId)
                await MainActor.run {
                    self.customerNames[customerId] = customer.fullName
                }
            } catch {
                print("Error fetching customer name for ID \(customerId): \(error)")
                // Set a fallback name if we can't fetch the customer info
                await MainActor.run {
                    self.customerNames[customerId] = "Customer \(customerId.suffix(6))"
                }
            }
        }
    }
    
    func getDriverName(for driverId: String) -> String {
        return driverNames[driverId] ?? "Driver \(driverId.suffix(6))"
    }
    
    func getCustomerName(for userId: String) -> String {
        return customerNames[userId] ?? "Customer \(userId.suffix(6))"
    }
    
    // MARK: - Admin Order Management
    
    func updateOrderStatus(_ order: Order) {
        Task {
            do {
                try await firebaseService.updateOrderStatus(order)
                await MainActor.run {
                    loadAllOrders()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Payment Management
    
    /// Loads available payment methods for the current user
    func loadPaymentMethods(for userId: String) {
        Task {
            do {
                let methods = try await firebaseService.getPaymentMethods(for: userId)
                await MainActor.run {
                    self.paymentMethods = methods
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load payment methods: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Processes a payment for an order
    func processPayment(for order: Order, paymentMethod: PaymentMethod) {
        guard let orderId = order.id else { return }
        
        isProcessingPayment = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await firebaseService.processPayment(orderId, amount: order.cost, paymentMethod: paymentMethod)
                
                await MainActor.run {
                    self.isProcessingPayment = false
                    if success {
                        // Reload orders to reflect payment status change
                        self.loadAllOrders()
                    } else {
                        self.errorMessage = "Payment processing failed"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessingPayment = false
                    self.errorMessage = "Payment error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Updates payment status for an order
    func updatePaymentStatus(for order: Order, status: PaymentStatus) {
        guard let orderId = order.id else { return }
        
        Task {
            do {
                try await firebaseService.updatePaymentStatus(orderId, status: status)
                await MainActor.run {
                    // Reload orders to reflect payment status change
                    self.loadAllOrders()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update payment status: \(error.localizedDescription)"
                }
            }
        }
    }
}
