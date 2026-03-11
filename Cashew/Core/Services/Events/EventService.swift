import Foundation
import Observation

@Observable
@MainActor
final class EventService: EventServiceProtocol {

    private let repository: EventRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?

    private(set) var events: [Event] = []

    init(repository: EventRepositoryProtocol, notificationService: NotificationServiceProtocol? = nil) {
        self.repository = repository
        self.notificationService = notificationService
    }

    func loadEvents() async throws {
        events = try await repository.fetchAll()
    }

    func createEvent(_ event: Event) async throws {
        let savedEvent = try await repository.save(event)
        events.append(savedEvent)
        sortEvents()

        // Schedule notifications for the new event
        if !savedEvent.reminders.isEmpty {
            await notificationService?.scheduleNotifications(for: savedEvent)
        }
    }

    func updateEvent(_ event: Event) async throws {
        let savedEvent = try await repository.save(event)
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = savedEvent
            sortEvents()
        }

        // Update notifications for the event
        await notificationService?.updateNotifications(for: savedEvent)
    }

    func deleteEvent(by id: UUID) async throws {
        try await repository.delete(by: id)
        events.removeAll { $0.id == id }

        // Cancel notifications for the deleted event
        await notificationService?.cancelNotifications(for: id)
    }

    func event(by id: UUID) -> Event? {
        events.first { $0.id == id }
    }

    private func sortEvents() {
        events.sort { $0.date < $1.date }
    }
}
