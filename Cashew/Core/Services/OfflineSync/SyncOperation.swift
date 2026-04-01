import Foundation

enum SyncEntityType: String, Codable, Sendable {
    case trip
    case event
    case dailyTask
    case dailyRoutine
}

enum SyncOperationKind: String, Codable, Sendable {
    case upsert
    case delete
}

enum SyncPayload: Codable, Sendable {
    case trip(Trip)
    case event(Event)
    case dailyTask(DailyTask)
    case dailyRoutine(DailyRoutine)

    private enum CodingKeys: String, CodingKey {
        case type
        case trip
        case event
        case dailyTask
        case dailyRoutine
    }

    private enum PayloadType: String, Codable {
        case trip
        case event
        case dailyTask
        case dailyRoutine
    }

    var entityType: SyncEntityType {
        switch self {
        case .trip:
            return .trip
        case .event:
            return .event
        case .dailyTask:
            return .dailyTask
        case .dailyRoutine:
            return .dailyRoutine
        }
    }

    var entityID: UUID {
        switch self {
        case .trip(let trip):
            return trip.id
        case .event(let event):
            return event.id
        case .dailyTask(let task):
            return task.id
        case .dailyRoutine(let routine):
            return routine.id
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PayloadType.self, forKey: .type)

        switch type {
        case .trip:
            self = .trip(try container.decode(Trip.self, forKey: .trip))
        case .event:
            self = .event(try container.decode(Event.self, forKey: .event))
        case .dailyTask:
            self = .dailyTask(try container.decode(DailyTask.self, forKey: .dailyTask))
        case .dailyRoutine:
            self = .dailyRoutine(try container.decode(DailyRoutine.self, forKey: .dailyRoutine))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .trip(let trip):
            try container.encode(PayloadType.trip, forKey: .type)
            try container.encode(trip, forKey: .trip)
        case .event(let event):
            try container.encode(PayloadType.event, forKey: .type)
            try container.encode(event, forKey: .event)
        case .dailyTask(let task):
            try container.encode(PayloadType.dailyTask, forKey: .type)
            try container.encode(task, forKey: .dailyTask)
        case .dailyRoutine(let routine):
            try container.encode(PayloadType.dailyRoutine, forKey: .type)
            try container.encode(routine, forKey: .dailyRoutine)
        }
    }
}

struct SyncOperation: Identifiable, Codable, Sendable {
    let id: UUID
    let entityType: SyncEntityType
    let kind: SyncOperationKind
    let entityID: UUID
    var payload: SyncPayload?
    let occurredAt: Date
    var retryCount: Int
    var nextAttemptAt: Date

    init(
        id: UUID = UUID(),
        entityType: SyncEntityType,
        kind: SyncOperationKind,
        entityID: UUID,
        payload: SyncPayload?,
        occurredAt: Date = Date(),
        retryCount: Int = 0,
        nextAttemptAt: Date? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.kind = kind
        self.entityID = entityID
        self.payload = payload
        self.occurredAt = occurredAt
        self.retryCount = retryCount
        self.nextAttemptAt = nextAttemptAt ?? occurredAt
    }

    static func upsert(_ payload: SyncPayload, at date: Date = Date()) -> SyncOperation {
        SyncOperation(
            entityType: payload.entityType,
            kind: .upsert,
            entityID: payload.entityID,
            payload: payload,
            occurredAt: date
        )
    }

    static func delete(entityType: SyncEntityType, entityID: UUID, at date: Date = Date()) -> SyncOperation {
        SyncOperation(
            entityType: entityType,
            kind: .delete,
            entityID: entityID,
            payload: nil,
            occurredAt: date
        )
    }
}
