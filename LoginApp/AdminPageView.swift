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
    @State private var searchText = ""
    @State private var selectedStatus: OrderStatus? = nil
    @State private var sortOption: OrderSortOption = .newest
    
    enum AdminTab {
        case overview, orders, users, analytics
    }
    
    enum OrderSortOption: String, CaseIterable {
        case newest = "Newest First"
        case oldest = "Oldest First"
        case status = "By Status"
        case cost = "By Cost"
        case customer = "By Customer"
    }
    
    // Computed properties for filtered and sorted orders
    private var filteredOrders: [Order] {
        var orders = orderStore.allOrders
        
        // Filter by search text
        if !searchText.isEmpty {
            orders = orders.filter { order in
                order.pickup.localizedCaseInsensitiveContains(searchText) ||
                order.dropoff.localizedCaseInsensitiveContains(searchText) ||
                orderStore.getCustomerName(for: order.userId).localizedCaseInsensitiveContains(searchText) ||
                (order.driverId != nil && orderStore.getDriverName(for: order.driverId!).localizedCaseInsensitiveContains(searchText))
            }
        }
        
        // Filter by status
        if let status = selectedStatus {
            orders = orders.filter { $0.status == status }
        }
        
        return orders
    }
    
    private var sortedOrders: [Order] {
        switch sortOption {
        case .newest:
            return filteredOrders.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return filteredOrders.sorted { $0.createdAt < $1.createdAt }
        case .status:
            return filteredOrders.sorted { $0.status.rawValue < $1.status.rawValue }
        case .cost:
            return filteredOrders.sorted { $0.cost > $1.cost }
        case .customer:
            return filteredOrders.sorted { 
                orderStore.getCustomerName(for: $0.userId) < orderStore.getCustomerName(for: $1.userId) 
            }
        }
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
                    // Main Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(title: "Total Orders", value: "\(orderStore.allOrders.count)", color: .blue)
                        StatCard(title: "Active Drivers", value: "\(userStore.drivers.count)", color: .green)
                        StatCard(title: "Total Users", value: "\(userStore.allUsers.count)", color: .orange)
                        StatCard(title: "Total Revenue", value: "$\(String(format: "%.2f", orderStore.totalRevenue))", color: .purple)
                    }
                    .padding(.horizontal)
                    
                    // Order Status Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order Status Breakdown")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(OrderStatus.allCases, id: \.self) { status in
                                let count = orderStore.allOrders.filter { $0.status == status }.count
                                StatusCard(status: status, count: count)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Driver Performance
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Driver Performance")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(userStore.drivers.prefix(3)) { driver in
                            DriverPerformanceCard(driver: driver, orderStore: orderStore)
                        }
                    }
                    
                    // Recent Orders
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Orders")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(orderStore.allOrders.prefix(5)) { order in
                            AdminOrderCard(order: order, orderStore: orderStore)
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
            VStack(spacing: 0) {
                // Search and Filter Controls
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search orders...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Filter and Sort Controls
                    HStack {
                        // Status Filter
                        Menu {
                            Button("All Statuses") {
                                selectedStatus = nil
                            }
                            ForEach(OrderStatus.allCases, id: \.self) { status in
                                Button(status.displayName) {
                                    selectedStatus = status
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedStatus?.displayName ?? "All Statuses")
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        // Sort Options
                        Menu {
                            ForEach(OrderSortOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    sortOption = option
                                }
                            }
                        } label: {
                            HStack {
                                Text(sortOption.rawValue)
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Orders List
                if orderStore.isLoading {
                    ProgressView("Loading orders...")
                        .padding()
                } else if sortedOrders.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No orders found")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty || selectedStatus != nil {
                            Text("Try adjusting your search or filters")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else {
                    List(sortedOrders) { order in
                        AdminOrderCard(order: order, orderStore: orderStore)
                    }
                }
            }
            .navigationTitle("All Orders (\(sortedOrders.count))")
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
    let orderStore: FirebaseOrderStore
    @State private var showingDriverAssignment = false
    @State private var showingStatusUpdate = false
    @State private var showingCancelOrder = false
    @State private var showingAdminNotes = false
    
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customer: \(orderStore.getCustomerName(for: order.userId))")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("ID: \(order.userId.suffix(6))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let driverId = order.driverId {
                        Text("Driver: \(orderStore.getDriverName(for: driverId))")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("ID: \(driverId.suffix(6))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No driver assigned")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
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
            
            // Admin Actions
            if order.status != .delivered && order.status != .cancelled {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Admin Actions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        // Assign Driver Button
                        if order.driverId == nil {
                            Button("Assign Driver") {
                                showingDriverAssignment = true
                            }
                            .buttonStyle(ActionButtonStyle(color: .blue))
                        }
                        
                        // Update Status Button
                        Button("Update Status") {
                            showingStatusUpdate = true
                        }
                        .buttonStyle(ActionButtonStyle(color: .orange))
                        
                        // Cancel Order Button
                        if order.status != .cancelled {
                            Button("Cancel Order") {
                                showingCancelOrder = true
                            }
                            .buttonStyle(ActionButtonStyle(color: .red))
                        }
                        
                        // Admin Notes Button
                        Button("Add Notes") {
                            showingAdminNotes = true
                        }
                        .buttonStyle(ActionButtonStyle(color: .purple))
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showingDriverAssignment) {
            DriverAssignmentView(order: order, orderStore: orderStore)
        }
        .sheet(isPresented: $showingStatusUpdate) {
            StatusUpdateView(order: order, orderStore: orderStore)
        }
        .sheet(isPresented: $showingCancelOrder) {
            CancelOrderView(order: order, orderStore: orderStore)
        }
        .sheet(isPresented: $showingAdminNotes) {
            AdminNotesView(order: order, orderStore: orderStore)
        }
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

// MARK: - Additional Card Components

struct StatusCard: View {
    let status: OrderStatus
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(status.color)
        }
        .padding()
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DriverPerformanceCard: View {
    let driver: AppUser
    let orderStore: FirebaseOrderStore
    
    private var completedOrders: Int {
        orderStore.allOrders.filter { $0.driverId == driver.id && $0.status == .delivered }.count
    }
    
    private var totalEarnings: Double {
        orderStore.allOrders.filter { $0.driverId == driver.id && $0.status == .delivered }.reduce(0) { $0 + $1.cost }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.fullName)
                    .font(.headline)
                Text(driver.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(completedOrders) completed")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("$\(String(format: "%.2f", totalEarnings))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Action Button Style

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Driver Assignment View

struct DriverAssignmentView: View {
    let order: Order
    let orderStore: FirebaseOrderStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDriverId: String?
    @State private var isAssigning = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Order Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "Unknown")")
                        .font(.headline)
                    Text("\(order.pickup) → \(order.dropoff)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Available Drivers
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Drivers")
                        .font(.headline)
                    
                    if orderStore.driverNames.isEmpty {
                        Text("Loading drivers...")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(orderStore.driverNames.keys), id: \.self) { driverId in
                            Button(action: {
                                selectedDriverId = driverId
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(orderStore.getDriverName(for: driverId))
                                            .font(.headline)
                                        Text("ID: \(driverId.suffix(6))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedDriverId == driverId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(selectedDriverId == driverId ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Assign Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Assign") {
                        assignDriver()
                    }
                    .disabled(selectedDriverId == nil || isAssigning)
                }
            }
        }
    }
    
    private func assignDriver() {
        guard let driverId = selectedDriverId else { return }
        
        isAssigning = true
        orderStore.acceptOrder(order, driverId: driverId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isAssigning = false
            dismiss()
        }
    }
}

// MARK: - Status Update View

struct StatusUpdateView: View {
    let order: Order
    let orderStore: FirebaseOrderStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatus: OrderStatus
    @State private var isUpdating = false
    
    init(order: Order, orderStore: FirebaseOrderStore) {
        self.order = order
        self.orderStore = orderStore
        self._selectedStatus = State(initialValue: order.status)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Order Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "Unknown")")
                        .font(.headline)
                    Text("Current Status: \(order.status.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Status Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select New Status")
                        .font(.headline)
                    
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button(action: {
                            selectedStatus = status
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(status.displayName)
                                        .font(.headline)
                                    Text(statusDescription(for: status))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedStatus == status {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(selectedStatus == status ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Update") {
                        updateStatus()
                    }
                    .disabled(selectedStatus == order.status || isUpdating)
                }
            }
        }
    }
    
    private func statusDescription(for status: OrderStatus) -> String {
        switch status {
        case .pending: return "Order created, waiting for driver"
        case .assigned: return "Driver accepted the order"
        case .pickedUp: return "Driver picked up the package"
        case .inTransit: return "Driver is delivering"
        case .delivered: return "Order completed"
        case .cancelled: return "Order cancelled"
        }
    }
    
    private func updateStatus() {
        isUpdating = true
        
        Task {
            var updatedOrder = order
            updatedOrder.status = selectedStatus
            
            // Update timestamps based on status
            switch selectedStatus {
            case .assigned:
                updatedOrder.assignedAt = Date()
            case .pickedUp:
                updatedOrder.pickedUpAt = Date()
            case .delivered:
                updatedOrder.deliveredAt = Date()
            default:
                break
            }
            
            await MainActor.run {
                orderStore.updateOrderStatus(updatedOrder)
                isUpdating = false
                dismiss()
            }
        }
    }
}

// MARK: - Cancel Order View

struct CancelOrderView: View {
    let order: Order
    let orderStore: FirebaseOrderStore
    @Environment(\.dismiss) private var dismiss
    @State private var cancelReason = ""
    @State private var isCancelling = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Order Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "Unknown")")
                        .font(.headline)
                    Text("\(order.pickup) → \(order.dropoff)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Status: \(order.status.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Cancel Reason
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cancellation Reason")
                        .font(.headline)
                    
                    TextField("Enter reason for cancellation...", text: $cancelReason, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Cancel Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel Order") {
                        cancelOrder()
                    }
                    .disabled(cancelReason.isEmpty || isCancelling)
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private func cancelOrder() {
        isCancelling = true
        
        Task {
            var updatedOrder = order
            updatedOrder.status = .cancelled
            
            await MainActor.run {
                orderStore.updateOrderStatus(updatedOrder)
                isCancelling = false
                dismiss()
            }
        }
    }
}

// MARK: - Admin Notes View

struct AdminNotesView: View {
    let order: Order
    let orderStore: FirebaseOrderStore
    @Environment(\.dismiss) private var dismiss
    @State private var adminNotes = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Order Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Order #\(order.id?.suffix(6) ?? "Unknown")")
                        .font(.headline)
                    Text("\(order.pickup) → \(order.dropoff)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // Admin Notes
                VStack(alignment: .leading, spacing: 12) {
                    Text("Admin Notes")
                        .font(.headline)
                    
                    TextField("Add notes about this order...", text: $adminNotes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(5...10)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Admin Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNotes()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveNotes() {
        isSaving = true
        
        // For now, we'll just dismiss since we don't have admin notes field in Order model
        // In a real implementation, you'd add adminNotes field to Order model
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
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
