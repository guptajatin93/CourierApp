//
//  AdminPageView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import SwiftUI

struct AdminPageView: View {
    @StateObject private var orderStore = FirebaseOrderStore()
    @StateObject private var userStore = FirebaseUserStore()
    @State private var selectedTab: AdminTab = .overview
    
    enum AdminTab {
        case overview, orders, users, analytics
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            overviewTab
                .tabItem { Label("Overview", systemImage: "chart.bar") }
                .tag(AdminTab.overview)
            
            ordersTab
                .tabItem { Label("Orders", systemImage: "list.bullet") }
                .tag(AdminTab.orders)
            
            usersTab
                .tabItem { Label("Users", systemImage: "person.2") }
                .tag(AdminTab.users)
            
            analyticsTab
                .tabItem { Label("Analytics", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AdminTab.analytics)
        }
        .onAppear {
            loadAdminData()
        }
    }
    
    // MARK: - Overview Tab
    private var overviewTab: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Total Orders", value: "\(orderStore.allOrders.count)", color: .blue)
                        StatCard(title: "Active Drivers", value: "\(userStore.drivers.count)", color: .green)
                        StatCard(title: "Total Users", value: "\(userStore.allUsers.count)", color: .orange)
                        StatCard(title: "Revenue", value: "$\(String(format: "%.2f", orderStore.totalRevenue))", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // Recent Orders
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Orders")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(orderStore.allOrders.prefix(5)) { order in
                            AdminOrderCard(order: order)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Admin Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        NotificationCenter.default.post(name: .didSignOut, object: nil)
                    }
                    .foregroundColor(.red)
                }
            }
            .refreshable {
                loadAdminData()
            }
        }
    }
    
    // MARK: - Orders Tab
    private var ordersTab: some View {
        NavigationView {
            VStack {
                if orderStore.isLoading {
                    ProgressView("Loading orders...")
                        .padding()
                } else {
                    List(orderStore.allOrders) { order in
                        AdminOrderCard(order: order)
                    }
                }
            }
            .navigationTitle("All Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        NotificationCenter.default.post(name: .didSignOut, object: nil)
                    }
                    .foregroundColor(.red)
                }
            }
            .refreshable {
                loadAdminData()
            }
        }
    }
    
    // MARK: - Users Tab
    private var usersTab: some View {
        NavigationView {
            VStack {
                if userStore.isLoading {
                    ProgressView("Loading users...")
                        .padding()
                } else {
                    List {
                        Section("Drivers") {
                            ForEach(userStore.drivers) { user in
                                UserCard(user: user)
                            }
                        }
                        
                        Section("Customers") {
                            ForEach(userStore.customers) { user in
                                UserCard(user: user)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        NotificationCenter.default.post(name: .didSignOut, object: nil)
                    }
                    .foregroundColor(.red)
                }
            }
            .refreshable {
                loadAdminData()
            }
        }
    }
    
    // MARK: - Analytics Tab
    private var analyticsTab: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Analytics Coming Soon")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Text("This section will include:")
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Order completion rates")
                        Text("• Driver performance metrics")
                        Text("• Revenue analytics")
                        Text("• Customer satisfaction scores")
                        Text("• Geographic delivery patterns")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                }
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        NotificationCenter.default.post(name: .didSignOut, object: nil)
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadAdminData() {
        orderStore.loadAllOrders()
        userStore.loadAllUsers()
    }
}

// MARK: - Supporting Views

struct AdminOrderCard: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.id?.suffix(6) ?? "Unknown")")
                    .font(.headline)
                Spacer()
                Text(order.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(6)
            }
            
            Text("\(order.pickup) → \(order.dropoff)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Customer: \(order.userId.suffix(6))")
                Spacer()
                if let driverId = order.driverId {
                    Text("Driver: \(driverId.suffix(6))")
                } else {
                    Text("No driver assigned")
                        .foregroundColor(.orange)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            HStack {
                Text("$\(String(format: "%.2f", order.cost))")
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                Spacer()
                Text("Created: \(order.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch order.status {
        case .pending: return .orange
        case .assigned: return .blue
        case .pickedUp: return .purple
        case .inTransit: return .green
        case .delivered: return .gray
        case .cancelled: return .red
        }
    }
}

struct UserCard: View {
    let user: AppUser
    
    var body: some View {
        HStack {
            Image(systemName: user.role == .driver ? "truck.box.fill" : "person.fill")
                .foregroundColor(user.role == .driver ? .blue : .green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(.headline)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(user.role.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(roleColor.opacity(0.2))
                    .foregroundColor(roleColor)
                    .cornerRadius(6)
                
                Text(user.isActive ? "Active" : "Inactive")
                    .font(.caption)
                    .foregroundColor(user.isActive ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var roleColor: Color {
        switch user.role {
        case .user: return .green
        case .driver: return .blue
        case .admin: return .purple
        }
    }
}

// MARK: - Firebase User Store for Admin

@MainActor
final class FirebaseUserStore: ObservableObject {
    @Published var allUsers: [AppUser] = []
    @Published var drivers: [AppUser] = []
    @Published var customers: [AppUser] = []
    @Published var isLoading = false
    
    private let firebaseService = FirebaseService.shared
    
    func loadAllUsers() {
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                let users = try await firebaseService.fetchAllUsers()
                await MainActor.run {
                    self.allUsers = users
                    self.drivers = users.filter { $0.role == .driver }
                    self.customers = users.filter { $0.role == .user }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading users: \(error)")
            }
        }
    }
}
