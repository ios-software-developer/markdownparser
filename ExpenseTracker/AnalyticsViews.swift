import SwiftUI
import SwiftData
import Charts

struct AnalyticsRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]
    @Query private var budgets: [MonthlyBudget]
    @Query private var shops: [Shop]

    @State private var selectedMonth: MonthYear = MonthYear.current
    @State private var isPresentingMonthPicker = false
    @State private var isPresentingBudgetSheet = false

    private var monthExpenses: [Expense] {
        expenses.filter { $0.date.isIn(month: selectedMonth) }
    }

    private var totalSpent: Decimal {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var budget: MonthlyBudget? {
        budgets.first { $0.year == selectedMonth.year && $0.month == selectedMonth.month }
    }

    private var allocatedAmount: Decimal? {
        budget?.allocatedAmount
    }

    private var remainingAmountText: (text: String, isOver: Bool)? {
        guard let allocatedAmount else { return nil }
        let remaining = allocatedAmount - totalSpent
        let formatter = NumberFormatter.currency
        if remaining >= 0 {
            return ("\(formatter.string(from: remaining as NSDecimalNumber) ?? "") remaining", false)
        } else {
            let over = -remaining
            return ("\(formatter.string(from: over as NSDecimalNumber) ?? "") over budget", true)
        }
    }

    private var utilisationFraction: Double? {
        guard let allocatedAmount, allocatedAmount > 0 else { return nil }
        let fraction = (totalSpent as NSDecimalNumber).doubleValue / (allocatedAmount as NSDecimalNumber).doubleValue
        return max(0, fraction)
    }

    private var perShopTotals: [(shop: Shop, total: Decimal)] {
        shops.map { shop in
            let total = monthExpenses
                .filter { $0.shop == shop }
                .reduce(0) { $0 + $1.amount }
            return (shop, total)
        }
        .filter { $0.total > 0 }
        .sorted { $0.total > $1.total }
    }

    private var burnRatePoints: [BurnRatePoint] {
        BurnRateCalculator.points(for: monthExpenses, month: selectedMonth)
    }

    private var isCurrentMonth: Bool {
        selectedMonth == .current
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summaryCard
                    utilisationView
                    perShopBreakdown
                    burnRateChart
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingMonthPicker = true
                    } label: {
                        Text(selectedMonth.formatted)
                    }
                }
            }
            .sheet(isPresented: $isPresentingMonthPicker) {
                MonthPickerSheet(
                    allExpenses: expenses,
                    selectedMonth: $selectedMonth
                )
            }
            .sheet(isPresented: $isPresentingBudgetSheet) {
                BudgetSheet(
                    month: selectedMonth,
                    existingBudget: budget,
                    onSave: upsertBudget
                )
                .environment(\.modelContext, modelContext)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(NumberFormatter.currency.string(from: totalSpent as NSDecimalNumber) ?? "")
                .font(.largeTitle.weight(.bold))

            if let allocatedAmount {
                Text("of \(NumberFormatter.currency.string(from: allocatedAmount as NSDecimalNumber) ?? "") budget")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    isPresentingBudgetSheet = true
                } label: {
                    Text("No budget set — tap to add")
                        .font(.subheadline)
                }
            }

            if let remaining = remainingAmountText {
                Text(remaining.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(remaining.isOver ? Color.red : Color.green)
            }

            if allocatedAmount == nil {
                Button {
                    isPresentingBudgetSheet = true
                } label: {
                    Text("Set Budget")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var utilisationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fund utilisation")
                .font(.headline)

            if let fraction = utilisationFraction {
                ProgressView(value: min(fraction, 1.0))
                    .tint(utilisationColor(for: fraction))

                let percentage = Int(min(fraction, 1.0) * 100)
                Text("\(percentage)% of budget spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Set a monthly budget to track utilisation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func utilisationColor(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.7:
            return .green
        case 0.7..<0.9:
            return .orange
        default:
            return .red
        }
    }

    private var perShopBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per-shop spending")
                .font(.headline)

            if perShopTotals.isEmpty {
                Text("No spending in this month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(perShopTotals, id: \.shop.id) { item in
                    BarMark(
                        x: .value("Amount", (item.total as NSDecimalNumber).doubleValue),
                        y: .value("Shop", item.shop.name)
                    )
                    .foregroundStyle(item.shop.iconBackgroundColor)
                }
                .frame(height: max(200, CGFloat(perShopTotals.count) * 24))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var burnRateChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Burn-rate projection")
                .font(.headline)

            guard isCurrentMonth, let allocatedAmount else {
                Text("Set a budget for the current month to see a burn-rate projection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                return AnyView(EmptyView())
            }

            if burnRatePoints.isEmpty {
                return AnyView(
                    Text("Log expenses to see your spending projection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                )
            }

            let budgetValue = (allocatedAmount as NSDecimalNumber).doubleValue
            let projection = BurnRateCalculator.projection(for: burnRatePoints, budget: budgetValue)

            return AnyView(
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        ForEach(burnRatePoints) { point in
                            LineMark(
                                x: .value("Day", point.day),
                                y: .value("Cumulative Spend", point.cumulative)
                            )
                            .foregroundStyle(Color.accentColor)
                        }

                        if let projected = projection {
                            ForEach(projected.projectedPoints) { point in
                                LineMark(
                                    x: .value("Day", point.day),
                                    y: .value("Projected", point.cumulative)
                                )
                                .foregroundStyle(Color.orange)
                                .interpolationMethod(.linear)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }

                            RuleMark(y: .value("Budget", budgetValue))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                                .foregroundStyle(Color.red)

                            if let exhaustionDay = projected.exhaustionDay {
                                PointMark(
                                    x: .value("Day", exhaustionDay),
                                    y: .value("Budget", budgetValue)
                                )
                                .annotation(position: .topLeading) {
                                    Text("Est. budget exhausted: \(selectedMonth.label(forDay: exhaustionDay))")
                                        .font(.caption2)
                                        .padding(4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color(.systemBackground))
                                        )
                                }
                            }
                        }
                    }
                    .frame(height: 220)

                    if let projected = projection, projected.exhaustionDay == nil {
                        Text("Budget sufficient for full month.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func upsertBudget(amount: Decimal) {
        if let budget {
            budget.allocatedAmount = amount
        } else {
            let newBudget = MonthlyBudget(
                year: selectedMonth.year,
                month: selectedMonth.month,
                allocatedAmount: amount
            )
            modelContext.insert(newBudget)
        }
    }
}

struct MonthYear: Equatable {
    let year: Int
    let month: Int

    static var current: MonthYear {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return MonthYear(year: comps.year ?? 2000, month: comps.month ?? 1)
    }

    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return formatter.string(from: date)
    }

    func label(forDay day: Int) -> String {
        let comps = DateComponents(year: year, month: month, day: day)
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MonthPickerSheet: View {
    let allExpenses: [Expense]
    @Binding var selectedMonth: MonthYear

    private var availableMonths: [MonthYear] {
        let calendar = Calendar.current
        let componentsSet = Set(
            allExpenses.map { expense in
                calendar.dateComponents([.year, .month], from: expense.date)
            }
        )

        return componentsSet.compactMap { comps in
            guard let year = comps.year, let month = comps.month else { return nil }
            return MonthYear(year: year, month: month)
        }
        .sorted { lhs, rhs in
            if lhs.year == rhs.year {
                return lhs.month > rhs.month
            }
            return lhs.year > rhs.year
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableMonths, id: \.self) { month in
                    Button {
                        selectedMonth = month
                    } label: {
                        HStack {
                            Text(month.formatted)
                            Spacer()
                            if month == selectedMonth {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Month")
        }
    }
}

struct BudgetSheet: View {
    @Environment(\.dismiss) private var dismiss

    let month: MonthYear
    let existingBudget: MonthlyBudget?
    let onSave: (Decimal) -> Void

    @State private var amountText: String = ""

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var isSaveEnabled: Bool {
        guard let amount, amount > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Budget for \(month.formatted)") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Set Budget")
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
            .onAppear {
                if let existingBudget {
                    amountText = (existingBudget.allocatedAmount as NSDecimalNumber).stringValue
                }
            }
        }
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        onSave(amount)
        dismiss()
    }
}

struct BurnRatePoint: Identifiable {
    let id = UUID()
    let day: Int
    let cumulative: Double
}

struct BurnRateProjection {
    let projectedPoints: [BurnRatePoint]
    let exhaustionDay: Int?
}

enum BurnRateCalculator {
    static func points(for expenses: [Expense], month: MonthYear) -> [BurnRatePoint] {
        let calendar = Calendar.current
        let daysRange = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: month.year, month: month.month)) ?? Date()) ?? 1...30

        var dailyTotals: [Int: Decimal] = [:]
        for expense in expenses {
            let comps = calendar.dateComponents([.year, .month, .day], from: expense.date)
            guard comps.year == month.year, comps.month == month.month, let day = comps.day else {
                continue
            }
            dailyTotals[day, default: 0] += expense.amount
        }

        var cumulative: Decimal = 0
        var points: [BurnRatePoint] = []
        for day in daysRange {
            cumulative += dailyTotals[day] ?? 0
            points.append(
                BurnRatePoint(
                    day: day,
                    cumulative: (cumulative as NSDecimalNumber).doubleValue
                )
            )
        }

        return points
    }

    static func projection(for points: [BurnRatePoint], budget: Double) -> BurnRateProjection? {
        guard !points.isEmpty else { return nil }

        let lastIndex = max(points.count - 7, 0)
        let recent = Array(points[lastIndex...])

        let n = Double(recent.count)
        let sumX = recent.reduce(0) { $0 + Double($1.day) }
        let sumY = recent.reduce(0) { $0 + $1.cumulative }
        let sumXY = recent.reduce(0) { $0 + Double($1.day) * $1.cumulative }
        let sumX2 = recent.reduce(0) { $0 + Double($1.day * $1.day) }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }

        let m = (n * sumXY - sumX * sumY) / denominator
        let b = (sumY - m * sumX) / n

        guard m > 0 else { return nil }

        let lastDay = points.last?.day ?? 30
        let exhaustionX = (budget - b) / m
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? lastDay

        var projectedPoints: [BurnRatePoint] = []
        for day in lastDay...daysInMonth {
            let y = m * Double(day) + b
            projectedPoints.append(BurnRatePoint(day: day, cumulative: y))
        }

        let exhaustionDay: Int?
        if exhaustionX.isFinite, exhaustionX >= Double(lastDay), exhaustionX <= Double(daysInMonth) {
            exhaustionDay = Int(exhaustionX.rounded())
        } else {
            exhaustionDay = nil
        }

        return BurnRateProjection(projectedPoints: projectedPoints, exhaustionDay: exhaustionDay)
    }
}

extension Date {
    func isIn(month: MonthYear) -> Bool {
        let comps = Calendar.current.dateComponents([.year, .month], from: self)
        return comps.year == month.year && comps.month == month.month
    }
}

