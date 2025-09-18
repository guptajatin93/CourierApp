import Foundation
import SwiftUI
import FirebaseFirestore

struct Order: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var driverId: String? = nil
    let pickup: String
    let dropoff: String
    let size: String
    let weight: String
    let fragile: Bool
    let speed: String
    let instructions: String?
    let cost: Double
    let distance: Double
    let etaMinutes: Int
    let createdAt: Date
    var status: OrderStatus
    var assignedAt: Date? = nil
    var pickedUpAt: Date? = nil
    var deliveredAt: Date? = nil
    var deliveryPhotoURL: String? = nil
    var deliveryNotes: String? = nil

    init(
        id: String? = nil,
        userId: String,
        driverId: String? = nil,
        pickup: String,
        dropoff: String,
        size: String,
        weight: String,
        fragile: Bool,
        speed: String,
        instructions: String? = nil,
        cost: Double,
        distance: Double,
        etaMinutes: Int,
        status: OrderStatus = .pending
    ) {
        self.id = id
        self.userId = userId
        self.driverId = driverId
        self.pickup = pickup
        self.dropoff = dropoff
        self.size = size
        self.weight = weight
        self.fragile = fragile
        self.speed = speed
        self.instructions = instructions
        self.cost = cost
        self.distance = distance
        self.etaMinutes = etaMinutes
        self.createdAt = Date()
        self.status = status
    }
}

enum OrderStatus: String, Codable, CaseIterable {
    case pending = "pending"           // Order created, waiting for driver
    case assigned = "assigned"         // Driver accepted the order
    case pickedUp = "picked_up"        // Driver picked up the package
    case inTransit = "in_transit"      // Driver is delivering
    case delivered = "delivered"       // Order completed
    case cancelled = "cancelled"       // Order cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .assigned: return "Assigned"
        case .pickedUp: return "Picked Up"
        case .inTransit: return "In Transit"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .assigned: return .blue
        case .pickedUp: return .purple
        case .inTransit: return .green
        case .delivered: return .gray
        case .cancelled: return .red
        }
    }
}
