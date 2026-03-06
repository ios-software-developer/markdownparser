import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            ShopsRootView()
                .tabItem {
                    Label("Shops", systemImage: "storefront.fill")
                }

            AnalyticsRootView()
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar.fill")
                }
        }
    }
}

struct ShopsRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shop.createdAt) private var shops: [Shop]

    @State private var isPresentingAddShop = false
    @State private var editingShop: Shop?

    private var hasShops: Bool {
        !shops.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasShops {
                    ShopsGridView(
                        shops: shops,
                        onTapShop: { shop in
                            editingShop = nil
                        },
                        onEditShop: { shop in
                            editingShop = shop
                            isPresentingAddShop = true
                        },
                        onDeleteShop: deleteShop
                    )
                } else {
                    ShopsEmptyStateView(addAction: { isPresentingAddShop = true })
                }
            }
            .navigationTitle("Shops")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingShop = nil
                        isPresentingAddShop = true
                    } label {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new shop")
                }
            }
            .sheet(isPresented: $isPresentingAddShop) {
                AddOrEditShopSheet(shopToEdit: editingShop)
                    .environment(\.modelContext, modelContext)
            }
        }
    }

    private func deleteShop(_ shop: Shop) {
        modelContext.delete(shop)
    }
}

struct AnalyticsRootView: View {
    var body: some View {
        NavigationStack {
            Text("Analytics coming soon")
                .navigationTitle("Analytics")
        }
    }
}

