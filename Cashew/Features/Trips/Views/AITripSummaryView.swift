import SwiftUI
import UIKit
import os

// MARK: - ViewModel

@Observable
final class AITripSummaryViewModel {

    enum Phase {
        case idle
        case loading
        case result(AITripSummaryResponse)
        case error(String)
    }

    var phase: Phase = .idle
    var selectedTone: AITripSummaryTone = .warm
    var isRegenerating: Bool = false

    private let service: AITripSummaryServiceProtocol
    let trip: Trip

    init(trip: Trip, service: AITripSummaryServiceProtocol = AITripSummaryService()) {
        self.trip = trip
        self.service = service
        if let cached = AIJournalCache.load(
            tripId: trip.id,
            tone: selectedTone,
            contentHash: currentContentHash()
        ) {
            phase = .result(cached)
        }
    }

    var response: AITripSummaryResponse? {
        guard case .result(let r) = phase else { return nil }
        return r
    }

    var hasAnyContentToSummarize: Bool {
        !trip.activities.isEmpty
            || !trip.expenses.isEmpty
            || !trip.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func generate() async {
        if let cached = AIJournalCache.load(
            tripId: trip.id,
            tone: selectedTone,
            contentHash: currentContentHash()
        ) {
            phase = .result(cached)
            return
        }

        guard hasAnyContentToSummarize else {
            phase = .error("Add some activities, expenses, or notes to your trip first, then come back for a journal.")
            return
        }

        phase = .loading
        do {
            let response = try await service.generateSummary(request: buildRequest(tone: selectedTone))
            AIJournalCache.save(
                response,
                tripId: trip.id,
                tone: selectedTone,
                contentHash: currentContentHash()
            )
            phase = .result(response)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    @MainActor
    func regenerate(tone: AITripSummaryTone) async {
        selectedTone = tone

        if let cached = AIJournalCache.load(
            tripId: trip.id,
            tone: tone,
            contentHash: currentContentHash()
        ) {
            phase = .result(cached)
            return
        }

        guard hasAnyContentToSummarize else {
            phase = .error("Add some activities, expenses, or notes to your trip first, then come back for a journal.")
            return
        }

        isRegenerating = true
        defer { isRegenerating = false }

        do {
            let response = try await service.generateSummary(request: buildRequest(tone: tone))
            AIJournalCache.save(
                response,
                tripId: trip.id,
                tone: tone,
                contentHash: currentContentHash()
            )
            phase = .result(response)
        } catch {
            Log.ai.error("Trip summary regeneration failed: \(error.localizedDescription)")
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - Private

    private func buildRequest(tone: AITripSummaryTone) -> AITripSummaryRequest {
        let activitiesInput = trip.activities.map { a in
            AITripSummaryActivity(
                title: a.title,
                date: DateFormatting.isoDate.string(from: a.date),
                category: a.category.rawValue,
                estimatedCost: a.cost.map { NSDecimalNumber(decimal: $0).doubleValue },
                location: a.location.isEmpty ? nil : a.location,
                address: a.address.isEmpty ? nil : a.address,
                startTime: a.startTime.map { DateFormatting.time24.string(from: $0) },
                endTime: a.endTime.map { DateFormatting.time24.string(from: $0) },
                notes: a.notes.isEmpty ? nil : a.notes
            )
        }

        let expensesInput = trip.expenses.map { e in
            AITripSummaryExpense(
                title: e.title,
                amount: NSDecimalNumber(decimal: e.amount).doubleValue,
                category: e.category.rawValue,
                date: DateFormatting.isoDate.string(from: e.date),
                notes: e.notes.isEmpty ? nil : e.notes
            )
        }

        let totalSpent = trip.expenses.reduce(Decimal.zero) { $0 + $1.amount }

        return AITripSummaryRequest(
            tripName: trip.name,
            destination: trip.destination,
            startDate: DateFormatting.isoDate.string(from: trip.startDate),
            endDate: DateFormatting.isoDate.string(from: trip.endDate),
            currency: trip.currency,
            totalBudget: trip.budget.map { NSDecimalNumber(decimal: $0).doubleValue },
            totalSpent: NSDecimalNumber(decimal: totalSpent).doubleValue,
            tone: tone.rawValue,
            notes: trip.notes.isEmpty ? nil : trip.notes,
            accommodationName: trip.accommodationName.isEmpty ? nil : trip.accommodationName,
            accommodationAddress: trip.accommodationAddress.isEmpty ? nil : trip.accommodationAddress,
            transportationType: trip.transportationType.isEmpty ? nil : trip.transportationType,
            transportationDetails: trip.transportationDetails.isEmpty ? nil : trip.transportationDetails,
            activities: activitiesInput,
            expenses: expensesInput
        )
    }

    private func currentContentHash() -> String {
        AIJournalCache.contentHash(
            activityCount: trip.activities.count,
            expenseCount: trip.expenses.count,
            updatedAt: trip.updatedAt,
            notes: trip.notes,
            accommodationName: trip.accommodationName,
            accommodationAddress: trip.accommodationAddress,
            transportationType: trip.transportationType,
            transportationDetails: trip.transportationDetails
        )
    }
}

// MARK: - View

struct AITripSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let trip: Trip
    @State private var viewModel: AITripSummaryViewModel
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    init(trip: Trip, viewModel: AITripSummaryViewModel? = nil) {
        self.trip = trip
        self._viewModel = State(initialValue: viewModel ?? AITripSummaryViewModel(trip: trip))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                switch viewModel.phase {
                case .idle:
                    idlePhase
                case .loading:
                    loadingPhase
                case .result(let summary):
                    resultPhase(summary)
                case .error(let message):
                    errorPhase(message)
                }
            }
            .navigationTitle("Trip Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let summary = viewModel.response {
                    ToolbarItem(placement: .primaryAction) {
                        toolbarMenu(summary: summary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Toolbar

    private func toolbarMenu(summary: AITripSummaryResponse) -> some View {
        Menu {
            Button {
                shareURL = AITripSummaryPDFRenderer.makePDF(
                    response: summary,
                    tripName: trip.name,
                    destination: trip.destination,
                    startDate: trip.startDate,
                    endDate: trip.endDate
                )
                showShareSheet = shareURL != nil
            } label: {
                Label("Share as PDF", systemImage: "doc.richtext")
            }

            Menu("Copy") {
                Button("Everything") { copyToPasteboard(summary.toMarkdown(tripName: trip.name)) }
                Button("Overview") { copyToPasteboard(summary.overviewText()) }
                Button("Highlights") { copyToPasteboard(summary.highlightsText()) }
                Button("Day by Day") { copyToPasteboard(summary.dailyRecapText()) }
                Button("Budget") { copyToPasteboard(summary.budgetText()) }
                Button("Fun Facts") { copyToPasteboard(summary.funFactsText()) }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    // MARK: - Idle

    private var idlePhase: some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            Image(systemName: "book.pages.fill")
                .font(AppTheme.TextStyle.displayLarge)
                .foregroundStyle(AppTheme.tripGradient)
            Text("Generate a beautiful summary of your trip to \(trip.destination)")
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Space.xl)
            Button {
                Task { await viewModel.generate() }
            } label: {
                Label("Generate Summary", systemImage: "sparkles")
                    .primaryActionButton(gradient: AppTheme.tripGradient)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.Space.xl)
            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingPhase: some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            RotatingCaption(lines: [
                "Reading your itinerary…",
                "Finding the story…",
                "Polishing the prose…"
            ])
            Spacer()
        }
    }

    // MARK: - Result

    private func resultPhase(_ summary: AITripSummaryResponse) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.lg) {
                tonePills

                TripSectionCard("Overview", icon: "text.quote") {
                    Text(summary.overview)
                        .font(AppTheme.TextStyle.body)
                        .foregroundStyle(AppTheme.onSurface)
                }

                if !summary.highlights.isEmpty {
                    TripSectionCard("Highlights", icon: "star.fill") {
                        VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                            ForEach(Array(summary.highlights.enumerated()), id: \.offset) { _, highlight in
                                HStack(alignment: .top, spacing: AppTheme.Space.sm) {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppTheme.tripGradient)
                                        .padding(.top, 3)
                                    Text(highlight)
                                        .font(AppTheme.TextStyle.body)
                                        .foregroundStyle(AppTheme.onSurface)
                                }
                            }
                        }
                    }
                }

                if !summary.dailyRecap.isEmpty {
                    TripSectionCard("Day by Day", icon: "calendar") {
                        VStack(alignment: .leading, spacing: AppTheme.cardInternalSpacing) {
                            ForEach(summary.dailyRecap) { recap in
                                VStack(alignment: .leading, spacing: 4) {
                                    let label = DateFormatting.isoDate.date(from: recap.date)
                                        .map { DateFormatting.shortDayMonth.string(from: $0) } ?? recap.date
                                    Text(label)
                                        .font(AppTheme.TextStyle.captionBold)
                                        .foregroundStyle(AppTheme.primary)
                                    Text(recap.summary)
                                        .font(AppTheme.TextStyle.body)
                                        .foregroundStyle(AppTheme.onSurface)
                                }
                            }
                        }
                    }
                }

                TripSectionCard("Budget", icon: "dollarsign.circle.fill") {
                    VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                        if let budget = summary.budgetRecap.totalBudget {
                            HStack {
                                Text("Budget")
                                    .font(AppTheme.TextStyle.secondary)
                                Spacer()
                                Text("\(summary.budgetRecap.currency) \(budget, specifier: "%.0f")")
                                    .font(AppTheme.TextStyle.bodyBold)
                            }
                        }
                        if let spent = summary.budgetRecap.totalSpent {
                            HStack {
                                Text("Spent")
                                    .font(AppTheme.TextStyle.secondary)
                                Spacer()
                                Text("\(summary.budgetRecap.currency) \(spent, specifier: "%.0f")")
                                    .font(AppTheme.TextStyle.bodyBold)
                            }
                        }
                        Text(summary.budgetRecap.verdict)
                            .font(AppTheme.TextStyle.body)
                            .foregroundStyle(AppTheme.primary)
                            .padding(.top, 4)
                    }
                }

                if !summary.funFacts.isEmpty {
                    TripSectionCard("Fun Facts", icon: "lightbulb.fill") {
                        VStack(alignment: .leading, spacing: AppTheme.Space.sm) {
                            ForEach(Array(summary.funFacts.enumerated()), id: \.offset) { _, fact in
                                HStack(alignment: .top, spacing: AppTheme.Space.sm) {
                                    Text("\u{2022}")
                                        .foregroundStyle(AppTheme.primary)
                                    Text(fact)
                                        .font(AppTheme.TextStyle.body)
                                        .foregroundStyle(AppTheme.onSurface)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, AppTheme.Space.lg)
        }
    }

    private var tonePills: some View {
        VStack(spacing: AppTheme.Space.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.sm) {
                    ForEach(AITripSummaryTone.allCases) { tone in
                        TonePill(
                            tone: tone,
                            isSelected: tone == viewModel.selectedTone,
                            isLoading: viewModel.isRegenerating && tone == viewModel.selectedTone
                        ) {
                            guard tone != viewModel.selectedTone, !viewModel.isRegenerating else { return }
                            Task { await viewModel.regenerate(tone: tone) }
                        }
                        .disabled(viewModel.isRegenerating)
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
            }
            if viewModel.isRegenerating {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Error

    private func errorPhase(_ message: String) -> some View {
        VStack(spacing: AppTheme.Space.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.negative)
            Text(message)
                .font(AppTheme.TextStyle.body)
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if viewModel.hasAnyContentToSummarize {
                Button {
                    Task { await viewModel.generate() }
                } label: {
                    Text("Try Again")
                        .primaryActionButton(gradient: AppTheme.tripGradient)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppTheme.Space.xl)
            }
            Spacer()
        }
    }
}

// MARK: - Tone Pill

private struct TonePill: View {
    let tone: AITripSummaryTone
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white)
                } else {
                    Image(systemName: tone.icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(tone.displayName)
                    .font(AppTheme.TextStyle.captionBold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        AppTheme.tripGradient
                    } else {
                        AppTheme.surface
                    }
                }
            )
            .foregroundStyle(isSelected ? .white : AppTheme.onSurface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : AppTheme.onSurfaceVariant.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rotating Caption

private struct RotatingCaption: View {
    let lines: [String]
    @State private var index = 0

    var body: some View {
        Text(lines[index])
            .font(AppTheme.TextStyle.body)
            .foregroundStyle(AppTheme.onSurfaceVariant)
            .id(index)
            .transition(.opacity)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeInOut(duration: 0.4)) {
                        index = (index + 1) % lines.count
                    }
                }
            }
    }
}
