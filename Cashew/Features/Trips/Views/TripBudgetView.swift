import SwiftUI

struct TripBudgetView: View {
    @Binding var trip: Trip
    let initialIntent: TripSectionIntent
    @State private var showAddExpense = false
    @State private var editingExpense: Expense?
    @State private var showBudgetEditor = false
    @State private var didApplyInitialIntent = false

    init(trip: Binding<Trip>, initialIntent: TripSectionIntent = .overview) {
        self._trip = trip
        self.initialIntent = initialIntent
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Space.md) {
                budgetOverviewCard

                if !trip.expenses.isEmpty {
                    expensesByCategoryCard
                }

                recentExpensesCard
            }
            .padding(.horizontal, AppTheme.Space.lg)
            .padding(.vertical, AppTheme.Space.md)
        }
        .background(AppTheme.background)
        .navigationTitle("Budget")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddExpense) {
            ExpenseFormView(trip: $trip, expense: nil)
        }
        .sheet(item: $editingExpense) { expense in
            ExpenseFormView(trip: $trip, expense: expense)
        }
        .sheet(isPresented: $showBudgetEditor) {
            BudgetEditorView(budget: Binding(
                get: { trip.budget },
                set: { trip.budget = $0 }
            ), currency: $trip.currency)
        }
        .onAppear {
            applyInitialIntentIfNeeded()
        }
    }

    // MARK: - Budget Overview

    private var budgetOverviewCard: some View {
        TripHeroCard(
            icon: "creditcard.fill",
            title: "Budget",
            subtitle: trip.budget == nil ? "Set your target and track spend" : "Monitor spending in real time"
        ) {
            HStack(spacing: AppTheme.Space.sm) {
                TripMetricPill(
                    label: "Budget",
                    value: trip.budget.map(formatCurrency(_:)) ?? "Not set"
                )
                TripMetricPill(
                    label: "Spent",
                    value: formatCurrency(trip.totalExpenses)
                )
                TripMetricPill(
                    label: "Remaining",
                    value: formatCurrency(trip.remainingBudget ?? 0)
                )
            }

            if trip.budget != nil {
                VStack(spacing: AppTheme.Space.sm) {
                    AppProgressBar(progress: trip.budgetProgress ?? 0, color: progressColor)
                        .frame(height: AppTheme.progressBarHeight)

                    HStack {
                        Text("Used \(Int((trip.budgetProgress ?? 0) * 100))%")
                            .font(AppTheme.TextStyle.captionBold)
                            .foregroundStyle(.white.opacity(0.86))
                        Spacer()
                        Button {
                            showBudgetEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .font(AppTheme.TextStyle.captionBold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.16))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                    }
                }
            } else {
                Button {
                    showBudgetEditor = true
                } label: {
                    Label("Set Budget", systemImage: "plus")
                        .font(AppTheme.TextStyle.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.16))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressColor: Color {
        guard let progress = trip.budgetProgress else { return .blue }
        if progress > 1.0 { return .red }
        if progress > 0.8 { return .orange }
        return .green
    }

    // MARK: - Expenses by Category

    private var expensesByCategoryCard: some View {
        TripSectionCard("Category Breakdown", icon: "chart.pie.fill") {
            let maxCategoryTotal = expensesByCategory.first?.total ?? 1
            VStack(spacing: AppTheme.Space.sm) {
                ForEach(expensesByCategory, id: \.category) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(item.category.displayName, systemImage: item.category.icon)
                                .font(AppTheme.TextStyle.bodyBold)
                                .foregroundStyle(AppTheme.onSurface)
                            Spacer()
                            Text(formatCurrency(item.total))
                                .font(AppTheme.TextStyle.bodyBold)
                                .foregroundStyle(AppTheme.onSurface)
                        }
                        AppProgressBar(
                            progress: progress(from: item.total, comparedTo: maxCategoryTotal),
                            color: item.category.color
                        )
                        .frame(height: AppTheme.progressBarHeight)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .tripSoftSurface()
                }
            }
        }
    }

    private var expensesByCategory: [(category: ExpenseCategory, total: Decimal)] {
        var totals: [ExpenseCategory: Decimal] = [:]
        for expense in trip.expenses {
            totals[expense.category, default: 0] += expense.amount
        }
        return totals.map { ($0.key, $0.value) }
            .sorted { $0.total > $1.total }
    }

    // MARK: - Recent Expenses

    private var recentExpensesCard: some View {
        TripSectionCard("Expenses", icon: "list.bullet.rectangle") {
            if trip.expenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    Text("No expenses yet")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    Button("Add Expense") {
                        showAddExpense = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: AppTheme.Space.sm) {
                    ForEach(trip.expenses.sorted(by: { $0.date > $1.date })) { expense in
                        ExpenseRow(expense: expense) {
                            editingExpense = expense
                        } onDelete: {
                            deleteExpense(expense)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = trip.currency
        return formatter.string(from: amount as NSNumber) ?? "\(trip.currency) \(amount)"
    }

    private func progress(from total: Decimal, comparedTo max: Decimal) -> Double {
        guard max > 0 else { return 0 }
        return Double(truncating: (total / max) as NSNumber)
    }

    private func deleteExpense(_ expense: Expense) {
        trip.expenses.removeAll { $0.id == expense.id }
    }

    private func applyInitialIntentIfNeeded() {
        guard !didApplyInitialIntent else { return }
        didApplyInitialIntent = true

        if initialIntent == .addExpense {
            showAddExpense = true
        }
    }
}

// MARK: - Expense Row

private struct ExpenseRow: View {
    let expense: Expense
    let onEdit: () -> Void
    let onDelete: () -> Void

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: expense.category.icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.onSurfaceVariant)
                .frame(width: 28, height: 28)
                .background(AppTheme.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(Self.dateFormatter.string(from: expense.date))
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }

            Spacer()

            Text(formatAmount(expense.amount, currency: expense.currency))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .tripSoftSurface()
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatAmount(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: amount as NSNumber) ?? "\(currency) \(amount)"
    }
}

// MARK: - Budget Editor

struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var budget: Decimal?
    @Binding var currency: String

    @State private var budgetString: String = ""
    @FocusState private var amountFocused: Bool

    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN"]

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: "Set Budget",
                subtitle: "Define your spending target",
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    CreationSectionCard(title: "Budget", icon: "creditcard") {
                        VStack(spacing: AppTheme.Space.sm) {
                            TextField("Amount", text: $budgetString)
                                .keyboardType(.decimalPad)
                                .focused($amountFocused)
                                .designField(isFocused: amountFocused)

                            HStack {
                                Text("Currency")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                Picker("Currency", selection: $currency) {
                                    ForEach(currencies, id: \.self) { code in
                                        Text(code).tag(code)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.secondary)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: "Save Budget",
                gradient: AppTheme.tripGradient,
                canConfirm: !budgetString.isEmpty,
                isLoading: false,
                onCancel: { dismiss() },
                onConfirm: {
                    if let value = Decimal(string: budgetString) {
                        budget = value
                    }
                    dismiss()
                }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .presentationDetents([.medium])
        .onAppear {
            if let budget {
                budgetString = "\(budget)"
            }
        }
    }
}

// MARK: - Expense Form

struct ExpenseFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trip: Trip

    let expense: Expense?

    @State private var title: String = ""
    @State private var amountString: String = ""
    @State private var category: ExpenseCategory = .other
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case title, amount, notes }

    private var canSave: Bool { !title.isEmpty && !amountString.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            CreationTopBar(
                title: expense == nil ? "Add Expense" : "Edit Expense",
                subtitle: nil,
                onClose: { dismiss() }
            )

            ScrollView {
                VStack(spacing: AppTheme.Space.md) {
                    CreationSectionCard(title: "Expense", icon: "creditcard") {
                        VStack(spacing: AppTheme.Space.sm) {
                            TextField("Title", text: $title)
                                .focused($focusedField, equals: .title)
                                .designField(isFocused: focusedField == .title)

                            HStack(spacing: AppTheme.Space.sm) {
                                Text(trip.currency)
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurfaceVariant)
                                    .padding(.leading, 14)
                                TextField("Amount", text: $amountString)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .amount)
                            }
                            .padding(.vertical, 14)
                            .background(focusedField == .amount ? AppTheme.surfaceContainerLowest : AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                                    .stroke(focusedField == .amount ? AppTheme.primary.opacity(0.20) : .clear, lineWidth: 1)
                            )
                            .animation(.easeInOut(duration: 0.2), value: focusedField == .amount)
                        }
                    }

                    CreationSectionCard(title: "Details", icon: "slider.horizontal.3") {
                        VStack(spacing: AppTheme.Space.sm) {
                            HStack {
                                Text("Category")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                Picker("Category", selection: $category) {
                                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.secondary)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            HStack {
                                Text("Date")
                                    .font(AppTheme.TextStyle.body)
                                    .foregroundStyle(AppTheme.onSurface)
                                Spacer()
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AppTheme.secondary)
                            }
                            .padding(.horizontal, AppTheme.Space.md)
                            .padding(.vertical, AppTheme.Space.sm)
                            .background(AppTheme.surfaceContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    CreationSectionCard(title: "Notes", icon: "note.text") {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .focused($focusedField, equals: .notes)
                            .designField(isFocused: focusedField == .notes)
                    }
                }
                .padding(.horizontal, AppTheme.Space.lg)
                .padding(.bottom, AppTheme.Space.xxxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            CreationBottomActionBar(
                cancelTitle: "Cancel",
                confirmTitle: expense == nil ? "Add Expense" : "Save Expense",
                gradient: AppTheme.tripGradient,
                canConfirm: canSave,
                isLoading: false,
                onCancel: { dismiss() },
                onConfirm: { saveExpense(); dismiss() }
            )
        }
        .background(CreationScreenBackground(gradient: AppTheme.tripGradient))
        .onAppear {
            if let expense {
                title = expense.title
                amountString = "\(expense.amount)"
                category = expense.category
                date = expense.date
                notes = expense.notes
            }
        }
    }

    private func saveExpense() {
        guard let amount = Decimal(string: amountString) else { return }

        if let expense {
            if let index = trip.expenses.firstIndex(where: { $0.id == expense.id }) {
                trip.expenses[index].title = title
                trip.expenses[index].amount = amount
                trip.expenses[index].category = category
                trip.expenses[index].date = date
                trip.expenses[index].notes = notes
            }
        } else {
            let newExpense = Expense(
                title: title,
                amount: amount,
                currency: trip.currency,
                category: category,
                date: date,
                notes: notes
            )
            trip.expenses.append(newExpense)
        }
    }
}

#Preview {
    NavigationStack {
        TripBudgetView(trip: .constant(Trip(
            name: "Paris Trip",
            destination: "Paris, France",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7),
            budget: 3000,
            expenses: [
                Expense(title: "Hotel", amount: 800, category: .accommodation, date: Date()),
                Expense(title: "Flight", amount: 600, category: .transportation, date: Date()),
                Expense(title: "Dinner", amount: 75, category: .food, date: Date())
            ]
        )))
    }
}
