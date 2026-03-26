import Foundation
import Observation
import Supabase

@Observable
@MainActor
final class EventService: EventServiceProtocol {

    private let repository: EventRepositoryProtocol
    private let notificationService: NotificationServiceProtocol?

    private(set) var events: [Event] = []

    // Realtime
    private var syncTask: Task<Void, Never>?

    init(repository: EventRepositoryProtocol, notificationService: NotificationServiceProtocol? = nil) {
        self.repository = repository
        self.notificationService = notificationService
    }

    // MARK: - Load

    func loadEvents() async throws {
        events = try await repository.fetchAll()
        sortEvents()
        await synchronizeNotificationSchedules()
    }

    // MARK: - CRUD

    func createEvent(_ event: Event) async throws {
        let saved = try await repository.save(event)
        events.append(saved)
        sortEvents()
        if !saved.reminders.isEmpty {
            await notificationService?.scheduleNotifications(for: saved)
        }
    }

    func updateEvent(_ event: Event) async throws {
        let saved = try await repository.save(event)
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = saved
            sortEvents()
        }
        await notificationService?.updateNotifications(for: saved)
    }

    func deleteEvent(by id: UUID) async throws {
        try await repository.delete(by: id)
        events.removeAll { $0.id == id }
        await notificationService?.cancelNotifications(for: id)
    }

    func event(by id: UUID) -> Event? {
        events.first { $0.id == id }
    }

    func refreshNotificationSchedules() async {
        if events.isEmpty {
            do {
                events = try await repository.fetchAll()
                sortEvents()
            } catch {
                print("[EventService] Failed to refresh events for notifications: \(error)")
                return
            }
        }

        await synchronizeNotificationSchedules()
    }

    private func sortEvents() {
        events.sort { $0.date < $1.date }
    }

    private func synchronizeNotificationSchedules() async {
        guard let notificationService else { return }

        for event in events {
            if event.reminders.isEmpty {
                await notificationService.cancelNotifications(for: event.id)
            } else {
                await notificationService.updateNotifications(for: event)
            }
        }
    }

    // MARK: - Realtime Sync

    func startRealtimeSync() {
        guard syncTask == nil else { return }

        syncTask = Task {
            let channel = SupabaseManager.client.channel("events-sync")
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "events")
            let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "events")
            let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "events")

            do { try await channel.subscribeWithError() }
            catch { print("[EventService] Realtime subscription failed: \(error)") }

            await withTaskGroup(of: Void.self) { group in
                group.addTask { for await action in inserts { await self.handleInsert(action) } }
                group.addTask { for await action in updates { await self.handleUpdate(action) } }
                group.addTask { for await action in deletes { await self.handleDelete(action) } }
            }
        }
    }

    func stopRealtimeSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Realtime Handlers

    private func handleInsert(_ action: InsertAction) async {
        guard let id = extractUUID(from: action.record) else { return }
        guard !events.contains(where: { $0.id == id }) else { return }
        do {
            let event = try await repository.fetch(by: id)
            events.append(event)
            sortEvents()
            await notificationService?.updateNotifications(for: event)
        } catch {
            print("[EventService] Failed to fetch inserted event \(id): \(error)")
        }
    }

    private func handleUpdate(_ action: UpdateAction) async {
        guard let id = extractUUID(from: action.record) else { return }
        do {
            let event = try await repository.fetch(by: id)
            if let index = events.firstIndex(where: { $0.id == id }) {
                events[index] = event
            } else {
                events.append(event)
            }
            sortEvents()
            await notificationService?.updateNotifications(for: event)
        } catch {
            print("[EventService] Failed to fetch updated event \(id): \(error)")
        }
    }

    private func handleDelete(_ action: DeleteAction) async {
        guard let id = extractUUID(from: action.oldRecord) else { return }
        events.removeAll { $0.id == id }
        await notificationService?.cancelNotifications(for: id)
    }

    private func extractUUID(from record: [String: AnyJSON]) -> UUID? {
        guard case .string(let str) = record["id"] else { return nil }
        return UUID(uuidString: str)
    }
}
