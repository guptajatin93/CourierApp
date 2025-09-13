import Foundation

struct Order: Codable, Identifiable {
    let id: UUID
    let pickup: String
    let dropoff: String
    let size: String
    let weight: String
    let fragile: Bool
    let speed: String
    let instructions: String
    let cost: Double
    let distance: Double
    let etaMinutes: Int

    init(
        id: UUID = UUID(),
        pickup: String,
        dropoff: String,
        size: String,
        weight: String,
        fragile: Bool,
        speed: String,
        instructions: String,
        cost: Double,
        distance: Double,
        etaMinutes: Int
    ) {
        self.id = id
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
    }
}
