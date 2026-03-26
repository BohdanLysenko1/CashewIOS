import Foundation

@MainActor
protocol EventServiceProtocol: AnyObject {
    var events: [Event] { get }

    func loadEvents() async throws
    func createEvent(_ event: Event) async throws
    func updateEvent(_ event: Event) async throws
    func deleteEvent(by id: UUID) async throws
    func event(by id: UUID) -> Event?
    func refreshNotificationSchedules() async
}
