import SwiftUI
import MapKit

struct UserPageView: View {
    @StateObject private var orderStore = FirebaseOrderStore()
    @State private var selectedTab: Tab = .home
    @State private var pickupAddress: String = ""
    @State private var dropAddress: String = ""
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

                AddressSearchView(text: $pickupAddress, placeholder: "Pickup Address")
                AddressSearchView(text: $dropAddress, placeholder: "Dropoff Address")

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
                                Text("Driver: \(driverId)")
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
            initialEmail: initialEmail
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

    // MARK: - Route Calculation
    private func getRoute() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(pickupAddress) { pickupPlacemarks, _ in
            guard let pickupPlacemark = pickupPlacemarks?.first else { return }
            geocoder.geocodeAddressString(dropAddress) { dropPlacemarks, _ in
                guard let dropPlacemark = dropPlacemarks?.first else { return }

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
