//
//  AdminPageView.swift
//  LoginApp
//
//  Created by Jatin Gupta on 2025-01-27.
//

import SwiftUI
import FirebaseFirestore

/// Main admin dashboard providing comprehensive system management capabilities
/// Includes order management, user management, analytics, and driver code administration
/// Only accessible to users with admin role
struct AdminPageView: View {
    // MARK: - State Management
    
    /// Manages all order-related data and operations
    @StateObject private var orderStore = FirebaseOrderStore()
    
    /// Manages all user-related data and operations
    @StateObject private var userStore = FirebaseUserStore()
    
    /// Currently selected tab in the admin interface
    @State private var selectedTab: AdminTab = .overview
    
    /// Search text for filtering orders and users
    @State private var searchText = ""
    
    /// Selected order status for filtering
    @State private var selectedStatus: OrderStatus? = nil
    
    /// Current sorting option for orders
    @State private var sortOption: OrderSortOption = .newest
    
    /// Time range for analytics calculations
    @State private var analyticsTimeRange: AnalyticsTimeRange = .last7Days
    
    /// List of driver invite codes for management
    @State private var driverCodes: [DriverCode] = []
    
    /// Loading state for driver codes operations
    @State private var isLoadingCodes = false
    
    /// Text input for creating new driver codes
    @State private var newCodeText = ""
    
    /// Loading state for code creation
    @State private var isCreatingCode = false
    
    // MARK: - Enums
    
    /// Available tabs in the admin interface
    enum AdminTab {
        case overview      // Dashboard with key metrics and recent activity
        case orders        // Order management and filtering
        case users         // User management and role administration
        case analytics     // Business analytics and reporting
        case driverCodes   // Driver invite code management
    }
    
    /// Available sorting options for orders
    enum OrderSortOption: String, CaseIterable {
        case newest = "Newest First"     // Sort by creation date (newest first)
        case oldest = "Oldest First"     // Sort by creation date (oldest first)
        case status = "By Status"        // Sort by order status
        case cost = "By Cost"           // Sort by order cost (highest first)
        case customer = "By Customer"    // Sort by customer name alphabetically
    }
    
    /// Time ranges for analytics calculations
    enum AnalyticsTimeRange: String, CaseIterable {
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case last90Days = "Last 90 Days"
        case allTime = "All Time"
        
        /// Returns the date range for the selected time period
        var dateRange: (start: Date, end: Date) {
            let now = Date()
            let calendar = Calendar.current
            
            switch self {
            case .last24Hours:
                return (calendar.date(byAdding: .hour, value: -24, to: now) ?? now, now)
            case .last7Days:
                return (calendar.date(byAdding: .day, value: -7, to: now) ?? now, now)
            case .last30Days:
                return (calendar.date(byAdding: .day, value: -30, to: now) ?? now, now)
            case .last90Days:
                return (calendar.date(byAdding: .day, value: -90, to: now) ?? now, now)
            case .allTime:
                return (Date.distantPast, now)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Orders filtered by search text and status selection
    /// Applies search across pickup/dropoff addresses and customer/driver names
    private var filteredOrders: [Order] {
        var orders = orderStore.allOrders
        
        // Filter by search text - searches across multiple fields
        if !searchText.isEmpty {
            orders = orders.filter { order in
                order.pickup.localizedCaseInsensitiveContains(searchText) ||
                order.dropoff.localizedCaseInsensitiveContains(searchText) ||
                orderStore.getCustomerName(for: order.userId).localizedCaseInsensitiveContains(searchText) ||
                (order.driverId != nil && orderStore.getDriverName(for: order.driverId!).localizedCaseInsensitiveContains(searchText))
            }
        }
        
        // Filter by selected status
        if let status = selectedStatus {
            orders = orders.filter { $0.status == status }
        }
        
        return orders
    }
    
    /// Orders sorted according to the selected sort option
    /// Provides multiple sorting criteria for different admin needs
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
    
    // MARK: - Analytics Computed Properties
    
    /// Orders filtered by the selected analytics time range
    /// Used for calculating metrics and generating reports
    private var analyticsOrders: [Order] {
        let dateRange = analyticsTimeRange.dateRange
        return orderStore.allOrders.filter { order in
            order.createdAt >= dateRange.start && order.createdAt <= dateRange.end
        }
    }
    
    /// Total revenue from completed orders in the selected time range
    private var totalRevenue: Double {
        analyticsOrders.filter { $0.status == .delivered }.reduce(0) { $0 + $1.cost }
    }
    
    /// Total number of orders in the selected time range
    private var totalOrders: Int {
        analyticsOrders.count
    }
    
    /// Number of successfully completed orders
    private var completedOrders: Int {
        analyticsOrders.filter { $0.status == .delivered }.count
    }
    
    /// Number of cancelled orders
    private var cancelledOrders: Int {
        analyticsOrders.filter { $0.status == .cancelled }.count
    }
    
    /// Percentage of orders that were successfully completed
    private var completionRate: Double {
        guard totalOrders > 0 else { return 0 }
        return Double(completedOrders) / Double(totalOrders) * 100
    }
    
    /// Average value of completed orders
    private var averageOrderValue: Double {
        guard completedOrders > 0 else { return 0 }
        return totalRevenue / Double(completedOrders)
    }
    
    private var ordersByStatus: [(OrderStatus, Int)] {
        OrderStatus.allCases.map { status in
            let count = analyticsOrders.filter { $0.status == status }.count
            return (status, count)
        }.sorted { $0.1 > $1.1 }
    }
    
    private var topDrivers: [(String, Int, Double)] {
        let driverStats = Dictionary(grouping: analyticsOrders.filter { $0.driverId != nil && $0.status == .delivered }) { $0.driverId! }
            .mapValues { orders in
                (count: orders.count, revenue: orders.reduce(0) { $0 + $1.cost })
            }
        
        return driverStats.map { (driverId, stats) in
            (orderStore.getDriverName(for: driverId), stats.count, stats.revenue)
        }.sorted { $0.1 > $1.1 }
    }
    
    private var ordersByDay: [(String, Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: analyticsOrders) { order in
            calendar.dateInterval(of: .day, for: order.createdAt)?.start ?? order.createdAt
        }
        
        return grouped.map { (date, orders) in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM dd"
            return (formatter.string(from: date), orders.count)
        }.sorted { $0.0 < $1.0 }
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
            
            driverCodesTab
                .tabItem { Label("Driver Codes", systemImage: "key.fill") }
                .tag(AdminTab.driverCodes)
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
                    // Time Range Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Time Range")
                            .font(.headline)
                        
                        Picker("Time Range", selection: $analyticsTimeRange) {
                            ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding(.horizontal)
                    
                    // Key Metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        AnalyticsCard(title: "Total Revenue", value: "$\(String(format: "%.2f", totalRevenue))", color: .green, icon: "dollarsign.circle.fill")
                        AnalyticsCard(title: "Total Orders", value: "\(totalOrders)", color: .blue, icon: "list.bullet")
                        AnalyticsCard(title: "Completion Rate", value: "\(String(format: "%.1f", completionRate))%", color: .purple, icon: "checkmark.circle.fill")
                        AnalyticsCard(title: "Avg Order Value", value: "$\(String(format: "%.2f", averageOrderValue))", color: .orange, icon: "chart.bar.fill")
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
                            ForEach(ordersByStatus, id: \.0) { status, count in
                                StatusAnalyticsCard(status: status, count: count, total: totalOrders)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Top Drivers
                    if !topDrivers.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Performing Drivers")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(Array(topDrivers.prefix(5).enumerated()), id: \.offset) { index, driver in
                                DriverAnalyticsCard(
                                    rank: index + 1,
                                    name: driver.0,
                                    orders: driver.1,
                                    revenue: driver.2
                                )
                            }
                        }
                    }
                    
                    // Daily Orders Chart
                    if !ordersByDay.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Orders by Day")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            DailyOrdersChart(data: ordersByDay)
                                .padding(.horizontal)
                        }
                    }
                    
                    // Revenue Trends
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Revenue Insights")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            RevenueInsightCard(
                                title: "Completed Orders",
                                value: "\(completedOrders)",
                                subtitle: "\(String(format: "%.1f", completionRate))% completion rate",
                                color: .green
                            )
                            
                            RevenueInsightCard(
                                title: "Cancelled Orders",
                                value: "\(cancelledOrders)",
                                subtitle: "\(String(format: "%.1f", Double(cancelledOrders) / Double(totalOrders) * 100))% cancellation rate",
                                color: .red
                            )
                            
                            RevenueInsightCard(
                                title: "Active Drivers",
                                value: "\(userStore.drivers.count)",
                                subtitle: "\(topDrivers.count) drivers with completed orders",
                                color: .blue
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
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
    
    // MARK: - Driver Codes Tab
    private var driverCodesTab: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Create New Code Section
                VStack(spacing: 12) {
                    Text("Create New Driver Code")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        TextField("Enter code (e.g., DRIVER001)", text: $newCodeText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocapitalization(.allCharacters)
                        
                        Button("Create") {
                            createDriverCode()
                        }
                        .disabled(newCodeText.isEmpty || isCreatingCode)
                        .buttonStyle(ActionButtonStyle(color: .blue))
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // Codes List
                if isLoadingCodes {
                    ProgressView("Loading codes...")
                        .padding()
                } else if driverCodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No driver codes created yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Create your first driver code above")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List(driverCodes) { code in
                        DriverCodeCard(code: code) {
                            deactivateCode(code)
                }
            }
                }
            }
            .navigationTitle("Driver Codes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        NotificationCenter.default.post(name: .didSignOut, object: nil)
                    }
                    .foregroundColor(.red)
                }
            }
            .refreshable {
                loadDriverCodes()
            }
            .onAppear {
                loadDriverCodes()
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadAdminData() {
        orderStore.loadAllOrders()
        userStore.loadAllUsers()
    }
    
    private func loadDriverCodes() {
        isLoadingCodes = true
        
        Task {
            do {
                let codesData = try await FirebaseService.shared.getAllDriverCodes()
                await MainActor.run {
                    self.driverCodes = codesData.compactMap { data in
                        DriverCode.fromDictionary(data)
                    }
                    self.isLoadingCodes = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingCodes = false
                    print("Error loading driver codes: \(error)")
                }
            }
        }
    }
    
    private func createDriverCode() {
        guard !newCodeText.isEmpty else { return }
        
        isCreatingCode = true
        
        Task {
            do {
                try await FirebaseService.shared.createDriverCode(
                    newCodeText.trimmingCharacters(in: .whitespacesAndNewlines),
                    createdBy: userStore.allUsers.first { $0.role == .admin }?.id ?? "unknown",
                    notes: "Created via admin interface"
                )
                
                await MainActor.run {
                    self.newCodeText = ""
                    self.isCreatingCode = false
                    loadDriverCodes() // Refresh the list
                }
            } catch {
                await MainActor.run {
                    self.isCreatingCode = false
                    print("Error creating driver code: \(error)")
                }
            }
        }
    }
    
    private func deactivateCode(_ code: DriverCode) {
        Task {
            do {
                try await FirebaseService.shared.deactivateDriverCode(code.id)
                await MainActor.run {
                    loadDriverCodes() // Refresh the list
                }
            } catch {
                print("Error deactivating code: \(error)")
            }
        }
    }
}

// MARK: - Driver Code Model

struct DriverCode: Identifiable {
    let id: String
    let code: String
    let isActive: Bool
    let createdAt: Date
    let createdBy: String
    let usedAt: Date?
    let usedBy: String?
    let notes: String?
    
    var isUsed: Bool {
        usedAt != nil
    }
    
    var statusText: String {
        if !isActive {
            return "Deactivated"
        } else if isUsed {
            return "Used"
        } else {
            return "Active"
        }
    }
    
    var statusColor: Color {
        if !isActive {
            return .red
        } else if isUsed {
            return .green
        } else {
            return .blue
        }
    }
    
    static func fromDictionary(_ data: [String: Any]) -> DriverCode? {
        guard let id = data["id"] as? String,
              let code = data["code"] as? String,
              let isActive = data["isActive"] as? Bool,
              let createdAt = data["createdAt"] as? Timestamp,
              let createdBy = data["createdBy"] as? String else {
            return nil
        }
        
        let usedAt = data["usedAt"] as? Timestamp
        let usedBy = data["usedBy"] as? String
        let notes = data["notes"] as? String
        
        return DriverCode(
            id: id,
            code: code,
            isActive: isActive,
            createdAt: createdAt.dateValue(),
            createdBy: createdBy,
            usedAt: usedAt?.dateValue(),
            usedBy: usedBy,
            notes: notes
        )
    }
}

// MARK: - Driver Code Card

struct DriverCodeCard: View {
    let code: DriverCode
    let onDeactivate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(code.code)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(code.statusText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(code.statusColor.opacity(0.2))
                    .foregroundColor(code.statusColor)
                    .cornerRadius(6)
            }
            
            if let notes = code.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Created: \(code.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let usedAt = code.usedAt {
                    Text("Used: \(usedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if code.isActive && !code.isUsed {
                HStack {
                    Spacer()
                    Button("Deactivate") {
                        onDeactivate()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
            
            // Payment Information
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Payment: \(order.paymentResponsibility?.displayName ?? "Not specified")")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Status: \(order.paymentStatus?.displayName ?? "Not specified")")
                        .font(.caption2)
                        .foregroundColor(order.paymentStatus?.color ?? .gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", order.cost))")
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    Text("Created: \(order.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
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

// MARK: - Analytics Card Components

struct AnalyticsCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StatusAnalyticsCard: View {
    let status: OrderStatus
    let count: Int
    let total: Int
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total) * 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(status.color)
            }
            
            HStack {
                Text("\(String(format: "%.1f", percentage))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(status.color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DriverAnalyticsCard: View {
    let rank: Int
    let name: String
    let orders: Int
    let revenue: Double
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            // Driver Info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text("\(orders) orders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Revenue
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(String(format: "%.2f", revenue))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                Text("earned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DailyOrdersChart: View {
    let data: [(String, Int)]
    
    private var maxValue: Int {
        data.map { $0.1 }.max() ?? 1
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(data, id: \.0) { day, count in
                    VStack(spacing: 4) {
                        // Bar
                        Rectangle()
                            .fill(Color.blue.opacity(0.7))
                            .frame(width: 30, height: CGFloat(count) / CGFloat(maxValue) * 100)
                            .cornerRadius(4)
                        
                        // Day label
                        Text(day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
            .frame(height: 120)
            
            // Legend
            HStack {
                Text("Orders per day")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Max: \(maxValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RevenueInsightCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
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
