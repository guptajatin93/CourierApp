//
//  DriverPageView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import SwiftUI
import MapKit

/// Main interface for drivers to manage their delivery assignments
/// Provides order acceptance, tracking, and completion capabilities
/// Only accessible to users with driver role
struct DriverPageView: View {
    // MARK: - State Management
    
    /// Manages all order-related data and operations for the driver
    @StateObject private var orderStore = FirebaseOrderStore()
    
    /// Currently selected tab in the driver interface
    @State private var selectedTab: DriverTab = .available
    
    /// Driver's online/offline status for order availability
    @State private var isOnline = false
    
    // MARK: - Driver Properties
    
    /// Unique identifier for the driver
    let driverId: String
    
    /// Display name of the driver
    let driverName: String
    
    // MARK: - Enums
    
    /// Available tabs in the driver interface
    enum DriverTab {
        case available   // Available orders to accept
        case assigned    // Currently assigned orders
        case completed   // Completed order history
        case profile     // Driver profile and settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            availableOrdersTab
                .tabItem { Label("Available", systemImage: "list.bullet") }
                .tag(DriverTab.available)
            
            assignedOrdersTab
                .tabItem { Label("My Orders", systemImage: "truck.box") }
                .tag(DriverTab.assigned)
            
            completedOrdersTab
                .tabItem { Label("Completed", systemImage: "checkmark.circle") }
                .tag(DriverTab.completed)
            
            driverProfileTab
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(DriverTab.profile)
        }
        .onAppear {
            loadDriverOrders()
        }
    }
    
    // MARK: - Available Orders Tab
    private var availableOrdersTab: some View {
        NavigationView {
            VStack {
                // Online/Offline Toggle
                HStack {
                    Text("Status:")
                        .font(.headline)
                    Spacer()
                    Toggle(isOnline ? "Online" : "Offline", isOn: $isOnline)
                        .toggleStyle(SwitchToggleStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if isOnline {
                    if orderStore.isLoading {
                        ProgressView("Loading available orders...")
                            .padding()
                    } else if orderStore.availableOrders.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "truck.box")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No available orders")
                                .font(.title2)
                                .foregroundColor(.gray)
                            Text("Check back later for new delivery requests")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        List(orderStore.availableOrders) { order in
                            AvailableOrderCard(order: order) {
                                acceptOrder(order)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("You're offline")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Go online to see available delivery orders")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Available Orders")
            .refreshable {
                loadDriverOrders()
            }
        }
    }
    
    // MARK: - Assigned Orders Tab
    private var assignedOrdersTab: some View {
        NavigationView {
            VStack {
                if orderStore.isLoading {
                    ProgressView("Loading your orders...")
                        .padding()
                } else if orderStore.assignedOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("No assigned orders")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Accept orders from the Available tab")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List(orderStore.assignedOrders) { order in
                        AssignedOrderCard(order: order) { action in
                            handleOrderAction(order, action: action)
                        }
                    }
                }
            }
            .navigationTitle("My Orders")
            .refreshable {
                loadDriverOrders()
            }
        }
    }
    
    // MARK: - Completed Orders Tab
    private var completedOrdersTab: some View {
        NavigationView {
            VStack {
                if orderStore.isLoading {
                    ProgressView("Loading completed orders...")
                        .padding()
                } else if orderStore.completedOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No completed orders yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Your completed deliveries will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List(orderStore.completedOrders) { order in
                        CompletedOrderCard(order: order)
                    }
                }
            }
            .navigationTitle("Completed Orders")
            .refreshable {
                loadDriverOrders()
            }
        }
    }
    
    // MARK: - Driver Profile Tab
    private var driverProfileTab: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Driver Info
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(driverName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Driver")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                
                // Stats
                VStack(spacing: 16) {
                    HStack {
                        StatCard(title: "Completed", value: "\(orderStore.completedOrders.count)", color: .green)
                        StatCard(title: "In Progress", value: "\(orderStore.assignedOrders.count)", color: .blue)
                    }
                    
                    HStack {
                        StatCard(title: "Total Earnings", value: "$\(String(format: "%.2f", orderStore.totalEarnings))", color: .orange)
                        StatCard(title: "Rating", value: "4.8", color: .yellow)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Sign Out Button
                Button("Sign Out") {
                    NotificationCenter.default.post(name: .didSignOut, object: nil)
                }
                .foregroundColor(.red)
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
    
    // MARK: - Helper Methods
    private func loadDriverOrders() {
        orderStore.loadDriverOrders(driverId: driverId)
    }
    
    private func acceptOrder(_ order: Order) {
        orderStore.acceptOrder(order, driverId: driverId)
    }
    
    private func handleOrderAction(_ order: Order, action: OrderAction) {
        // Skip camera confirmation for now - directly update status
        orderStore.updateOrderStatus(order, action: action)
    }
}

// MARK: - Supporting Views

struct AvailableOrderCard: View {
    let order: Order
    let onAccept: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(order.pickup) → \(order.dropoff)")
                        .font(.headline)
                    Text("Distance: \(String(format: "%.1f", order.distance)) km")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("$\(String(format: "%.2f", order.cost))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            HStack {
                Label("\(order.size) • \(order.weight)", systemImage: "shippingbox")
                Spacer()
                Label("\(order.etaMinutes) min", systemImage: "clock")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if order.fragile {
                Label("Fragile", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Button("Accept Order") {
                onAccept()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AssignedOrderCard: View {
    let order: Order
    let onAction: (OrderAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(order.pickup) → \(order.dropoff)")
                    .font(.headline)
                Spacer()
                Text(order.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(6)
            }
            
            Text("Customer: \(order.userId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let instructions = order.instructions, !instructions.isEmpty {
                Text("Instructions: \(instructions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons based on status
            HStack {
                switch order.status {
                case .assigned:
                    Button("Mark as Picked Up") {
                        onAction(.pickedUp)
                    }
                    .buttonStyle(.borderedProminent)
                case .pickedUp:
                    Button("Mark as Delivered") {
                        onAction(.delivered)
                    }
                    .buttonStyle(.borderedProminent)
                default:
                    EmptyView()
                }
                
                Spacer()
                
                Button("Cancel") {
                    onAction(.cancel)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CompletedOrderCard: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(order.pickup) → \(order.dropoff)")
                    .font(.headline)
                Spacer()
                Text("$\(String(format: "%.2f", order.cost))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            Text("Completed on \(order.deliveredAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let notes = order.deliveryNotes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

enum OrderAction {
    case pickedUp
    case delivered
    case cancel
}
