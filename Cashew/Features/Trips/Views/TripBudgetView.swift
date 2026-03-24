import SwiftUI

struct TripBudgetView: View {
    @Binding var trip: Trip
    @State private var showAddExpense = false
    @State private var editingExpense: Expense?
    @State private var showBudgetEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Budget Overview Card
                budgetOverviewCard

                // Expenses by Category
                if !trip.expenses.isEmpty {
                    expensesByCategoryCard
                }

                // Recent Expenses
                recentExpensesCard
            }
            .padding()
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
    }

    // MARK: - Budget Overview

    private var budgetOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.onSurfaceVariant)

                    if let budget = trip.budget {
                        Text(formatCurrency(budget))
                            .font(.title)
                            .fontWeight(.bold)
                    } else {
                        Text("Not set")
                            .font(.title2)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                    }
                }

                Spacer()

                Button {
                    showBudgetEditor = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }

            if let budget = trip.budget, budget > 0 {
                // Progress bar
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppTheme.surfaceContainerHigh)
                                .frame(height: 12)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(progressColor.gradient)
                                .frame(width: min(geometry.size.width * (trip.budgetProgress ?? 0), geometry.size.width), height: 12)
                        }
                    }
                    .frame(height: 12)

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Spent")
                                .font(.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Text(formatCurrency(trip.totalExpenses))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(AppTheme.onSurfaceVariant)
                            Text(formatCurrency(trip.remainingBudget ?? 0))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(trip.remainingBudget ?? 0 >= 0 ? .green : .red)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    private var progressColor: Color {
        guard let progress = trip.budgetProgress else { return .blue }
        if progress > 1.0 { return .red }
        if progress > 0.8 { return .orange }
        return .green
    }

    // MARK: - Expenses by Category

    private var expensesByCategoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(expensesByCategory, id: \.category) { item in
                    HStack {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(item.category.color.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(item.category.displayName)
                            .font(.subheadline)

                        Spacer()

                        Text(formatCurrency(item.total))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Expenses")
                    .font(.headline)

                Spacer()

                Text("\(trip.expenses.count) items")
                    .font(.caption)
                    .foregroundStyle(AppTheme.onSurfaceVariant)
            }
            .padding(.horizontal)

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
                VStack(spacing: 0) {
                    ForEach(trip.expenses.sorted(by: { $0.date > $1.date })) { expense in
                        ExpenseRow(expense: expense) {
                            editingExpense = expense
                        } onDelete: {
                            deleteExpense(expense)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius))
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = trip.currency
        return formatter.string(from: amount as NSNumber) ?? "\(trip.currency) \(amount)"
    }


    private func deleteExpense(_ expense: Expense) {
        trip.expenses.removeAll { $0.id == expense.id }
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
        .padding(.horizontal)
        .padding(.vertical, 8)
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

    private let currencies = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "MXN"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget Amount") {
                    TextField("Amount", text: $budgetString)
                        .keyboardType(.decimalPad)
                }

                Section("Currency") {
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Set Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let value = Decimal(string: budgetString) {
                            budget = value
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let budget {
                    budgetString = "\(budget)"
                }
            }
        }
        .presentationDetents([.medium])
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)

                    HStack {
                        Text(trip.currency)
                            .foregroundStyle(AppTheme.onSurfaceVariant)
                        TextField("Amount", text: $amountString)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(expense == nil ? "Add Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                        dismiss()
                    }
                    .disabled(title.isEmpty || amountString.isEmpty)
                }
            }
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
    }

    private func saveExpense() {
        guard let amount = Decimal(string: amountString) else { return }

        if let expense {
            // Update existing
            if let index = trip.expenses.firstIndex(where: { $0.id == expense.id }) {
                trip.expenses[index].title = title
                trip.expenses[index].amount = amount
                trip.expenses[index].category = category
                trip.expenses[index].date = date
                trip.expenses[index].notes = notes
            }
        } else {
            // Create new
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
