import Foundation

protocol TripRepositoryProtocol: AnyObject {
    func fetchAll() async throws -> [Trip]
    func fetch(by id: UUID) async throws -> Trip
    @discardableResult func save(_ trip: Trip) async throws -> Trip
    func delete(by id: UUID) async throws
}
