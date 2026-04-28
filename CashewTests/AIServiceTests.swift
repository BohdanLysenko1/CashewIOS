import Foundation
import XCTest
@testable import Cashew

// MARK: - Mock Services

private struct MockPackingListService: AIPackingListServiceProtocol {
    let result: Result<AIPackingListResponse, Error>

    func generatePackingList(request: AIPackingListRequest) async throws -> AIPackingListResponse {
        try result.get()
    }
}

private struct MockTripSummaryService: AITripSummaryServiceProtocol {
    let result: Result<AITripSummaryResponse, Error>

    func generateSummary(request: AITripSummaryRequest) async throws -> AITripSummaryResponse {
        try result.get()
    }
}

// `@unchecked Sendable` is safe here: tests are single-threaded and `@MainActor`-isolated,
// so the mutable storage below is never accessed concurrently.
private final class RecordingTripSummaryService: AITripSummaryServiceProtocol, @unchecked Sendable {
    var responseByTone: [String: AITripSummaryResponse] = [:]
    var defaultResponse: AITripSummaryResponse?
    private(set) var receivedRequests: [AITripSummaryRequest] = []

    func generateSummary(request: AITripSummaryRequest) async throws -> AITripSummaryResponse {
        receivedRequests.append(request)
        if let r = responseByTone[request.tone] { return r }
        if let r = defaultResponse { return r }
        throw AITripSummaryError.functionError("no stub for tone \(request.tone)")
    }
}

// MARK: - Packing List Tests

@MainActor
final class AIPackingListViewModelTests: XCTestCase {

    private func makeTrip() -> Trip {
        Trip(
            name: "Beach Trip",
            destination: "Cancun",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            currency: "USD"
        )
    }

    func testGenerateSuccess_selectsAllItems() async {
        let response = AIPackingListResponse(categories: [
            AIPackingCategory(category: "clothing", items: [
                AIPackingItem(name: "T-Shirts", quantity: 3, essential: true),
                AIPackingItem(name: "Shorts", quantity: 2, essential: false)
            ]),
            AIPackingCategory(category: "toiletries", items: [
                AIPackingItem(name: "Sunscreen", quantity: 1, essential: true)
            ])
        ])
        let service = MockPackingListService(result: .success(response))
        let vm = AIPackingListViewModel(trip: makeTrip(), service: service)

        await vm.generate()

        guard case .review(let resp) = vm.phase else {
            return XCTFail("Expected review phase")
        }
        XCTAssertEqual(resp.categories.count, 2)
        XCTAssertEqual(vm.selectedCount, 3)
    }

    func testSelectEssentials_onlySelectsEssentialItems() async {
        let response = AIPackingListResponse(categories: [
            AIPackingCategory(category: "clothing", items: [
                AIPackingItem(name: "T-Shirts", quantity: 3, essential: true),
                AIPackingItem(name: "Fancy Hat", quantity: 1, essential: false)
            ])
        ])
        let service = MockPackingListService(result: .success(response))
        let vm = AIPackingListViewModel(trip: makeTrip(), service: service)

        await vm.generate()
        vm.selectEssentials()

        XCTAssertEqual(vm.selectedCount, 1)
        XCTAssertTrue(vm.isItemSelected("clothing", AIPackingItem(name: "T-Shirts", quantity: 3, essential: true)))
        XCTAssertFalse(vm.isItemSelected("clothing", AIPackingItem(name: "Fancy Hat", quantity: 1, essential: false)))
    }

    func testGenerateFailure_setsErrorPhase() async {
        let service = MockPackingListService(result: .failure(AIPackingListError.functionError("Server error")))
        let vm = AIPackingListViewModel(trip: makeTrip(), service: service)

        await vm.generate()

        guard case .error(let msg) = vm.phase else {
            return XCTFail("Expected error phase")
        }
        XCTAssertTrue(msg.contains("Server error"))
    }

    func testGenerateDecodingFailure_setsErrorPhase() async {
        struct StubDecodeError: Error {}
        let service = MockPackingListService(result: .failure(AIPackingListError.decodingFailed(StubDecodeError())))
        let vm = AIPackingListViewModel(trip: makeTrip(), service: service)

        await vm.generate()

        guard case .error(let msg) = vm.phase else {
            return XCTFail("Expected error phase")
        }
        XCTAssertTrue(msg.lowercased().contains("decode"), "Expected decode-failure surface, got: \(msg)")
    }

    func testBuildPackingItems_returnsOnlySelected() async {
        let response = AIPackingListResponse(categories: [
            AIPackingCategory(category: "clothing", items: [
                AIPackingItem(name: "T-Shirts", quantity: 3, essential: true),
                AIPackingItem(name: "Shorts", quantity: 2, essential: false)
            ])
        ])
        let service = MockPackingListService(result: .success(response))
        let vm = AIPackingListViewModel(trip: makeTrip(), service: service)

        await vm.generate()
        vm.selectEssentials() // Only T-Shirts

        let items = vm.buildPackingItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.name, "T-Shirts")
        XCTAssertEqual(items.first?.quantity, 3)
    }
}

// MARK: - Trip Summary Tests

@MainActor
final class AITripSummaryViewModelTests: XCTestCase {

    private func makeTrip(activities: [Activity]? = nil, notes: String = "") -> Trip {
        let defaultActivity = Activity(
            title: "Colosseum visit",
            date: Date(),
            category: .museum
        )
        return Trip(
            id: UUID(),
            name: "Italy Trip",
            destination: "Rome",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            notes: notes,
            currency: "EUR",
            activities: activities ?? [defaultActivity]
        )
    }

    private func sampleResponse(overview: String = "An amazing trip!") -> AITripSummaryResponse {
        AITripSummaryResponse(
            overview: overview,
            highlights: ["Colosseum visit", "Best pasta"],
            dailyRecap: [AIDailyRecap(date: "2025-06-01", summary: "Explored the old city")],
            budgetRecap: AIBudgetRecap(totalBudget: 2000, totalSpent: 1500, currency: "EUR", verdict: "Under budget"),
            funFacts: ["Rome has over 900 churches"]
        )
    }

    private func clearJournalCache() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("ai_journal_v1_") {
            defaults.removeObject(forKey: key)
        }
    }

    override func setUp() {
        super.setUp()
        clearJournalCache()
    }

    override func tearDown() {
        clearJournalCache()
        super.tearDown()
    }

    func testGenerateSuccess() async {
        let service = MockTripSummaryService(result: .success(sampleResponse()))
        let vm = AITripSummaryViewModel(trip: makeTrip(), service: service)

        await vm.generate()

        guard case .result(let r) = vm.phase else {
            return XCTFail("Expected result phase")
        }
        XCTAssertEqual(r.overview, "An amazing trip!")
        XCTAssertEqual(r.highlights.count, 2)
        XCTAssertEqual(r.dailyRecap.count, 1)
    }

    func testGenerateFailure() async {
        let service = MockTripSummaryService(result: .failure(AITripSummaryError.functionError("Timeout")))
        let vm = AITripSummaryViewModel(trip: makeTrip(), service: service)

        await vm.generate()

        guard case .error(let msg) = vm.phase else {
            return XCTFail("Expected error phase")
        }
        XCTAssertTrue(msg.contains("Timeout"))
    }

    func testGenerateDecodingFailure_setsErrorPhase() async {
        struct StubDecodeError: Error {}
        let service = MockTripSummaryService(result: .failure(AITripSummaryError.decodingFailed(StubDecodeError())))
        let vm = AITripSummaryViewModel(trip: makeTrip(), service: service)

        await vm.generate()

        guard case .error(let msg) = vm.phase else {
            return XCTFail("Expected error phase")
        }
        XCTAssertTrue(msg.lowercased().contains("decode"), "Expected decode-failure surface, got: \(msg)")
    }

    func testGenerateSuccess_cachesResponse() async {
        let trip = makeTrip()
        let service = RecordingTripSummaryService()
        service.defaultResponse = sampleResponse()

        let vm1 = AITripSummaryViewModel(trip: trip, service: service)
        await vm1.generate()
        XCTAssertEqual(service.receivedRequests.count, 1)

        // Second viewmodel for the same trip + tone should load from cache without another network call.
        let vm2 = AITripSummaryViewModel(trip: trip, service: service)
        guard case .result = vm2.phase else {
            return XCTFail("Expected cached result on re-init")
        }
        XCTAssertEqual(service.receivedRequests.count, 1, "Service should not be called again on cache hit")

        // Explicit generate() should also hit cache, not the service.
        await vm2.generate()
        XCTAssertEqual(service.receivedRequests.count, 1)
    }

    func testRegenerate_withNewTone_callsServiceAndUpdatesTone() async {
        let trip = makeTrip()
        let service = RecordingTripSummaryService()
        service.responseByTone["warm"] = sampleResponse(overview: "Warm take")
        service.responseByTone["poetic"] = sampleResponse(overview: "Poetic take")

        let vm = AITripSummaryViewModel(trip: trip, service: service)
        await vm.generate()
        XCTAssertEqual(vm.response?.overview, "Warm take")
        XCTAssertEqual(service.receivedRequests.count, 1)
        XCTAssertEqual(service.receivedRequests.last?.tone, "warm")

        await vm.regenerate(tone: .poetic)
        XCTAssertEqual(vm.selectedTone, .poetic)
        XCTAssertEqual(vm.response?.overview, "Poetic take")
        XCTAssertEqual(service.receivedRequests.count, 2)
        XCTAssertEqual(service.receivedRequests.last?.tone, "poetic")
        XCTAssertFalse(vm.isRegenerating)
    }

    func testEmptyTrip_showsHelpfulError() async {
        let emptyTrip = Trip(
            name: "Empty",
            destination: "Nowhere",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let service = RecordingTripSummaryService()
        service.defaultResponse = sampleResponse()

        let vm = AITripSummaryViewModel(trip: emptyTrip, service: service)
        await vm.generate()

        guard case .error(let message) = vm.phase else {
            return XCTFail("Expected error phase for empty trip")
        }
        XCTAssertTrue(message.lowercased().contains("add some activities"))
        XCTAssertEqual(service.receivedRequests.count, 0, "Service should not be called for empty trip")
    }
}

final class AITripSummaryMarkdownTests: XCTestCase {

    func testToMarkdown_includesAllSections() {
        let response = AITripSummaryResponse(
            overview: "A whirlwind week.",
            highlights: ["Sunset over the canal", "Fresh pasta"],
            dailyRecap: [AIDailyRecap(date: "2025-06-01", summary: "Arrived and wandered.")],
            budgetRecap: AIBudgetRecap(totalBudget: 1000, totalSpent: 850, currency: "EUR", verdict: "Right on target."),
            funFacts: ["Visited 3 museums"]
        )

        let md = response.toMarkdown(tripName: "Italy Trip")

        XCTAssertTrue(md.contains("# Italy Trip"))
        XCTAssertTrue(md.contains("## Overview"))
        XCTAssertTrue(md.contains("A whirlwind week."))
        XCTAssertTrue(md.contains("## Highlights"))
        XCTAssertTrue(md.contains("- Sunset over the canal"))
        XCTAssertTrue(md.contains("## Day by Day"))
        XCTAssertTrue(md.contains("## Budget"))
        XCTAssertTrue(md.contains("EUR 1000"))
        XCTAssertTrue(md.contains("Right on target."))
        XCTAssertTrue(md.contains("## Fun Facts"))
        XCTAssertTrue(md.contains("- Visited 3 museums"))
        XCTAssertTrue(md.contains("_Generated by Cashew AI Journal_"))
    }

    func testToMarkdown_omitsEmptySections() {
        let response = AITripSummaryResponse(
            overview: "Quiet trip.",
            highlights: [],
            dailyRecap: [],
            budgetRecap: AIBudgetRecap(totalBudget: nil, totalSpent: nil, currency: "USD", verdict: "Memorable."),
            funFacts: []
        )

        let md = response.toMarkdown(tripName: "Solo")

        XCTAssertFalse(md.contains("## Highlights"))
        XCTAssertFalse(md.contains("## Day by Day"))
        XCTAssertFalse(md.contains("## Fun Facts"))
        XCTAssertTrue(md.contains("## Budget"))
        XCTAssertTrue(md.contains("Memorable."))
    }
}

// MARK: - DTO Conversion Tests

final class AIPackingConversionTests: XCTestCase {

    func testAIPackingCategoryToPackingItems() {
        let cat = AIPackingCategory(category: "clothing", items: [
            AIPackingItem(name: "Jacket", quantity: 1, essential: true),
            AIPackingItem(name: "Socks", quantity: 5, essential: false)
        ])

        let items = cat.toPackingItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].name, "Jacket")
        XCTAssertEqual(items[0].quantity, 1)
        XCTAssertEqual(items[0].category, .clothing)
        XCTAssertFalse(items[0].isPacked)
    }

    func testUnknownCategoryFallsBackToOther() {
        let cat = AIPackingCategory(category: "unknown_stuff", items: [
            AIPackingItem(name: "Widget", quantity: 1, essential: false)
        ])

        let items = cat.toPackingItems()
        XCTAssertEqual(items.first?.category, .other)
    }
}

// MARK: - Itinerary Tests

private struct MockItineraryService: AIItineraryServiceProtocol, @unchecked Sendable {
    let initialResult: Result<AIItineraryResponse, Error>
    let regenerateResult: ((String) -> Result<AIItineraryResponse, Error>)?

    init(initialResult: Result<AIItineraryResponse, Error>,
         regenerateResult: ((String) -> Result<AIItineraryResponse, Error>)? = nil) {
        self.initialResult = initialResult
        self.regenerateResult = regenerateResult
    }

    func generateItinerary(request: AIItineraryRequest) async throws -> AIItineraryResponse {
        if let target = request.targetDate, let handler = regenerateResult {
            return try handler(target).get()
        }
        return try initialResult.get()
    }
}

@MainActor
final class AIItineraryViewModelTests: XCTestCase {

    private func makeTrip() -> Trip {
        Trip(
            name: "Tokyo",
            destination: "Tokyo",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            currency: "JPY"
        )
    }

    private func sampleActivity(date: String, title: String) -> AIActivity {
        AIActivity(
            title: title,
            date: date,
            startTime: "09:00",
            endTime: "10:00",
            location: "Loc",
            address: "Addr",
            notes: "Notes",
            category: "activity",
            estimatedCost: 100,
            latitude: 0,
            longitude: 0
        )
    }

    func testGenerateSuccess_movesToReviewWithAllSelected() async {
        let activities = [
            sampleActivity(date: "2025-06-01", title: "A"),
            sampleActivity(date: "2025-06-02", title: "B")
        ]
        let service = MockItineraryService(initialResult: .success(AIItineraryResponse(activities: activities)))
        let vm = AIItineraryViewModel(trip: makeTrip(), service: service)
        vm.budgetAllocationString = "1000"

        await vm.generate()

        guard case .review(let acts) = vm.phase else {
            return XCTFail("Expected review phase")
        }
        XCTAssertEqual(acts.count, 2)
        XCTAssertEqual(vm.selectedIDs.count, 2, "All generated activities should be auto-selected")
    }

    func testGenerateFailure_setsErrorPhase() async {
        let service = MockItineraryService(initialResult: .failure(AIItineraryError.functionError("Network down")))
        let vm = AIItineraryViewModel(trip: makeTrip(), service: service)
        vm.budgetAllocationString = "1000"

        await vm.generate()

        guard case .error(let msg) = vm.phase else {
            return XCTFail("Expected error phase")
        }
        XCTAssertTrue(msg.contains("Network down"))
    }

    func testGenerateDecodingFailure_setsErrorPhase() async {
        struct StubDecodeError: Error {}
        let service = MockItineraryService(initialResult: .failure(AIItineraryError.decodingFailed(StubDecodeError())))
        let vm = AIItineraryViewModel(trip: makeTrip(), service: service)
        vm.budgetAllocationString = "1000"

        await vm.generate()

        guard case .error(let msg) = vm.phase else {
            return XCTFail("Expected error phase")
        }
        XCTAssertTrue(msg.lowercased().contains("parse"), "Expected parse-failure surface, got: \(msg)")
    }

    func testRegenerateDay_singleFlight_secondCallNoOpsWhileFirstInFlight() async {
        let day1 = "2025-06-01"
        let day2 = "2025-06-02"
        let original = [
            sampleActivity(date: day1, title: "Original day1"),
            sampleActivity(date: day2, title: "Original day2"),
        ]
        let service = MockItineraryService(
            initialResult: .success(AIItineraryResponse(activities: original)),
            regenerateResult: { target in
                .success(AIItineraryResponse(activities: [self.sampleActivityRegenerated(date: target)]))
            }
        )
        let vm = AIItineraryViewModel(trip: makeTrip(), service: service)
        vm.budgetAllocationString = "1000"

        await vm.generate()
        XCTAssertEqual(vm.reviewActivities.count, 2)

        // Simulate "first regenerate already in flight" by manually setting the marker.
        // The single-flight guard at the top of regenerateDay should make the second call a no-op.
        vm.regeneratingDay = day1
        await vm.regenerateDay(day2)

        // day2 must still hold its Original activity — the second regenerate bailed.
        guard case .review(let acts) = vm.phase else {
            return XCTFail("Expected review phase")
        }
        XCTAssertTrue(
            acts.contains { $0.date == day2 && $0.title == "Original day2" },
            "Single-flight guard should have skipped the day2 regenerate"
        )
        XCTAssertEqual(vm.regeneratingDay, day1, "regeneratingDay should be untouched by the skipped call")
    }

    func testRegenerateDay_replacesActivitiesForTargetDayOnly() async {
        let day1 = "2025-06-01"
        let day2 = "2025-06-02"
        let original = [
            sampleActivity(date: day1, title: "Original day1"),
            sampleActivity(date: day2, title: "Original day2"),
        ]
        let service = MockItineraryService(
            initialResult: .success(AIItineraryResponse(activities: original)),
            regenerateResult: { target in
                .success(AIItineraryResponse(activities: [self.sampleActivityRegenerated(date: target)]))
            }
        )
        let vm = AIItineraryViewModel(trip: makeTrip(), service: service)
        vm.budgetAllocationString = "1000"

        await vm.generate()
        await vm.regenerateDay(day1)

        guard case .review(let acts) = vm.phase else {
            return XCTFail("Expected review phase")
        }
        // day1 was replaced with the regenerated activity; day2 untouched.
        XCTAssertTrue(acts.contains { $0.date == day1 && $0.title.contains("Regenerated") })
        XCTAssertFalse(acts.contains { $0.date == day1 && $0.title == "Original day1" })
        XCTAssertTrue(acts.contains { $0.date == day2 && $0.title == "Original day2" })
        XCTAssertNil(vm.regeneratingDay, "regeneratingDay should be cleared after completion")
    }

    private func sampleActivityRegenerated(date: String) -> AIActivity {
        AIActivity(
            title: "Regenerated \(date)",
            date: date,
            startTime: "11:00",
            endTime: "12:00",
            location: "New Loc",
            address: "New Addr",
            notes: "Notes",
            category: "activity",
            estimatedCost: 200,
            latitude: 0,
            longitude: 0
        )
    }
}

