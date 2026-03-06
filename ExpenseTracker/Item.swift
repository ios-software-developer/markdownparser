//
//  Item.swift
//  ExpenseTracker
//
//  Created by SoftDev on 06.03.2026.
//

import Foundation
import SwiftData

@Model
final class Shop {
    var id: UUID
    var name: String
    var iconSymbolName: String
    var iconBackgroundColorHex: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Expense.shop)
    var expenses: [Expense]

    init(
        id: UUID = UUID(),
        name: String,
        iconSymbolName: String,
        iconBackgroundColorHex: String,
        createdAt: Date = .now,
        expenses: [Expense] = []
    ) {
        self.id = id
        self.name = name
        self.iconSymbolName = iconSymbolName
        self.iconBackgroundColorHex = iconBackgroundColorHex
        self.createdAt = createdAt
        self.expenses = expenses
    }
}

@Model
final class Expense {
    var id: UUID
    var amount: Decimal
    var date: Date
    var note: String?
    @Relationship(inverse: \Shop.expenses)
    var shop: Shop?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date,
        note: String? = nil,
        shop: Shop? = nil
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.shop = shop
    }
}

@Model
final class MonthlyBudget {
    var id: UUID
    var year: Int
    var month: Int
    var allocatedAmount: Decimal

    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        allocatedAmount: Decimal
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.allocatedAmount = allocatedAmount
    }
}
