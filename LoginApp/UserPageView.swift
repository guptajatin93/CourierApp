import SwiftUI
import MapKit

struct UserPageView: View {
    @StateObject private var orderStore = FirebaseOrderStore()
    @StateObject private var profileStore = FirebaseProfileStore()
    @State private var selectedTab: Tab = .home
    @State private var pickupAddress: String = ""
    @State private var dropAddress: String = ""
    @State private var isSettingQuickAddresses = false
    @State private var isReversing = false
    @State private var route: MKRoute? = nil   // ✅ optional
    @State private var showMap = false
    @State private var deliveryCost: Double? = nil

    // Order options
    @State private var packageSize: String = "Medium"
    @State private var packageWeight: String = "< 5kg"
    @State private var fragile: Bool = false
    @State private var deliverySpeed: String = "Standard"
    @State private var instructions: String = ""
    
    var token: String
    var initialName: String? = nil
    var initialEmail: String? = nil
    var initialPhone: String? = nil

    enum Tab {
        case home, pastOrders, profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            ordersTab
                .tabItem { Label("Orders", systemImage: "clock.fill") }
                .tag(Tab.pastOrders)

            profileTab
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
        }
    }

    // MARK: - Home Tab
    private var homeTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Courier Order")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 20)

                // Quick Address Selection
                quickAddressButtons
                
                ZStack {
                    VStack(spacing: 8) {
                        AddressSearchView(text: $pickupAddress, placeholder: "Pickup Address", disableSuggestions: $isSettingQuickAddresses)
                        AddressSearchView(text: $dropAddress, placeholder: "Dropoff Address", disableSuggestions: $isSettingQuickAddresses)
                    }
                    
                    // Small reverse button positioned on the right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: reverseAddresses) {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isReversing ? .white : .gray)
                                    .frame(width: 28, height: 28)
                                    .background(isReversing ? Color.blue : Color(.systemGray5))
                                    .clipShape(Circle())
                                    .scaleEffect(isReversing ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isReversing)
                            }
                            .disabled(pickupAddress.isEmpty || dropAddress.isEmpty)
                            .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                }

                Button("Get Route") {
                    getRoute()
                }
                .disabled(pickupAddress.isEmpty || dropAddress.isEmpty)
                .padding()
                .frame(maxWidth: .infinity)
                .background((pickupAddress.isEmpty || dropAddress.isEmpty) ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)

                if showMap, let route = route {
                    routeDetails(for: route)
                }
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            profileStore.loadProfile()
        }
    }

    // MARK: - Orders Tab
    private var ordersTab: some View {
        NavigationView {
            VStack {
                Text("📦 My Orders")
                    .font(.title2)
                    .padding(.top, 20)

                if orderStore.orders.isEmpty {
                    VStack(spacing: 16) {
                        Text("No orders yet.")
                            .foregroundColor(.gray)
                            .font(.headline)
                        Text("Create your first order from the Home tab!")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    List(orderStore.orders) { order in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(order.pickup) → \(order.dropoff)")
                                    .font(.headline)
                                Spacer()
                                Text(order.status.displayName)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(order.status.color.opacity(0.2))
                                    .foregroundColor(order.status.color)
                                    .cornerRadius(8)
                            }
                            
                            Text("Size: \(order.size), Weight: \(order.weight), Fragile: \(order.fragile ? "Yes" : "No")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Cost: $\(String(format: "%.2f", order.cost)) — ETA: \(order.etaMinutes) mins")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            
                            if let instructions = order.instructions, !instructions.isEmpty {
                                Text("Instructions: \(instructions)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                            
                            if let driverId = order.driverId {
                                Text("Driver: \(orderStore.getDriverName(for: driverId))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            if order.deliveryPhotoURL != nil {
                                Button("View Delivery Photo") {
                                    // TODO: Show delivery photo
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .onAppear {
                orderStore.loadOrders()
            }
        }
    }


    private var profileTab: some View {
        ProfileView(
            token: token,
            initialName: initialName,
            initialEmail: initialEmail,
            initialPhone: initialPhone
        ) {
            // Sign out action
            selectedTab = .home    // optional, reset tab
            // You’ll also need to tell ContentView to set isLoggedIn = false
            NotificationCenter.default.post(name: .didSignOut, object: nil)
        }
        
    }



    // MARK: - Route Details
    private func routeDetails(for route: MKRoute) -> some View {
        VStack(spacing: 16) {
            RouteMapView(route: route)
                .id(route.polyline.hashValue)
                .frame(height: 250)
                .cornerRadius(10)
                .padding(.horizontal)

            Text("Distance: \(String(format: "%.2f", route.distance / 1000)) km")
            Text("Estimated time: \(Int(route.expectedTravelTime / 60)) mins")

            if let cost = deliveryCost {
                Text("Estimated Delivery Cost: $\(String(format: "%.2f", cost))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            packageOptions

            Button("Confirm Order") {
                confirmOrder()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .onAppear { deliveryCost = calculateCost(for: route) }
        .onChange(of: packageSize) { deliveryCost = calculateCost(for: route) }
        .onChange(of: packageWeight) { deliveryCost = calculateCost(for: route) }
        .onChange(of: fragile) { deliveryCost = calculateCost(for: route) }
        .onChange(of: deliverySpeed) { deliveryCost = calculateCost(for: route) }
    }

    // MARK: - Package Options UI
    private var packageOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Package Size", selection: $packageSize) {
                Text("Small").tag("Small")
                Text("Medium").tag("Medium")
                Text("Large").tag("Large")
            }
            .pickerStyle(.segmented)

            Picker("Weight", selection: $packageWeight) {
                Text("< 5kg").tag("< 5kg")
                Text("5–20kg").tag("5–20kg")
                Text("20–50kg").tag("20–50kg")
                Text("> 50kg").tag("> 50kg")
            }

            Toggle("Fragile?", isOn: $fragile)

            Picker("Delivery Speed", selection: $deliverySpeed) {
                Text("Standard").tag("Standard")
                Text("Express").tag("Express")
                Text("Same-day").tag("Same-day")
            }

            TextField("Special Instructions", text: $instructions)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal)
    }

    // MARK: - Confirm Order
    private func confirmOrder() {
        guard let route = self.route, let cost = deliveryCost else { return }
        let order = Order(
            userId: token, // Using token as userId for now
            pickup: pickupAddress,
            dropoff: dropAddress,
            size: packageSize,
            weight: packageWeight,
            fragile: fragile,
            speed: deliverySpeed,
            instructions: instructions.isEmpty ? nil : instructions,
            cost: cost,
            distance: route.distance / 1000,
            etaMinutes: Int(route.expectedTravelTime / 60)
        )
        
        Task {
            await orderStore.saveOrder(order)
            await MainActor.run {
                selectedTab = .pastOrders
                // Reset fields for new order
                pickupAddress = ""
                dropAddress = ""
                packageSize = "Medium"
                packageWeight = "< 5kg"
                fragile = false
                deliverySpeed = "Standard"
                instructions = ""
                self.route = nil
                showMap = false
                deliveryCost = nil
            }
        }
    }


    // MARK: - Cost Calculation
    private func calculateCost(for route: MKRoute) -> Double {
        let distanceKm = route.distance / 1000
        var cost = 5.0 + (distanceKm * 1.2)

        switch packageWeight {
        case "< 5kg": cost *= 1.0
        case "5–20kg": cost *= 1.5
        case "20–50kg": cost *= 2.0
        case "> 50kg": cost *= 3.0
        default: break
        }

        if fragile { cost += 5.0 }
        if deliverySpeed == "Express" || deliverySpeed == "Same-day" {
            cost *= 1.5
        }

        return cost
    }

    // MARK: - Quick Address Selection
    private var quickAddressButtons: some View {
        VStack(spacing: 12) {
            Text("Quick Select")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Home to Work
                Button(action: {
                    setQuickAddresses(pickup: "Home", dropoff: "Work")
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.title2)
                        Text("Home → Work")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                // Work to Home
                Button(action: {
                    setQuickAddresses(pickup: "Work", dropoff: "Home")
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "building.2.fill")
                            .font(.title2)
                        Text("Work → Home")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            
            // Smart Suggestions
            if !pickupAddress.isEmpty || !dropAddress.isEmpty {
                smartSuggestions
            }
        }
        .padding(.horizontal)
    }
    
    private var smartSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Smart Suggestions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            if pickupAddress.isEmpty && !dropAddress.isEmpty {
                Button("Set pickup to Home") {
                    pickupAddress = "Home"
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if dropAddress.isEmpty && !pickupAddress.isEmpty {
                Button("Set delivery to Work") {
                    dropAddress = "Work"
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if pickupAddress == "Home" && dropAddress == "Work" {
                Text("🚀 Perfect! This is a common route - you'll get priority delivery!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
            
            // Address setup reminders
            if profileStore.profile.homeAddress.isEmpty || profileStore.profile.workAddress.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Quick buttons won't work until you set up addresses:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    if profileStore.profile.homeAddress.isEmpty {
                        Text("• Add your home address in Profile tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if profileStore.profile.workAddress.isEmpty {
                        Text("• Add your work address in Profile tab")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("💡 After setting up addresses, quick buttons will use your actual addresses!")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func setQuickAddresses(pickup: String, dropoff: String) {
        print("🚀 Setting quick addresses: \(pickup) → \(dropoff)")
        
        // Set flag to disable suggestions during programmatic update
        isSettingQuickAddresses = true
        print("🔒 Disabled suggestions: \(isSettingQuickAddresses)")
        
        // Resolve addresses before setting them
        let resolvedPickup = resolveAddress(pickup)
        let resolvedDropoff = resolveAddress(dropoff)
        
        print("📍 Resolved addresses: '\(resolvedPickup)' → '\(resolvedDropoff)'")
        
        pickupAddress = resolvedPickup
        dropAddress = resolvedDropoff
        
        // Reset flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSettingQuickAddresses = false
            print("🔓 Re-enabled suggestions: \(isSettingQuickAddresses)")
        }
        
        // Auto-trigger route calculation for quick selections
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            getRoute()
        }
    }
    
    private func reverseAddresses() {
        print("🔄 Reversing addresses: '\(pickupAddress)' ↔ '\(dropAddress)'")
        
        // Show reversing animation
        isReversing = true
        
        // Set flag to disable suggestions during programmatic update
        isSettingQuickAddresses = true
        
        // Swap the addresses
        let tempAddress = pickupAddress
        pickupAddress = dropAddress
        dropAddress = tempAddress
        
        // Reset reversing animation after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isReversing = false
        }
        
        // Reset flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSettingQuickAddresses = false
            print("🔓 Re-enabled suggestions after reverse")
        }
        
        // Auto-trigger route calculation after reversing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            getRoute()
        }
    }
    
    private func resolveAddress(_ address: String) -> String {
        switch address {
        case "Home":
            if profileStore.profile.homeAddress.isEmpty {
                print("⚠️ Home address not set in profile, using placeholder")
                return "Home Address" // This will cause geocoding to fail gracefully
            }
            print("✅ Using home address: \(profileStore.profile.homeAddress)")
            return profileStore.profile.homeAddress
        case "Work":
            if profileStore.profile.workAddress.isEmpty {
                print("⚠️ Work address not set in profile, using placeholder")
                return "Work Address" // This will cause geocoding to fail gracefully
            }
            print("✅ Using work address: \(profileStore.profile.workAddress)")
            return profileStore.profile.workAddress
        default:
            return address
        }
    }

    // MARK: - Route Calculation
    private func getRoute() {
        let geocoder = CLGeocoder()
        
        print("🗺️ Getting route from: '\(pickupAddress)' to '\(dropAddress)'")
        
        geocoder.geocodeAddressString(pickupAddress) { pickupPlacemarks, _ in
            guard let pickupPlacemark = pickupPlacemarks?.first else { 
                print("❌ Failed to geocode pickup address: \(pickupAddress)")
                return 
            }
            geocoder.geocodeAddressString(dropAddress) { dropPlacemarks, _ in
                guard let dropPlacemark = dropPlacemarks?.first else { 
                    print("❌ Failed to geocode dropoff address: \(dropAddress)")
                    return 
                }

                let request = MKDirections.Request()
                request.source = MKMapItem(placemark: MKPlacemark(placemark: pickupPlacemark))
                request.destination = MKMapItem(placemark: MKPlacemark(placemark: dropPlacemark))
                request.transportType = .automobile

                let directions = MKDirections(request: request)
                directions.calculate { response, _ in
                    if let route = response?.routes.first {
                        self.route = route
                        self.showMap = true
                    }
                }
            }
        }
    }
}
