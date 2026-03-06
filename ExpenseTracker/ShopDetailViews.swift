import SwiftUI
import SwiftData

struct ShopDetailView: View, Identifiable {
    @Environment(\.modelContext) private var modelContext

    let id = UUID()
    @Bindable var shop: Shop

    @State private var isPresentingAddExpense = false

    private var currentMonthTotal: Decimal {
        shop.monthlyTotal(for: Date())
    }

    private var expensesByMonth: [(month: DateComponents, expenses: [Expense], total: Decimal)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: shop.expenses) { expense in
            calendar.dateComponents([.year, .month], from: expense.date)
        }

        return grouped
            .map { components, expenses in
                let total = expenses.reduce(0) { partial, expense in
                    partial + expense.amount
                }
                return (month: components, expenses: expenses.sorted { $0.date > $1.date }, total: total)
            }
            .sorted { lhs, rhs in
                guard
                    let lDate = Calendar.current.date(from: lhs.month),
                    let rDate = Calendar.current.date(from: rhs.month)
                else {
                    return false
                }
                return lDate > rDate
            }
    }

    var body: some View {
        List {
            if currentMonthTotal > 0 {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This Month")
                            .font(.headline)
                        Text(NumberFormatter.currency.string(from: currentMonthTotal as NSDecimalNumber) ?? "")
                            .font(.title2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(expensesByMonth, id: \.month) { group in
                Section(header: sectionHeader(for: group.month, total: group.total)) {
                    ForEach(group.expenses) { expense in
                        ExpenseRow(expense: expense)
                    }
                    .onDelete { indexSet in
                        deleteExpenses(at: indexSet, in: group.expenses)
                    }
                }
            }
        }
        .navigationTitle(shop.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPresentingAddExpense = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add expense")
            }
        }
        .sheet(isPresented: $isPresentingAddExpense) {
            AddExpenseSheet(shop: shop)
        }
    }

    private func sectionHeader(for components: DateComponents, total: Decimal) -> some View {
        let calendar = Calendar.current
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"

        return HStack {
            Text(formatter.string(from: date))
            Spacer()
            Text(NumberFormatter.currency.string(from: total as NSDecimalNumber) ?? "")
                .font(.subheadline.weight(.semibold))
        }
    }

    private func deleteExpenses(at offsets: IndexSet, in expenses: [Expense]) {
        for index in offsets {
            let expense = expenses[index]
            modelContext.delete(expense)
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expense.date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.note?.isEmpty == false ? expense.note! : "Expense")
                    .font(.body)
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(NumberFormatter.currency.string(from: expense.amount as NSDecimalNumber) ?? "")
                .font(.body.weight(.semibold))
        }
        .contentShape(Rectangle())
    }
}

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var shop: Shop

    @State private var amountText: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var isSaveEnabled: Bool {
        guard let amount, amount > 0 else { return false }
        return date <= Date()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section("Date") {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }

                Section("Note") {
                    TextField("Optional note...", text: $note)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .navigationTitle("Add Expense")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isSaveEnabled)
                }
            }
        }
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        guard date <= Date() else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(
            amount: amount,
            date: date,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            shop: shop
        )

        modelContext.insert(expense)
        dismiss()
    }
}

