import Foundation

protocol EventRepositoryProtocol: AnyObject {
    func fetchAll() async throws -> [Event]
    func fetch(by id: UUID) async throws -> Event
    @discardableResult func save(_ event: Event) async throws -> Event
    func delete(by id: UUID) async throws
}
