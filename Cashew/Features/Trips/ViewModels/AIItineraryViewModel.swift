import Foundation
import os

@Observable
final class AIItineraryViewModel {

    enum Phase {
        case configure
        case loading
        case review([AIActivity])
        case error(String)
        case noBudget
    }

    // Configure state
    var selectedInterests: Set<String> = []
    var budgetAllocationString: String = ""
    var userNote: String = ""
    var selectedVibe: TripVibe? = nil
    var selectedPace: TripPace = .balanced

    static let userNoteCharLimit = 500

    // Review state
    var phase: Phase = .configure
    var selectedIDs: Set<String> = []
    var selectedMapDay: String? = nil  // "YYYY-MM-DD" or nil = show all days
    var regeneratingDay: String? = nil // date string currently being regenerated

    private let service: AIItineraryServiceProtocol
    let trip: Trip

    @ObservationIgnored private var generateTask: Task<Void, Never>?
    @ObservationIgnored private var regenerateTask: Task<Void, Never>?

    init(trip: Trip, service: AIItineraryServiceProtocol = AIItineraryService()) {
        self.trip = trip
        self.service = service
        // Pre-fill allocation from remaining budget, else total budget
        if let remaining = trip.remainingBudget, remaining > 0 {
            budgetAllocationString = "\(NSDecimalNumber(decimal: remaining).doubleValue)"
        } else if let budget = trip.budget {
            budgetAllocationString = "\(NSDecimalNumber(decimal: budget).doubleValue)"
        }
    }

    // MARK: - Computed

    var hasBudget: Bool { trip.budget != nil }
    var budgetAllocation: Double { Double(budgetAllocationString) ?? 0 }
    var canGenerate: Bool {
        !selectedInterests.isEmpty
            && budgetAllocation > 0
            && userNote.count <= Self.userNoteCharLimit
    }

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    let availableInterests: [ItineraryInterest] = ItineraryInterest.catalog

    var reviewActivities: [AIActivity] {
        guard case .review(let a) = phase else { return [] }
        return a
    }

    var activitiesByDay: [(date: String, items: [AIActivity])] {
        let base = selectedMapDay.map { day in reviewActivities.filter { $0.date == day } }
            ?? reviewActivities
        let grouped = Dictionary(grouping: base) { $0.date }
        return grouped.keys.sorted().map { d in
            (date: d, items: grouped[d]!.sorted { ($0.startTime ?? "") < ($1.startTime ?? "") })
        }
    }

    var visibleMapActivities: [AIActivity] {
        let base = selectedMapDay.map { day in reviewActivities.filter { $0.date == day } }
            ?? reviewActivities
        return base.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var selectedCount: Int { selectedIDs.count }

    // MARK: - Actions

    func toggleInterest(_ i: String) {
        if selectedInterests.contains(i) { selectedInterests.remove(i) }
        else { selectedInterests.insert(i) }
    }

    func toggleActivity(_ a: AIActivity) {
        if selectedIDs.contains(a.id) { selectedIDs.remove(a.id) }
        else { selectedIDs.insert(a.id) }
    }

    func selectAll() {
        selectedIDs = Set(reviewActivities.map(\.id))
    }

    private func buildRequest(targetDate: String? = nil) -> AIItineraryRequest {
        let trimmedNote = userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return AIItineraryRequest(
            destination: trip.destination,
            destinationLatitude: trip.destinationLatitude,
            destinationLongitude: trip.destinationLongitude,
            startDate: DateFormatting.isoDate.string(from: trip.startDate),
            endDate: DateFormatting.isoDate.string(from: trip.endDate),
            tripCurrency: trip.currency,
            budgetAllocation: budgetAllocation,
            interests: Array(selectedInterests),
            existingActivityTitles: trip.activities.map(\.title),
            targetDate: targetDate,
            userNote: trimmedNote.isEmpty ? nil : trimmedNote,
            vibe: selectedVibe?.rawValue,
            pace: selectedPace.rawValue
        )
    }

    @MainActor
    func generate() async {
        phase = .loading

        let request = buildRequest()

        do {
            let response = try await service.generateItinerary(request: request)
            try Task.checkCancellation()
            selectedIDs = Set(response.activities.map(\.id))
            phase = .review(response.activities)
        } catch is CancellationError {
            // Sheet dismissed mid-flight; leave state alone.
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func buildSelectedActivities() -> [Activity] {
        reviewActivities
            .filter { selectedIDs.contains($0.id) }
            .map { $0.toActivity(tripStartDate: trip.startDate, tripCurrency: trip.currency) }
    }

    @MainActor
    func regenerateDay(_ dateString: String) async {
        // Single-flight: tracking state and merge logic assume one regenerate at a time.
        guard regeneratingDay == nil else { return }
        regeneratingDay = dateString

        let request = buildRequest(targetDate: dateString)

        do {
            let response = try await service.generateItinerary(request: request)
            try Task.checkCancellation()

            // Remove old activities for this day, keep others
            guard case .review(let current) = phase else {
                regeneratingDay = nil
                return
            }
            let kept = current.filter { $0.date != dateString }
            let merged = kept + response.activities

            // Select new activities
            for a in response.activities { selectedIDs.insert(a.id) }

            phase = .review(merged)
        } catch is CancellationError {
            // View dismissed; don't mutate state further.
        } catch {
            Log.ai.error("Day regeneration failed for \(dateString): \(error.localizedDescription)")
        }

        regeneratingDay = nil
    }

    @MainActor
    func startGenerate() {
        generateTask?.cancel()
        generateTask = Task { [weak self] in
            await self?.generate()
        }
    }

    @MainActor
    func startRegenerateDay(_ dateString: String) {
        guard regenerateTask == nil else { return }
        regenerateTask = Task { [weak self] in
            await self?.regenerateDay(dateString)
            self?.regenerateTask = nil
        }
    }

    @MainActor
    func cancelInFlight() {
        generateTask?.cancel()
        generateTask = nil
        regenerateTask?.cancel()
        regenerateTask = nil
        regeneratingDay = nil
    }
}
