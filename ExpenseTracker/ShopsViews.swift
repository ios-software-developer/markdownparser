import SwiftUI
import SwiftData

struct ShopsGridView: View {
    let shops: [Shop]
    let onTapShop: (Shop) -> Void
    let onEditShop: (Shop) -> Void
    let onDeleteShop: (Shop) -> Void

    private let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(shops) { shop in
                    ShopCellView(
                        shop: shop,
                        monthlyTotal: shop.monthlyTotal(for: Date())
                    )
                    .contextMenu {
                        Button("Edit Shop") {
                            onEditShop(shop)
                        }

                        Button("Delete Shop", role: .destructive) {
                            onDeleteShop(shop)
                        }
                    }
                    .onTapGesture {
                        onTapShop(shop)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
    }
}

struct ShopCellView: View {
    let shop: Shop
    let monthlyTotal: Decimal

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(shop.iconBackgroundColor)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: shop.iconSymbolName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }

                if monthlyTotal > 0 {
                    Text(NumberFormatter.currency.string(from: monthlyTotal as NSDecimalNumber) ?? "")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.red)
                        )
                        .foregroundStyle(Color.white)
                        .padding(4)
                }
            }

            Text(shop.name)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShopsEmptyStateView: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No shops yet")
                    .font(.title3.weight(.semibold))

                Text("Tap Add Shop to create your first shop and start tracking spending.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Button(action: addAction) {
                Text("Add Shop")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityLabel("No shops added yet")
    }
}

struct AddOrEditShopSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let shopToEdit: Shop?

    @State private var name: String = ""
    @State private var selectedIcon: String = "storefront.fill"
    @State private var selectedColorHex: String = ShopColorPalette.defaultColors.first?.hex ?? "E63946"

    private var isEditing: Bool {
        shopToEdit != nil
    }

    private var isSaveEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shop") {
                    TextField("e.g. Whole Foods", text: $name)
                        .onChange(of: name) { _ in
                            if shopToEdit == nil {
                                updateSuggestedIcon()
                            }
                        }

                    HStack {
                        ShopIconPreview(symbolName: selectedIcon, colorHex: selectedColorHex)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(IconSuggestionEngine.suggestIcons(for: name), id: \.self) { symbol in
                                    Button {
                                        selectedIcon = symbol
                                    } label: {
                                        Image(systemName: symbol)
                                            .frame(width: 32, height: 32)
                                            .background(
                                                Circle()
                                                    .stroke(selectedIcon == symbol ? Color.accentColor : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Icon Background Colour") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ShopColorPalette.defaultColors) { color in
                                Button {
                                    selectedColorHex = color.hex
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if selectedColorHex == color.hex {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Shop" : "Add Shop")
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
                if let shopToEdit {
                    name = shopToEdit.name
                    selectedIcon = shopToEdit.iconSymbolName
                    selectedColorHex = shopToEdit.iconBackgroundColorHex
                }
            }
        }
    }

    private func updateSuggestedIcon() {
        if let first = IconSuggestionEngine.suggestIcons(for: name).first {
            selectedIcon = first
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if let shopToEdit {
            shopToEdit.name = trimmedName
            shopToEdit.iconSymbolName = selectedIcon
            shopToEdit.iconBackgroundColorHex = selectedColorHex
        } else {
            let shop = Shop(
                name: trimmedName,
                iconSymbolName: selectedIcon,
                iconBackgroundColorHex: selectedColorHex
            )
            modelContext.insert(shop)
        }

        dismiss()
    }
}

struct ShopIconPreview: View {
    let symbolName: String
    let colorHex: String

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(hex: colorHex))
            .frame(width: 72, height: 72)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
    }
}

struct ShopColorPaletteColor: Identifiable {
    let id = UUID()
    let hex: String

    var color: Color {
        Color(hex: hex)
    }
}

enum ShopColorPalette {
    static let defaultColors: [ShopColorPaletteColor] = [
        .init(hex: "E63946"),
        .init(hex: "F4831F"),
        .init(hex: "F9C22E"),
        .init(hex: "2DC653"),
        .init(hex: "1B7FD4"),
        .init(hex: "7B2FBE"),
        .init(hex: "E91E8C"),
        .init(hex: "00BCD4"),
        .init(hex: "795548"),
        .init(hex: "607D8B"),
        .init(hex: "212121"),
    ]
}

extension Shop {
    func monthlyTotal(for date: Date) -> Decimal {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else {
            return 0
        }

        let monthExpenses = expenses.filter { expense in
            let comps = calendar.dateComponents([.year, .month], from: expense.date)
            return comps.year == year && comps.month == month
        }

        return monthExpenses.reduce(0) { partial, expense in
            partial + expense.amount
        }
    }

    var iconBackgroundColor: Color {
        Color(hex: iconBackgroundColorHex)
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            r = 0
            g = 0
            b = 0
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()
}

enum IconSuggestionEngine {
    private static let keywordMap: [String: [String]] = [
        "grocery": ["cart.fill", "basket.fill", "storefront.fill", "leaf.fill", "apple.logo"],
        "market": ["cart.fill", "basket.fill", "storefront.fill", "leaf.fill", "apple.logo"],
        "food": ["cart.fill", "basket.fill", "storefront.fill", "leaf.fill", "apple.logo"],
        "whole": ["cart.fill", "basket.fill", "storefront.fill", "leaf.fill", "apple.logo"],
        "fresh": ["cart.fill", "basket.fill", "storefront.fill", "leaf.fill", "apple.logo"],
        "farm": ["cart.fill", "basket.fill", "storefront.fill", "leaf.fill", "apple.logo"],
        "coffee": ["cup.and.saucer.fill", "mug.fill", "flame.fill"],
        "cafe": ["cup.and.saucer.fill", "mug.fill", "flame.fill"],
        "brew": ["cup.and.saucer.fill", "mug.fill", "flame.fill"],
        "starbucks": ["cup.and.saucer.fill", "mug.fill", "flame.fill"],
        "bean": ["cup.and.saucer.fill", "mug.fill", "flame.fill"],
        "pharmacy": ["cross.case.fill", "pills.fill", "heart.fill"],
        "drug": ["cross.case.fill", "pills.fill", "heart.fill"],
        "health": ["cross.case.fill", "pills.fill", "heart.fill"],
        "medical": ["cross.case.fill", "pills.fill", "heart.fill"],
        "chemist": ["cross.case.fill", "pills.fill", "heart.fill"],
        "petrol": ["fuelpump.fill", "car.fill"],
        "gas": ["fuelpump.fill", "car.fill"],
        "fuel": ["fuelpump.fill", "car.fill"],
        "shell": ["fuelpump.fill", "car.fill"],
        "bp": ["fuelpump.fill", "car.fill"],
        "esso": ["fuelpump.fill", "car.fill"],
        "restaurant": ["fork.knife", "takeoutbag.and.cup.and.straw.fill"],
        "diner": ["fork.knife", "takeoutbag.and.cup.and.straw.fill"],
        "eat": ["fork.knife", "takeoutbag.and.cup.and.straw.fill"],
        "kitchen": ["fork.knife", "takeoutbag.and.cup.and.straw.fill"],
        "pizza": ["fork.knife", "takeoutbag.and.cup.and.straw.fill"],
        "burger": ["fork.knife", "takeoutbag.and.cup.and.straw.fill"],
        "book": ["books.vertical.fill", "pencil.and.book.fill"],
        "library": ["books.vertical.fill", "pencil.and.book.fill"],
        "school": ["books.vertical.fill", "pencil.and.book.fill"],
        "stationery": ["books.vertical.fill", "pencil.and.book.fill"],
        "clothes": ["tshirt.fill", "bag.fill"],
        "fashion": ["tshirt.fill", "bag.fill"],
        "apparel": ["tshirt.fill", "bag.fill"],
        "wear": ["tshirt.fill", "bag.fill"],
        "boutique": ["tshirt.fill", "bag.fill"],
        "gym": ["figure.run", "heart.circle.fill", "dumbbell.fill"],
        "fitness": ["figure.run", "heart.circle.fill", "dumbbell.fill"],
        "sport": ["figure.run", "heart.circle.fill", "dumbbell.fill"],
        "yoga": ["figure.run", "heart.circle.fill", "dumbbell.fill"],
        "wellness": ["figure.run", "heart.circle.fill", "dumbbell.fill"],
        "tech": ["laptopcomputer", "iphone", "tv.fill"],
        "electronics": ["laptopcomputer", "iphone", "tv.fill"],
        "computer": ["laptopcomputer", "iphone", "tv.fill"],
        "phone": ["laptopcomputer", "iphone", "tv.fill"],
        "apple": ["laptopcomputer", "iphone", "tv.fill"],
    ]

    private static let fallbackIcons: [String] = [
        "storefront.fill",
        "bag.fill",
        "creditcard.fill",
    ]

    static func suggestIcons(for name: String) -> [String] {
        let lowercased = name.lowercased()
        let tokens = lowercased.split(separator: " ").map(String.init)

        var suggestions: [String] = []

        for token in tokens {
            for (keyword, symbols) in keywordMap {
                if token.contains(keyword) || keyword.contains(token) {
                    for symbol in symbols where !suggestions.contains(symbol) {
                        suggestions.append(symbol)
                    }
                }
            }
        }

        for symbol in fallbackIcons where !suggestions.contains(symbol) {
            suggestions.append(symbol)
        }

        return Array(suggestions.prefix(8))
    }
}

