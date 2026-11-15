import Foundation

/// Categoría de un evento. El `id` se guarda en los eventos y no debe cambiar.
nonisolated struct EventCategory: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let emoji: String
}

/// Opciones fijas de la app: categorías, emojis y colores (igual que `js/ui.js`).
nonisolated enum Catalog {
    static let categories: [EventCategory] = [
        EventCategory(id: "birthday", label: "Cumpleaños", emoji: "🎂"),
        EventCategory(id: "health", label: "Salud", emoji: "🩺"),
        EventCategory(id: "party", label: "Fiestas", emoji: "🎉"),
        EventCategory(id: "fair", label: "Ferias", emoji: "🎪"),
        EventCategory(id: "festival", label: "Festivales", emoji: "🎶"),
        EventCategory(id: "travel", label: "Viajes", emoji: "✈️"),
        EventCategory(id: "other", label: "Otros", emoji: "⏳"),
    ]

    static let defaultCategoryId = "other"

    static let emojis: [String] = [
        "⏳", "🎂", "✈️", "🎓", "🎬", "💒", "🏠", "🍾",
        "💼", "🎮", "🎉", "❤️", "🌴", "🎄", "🐣", "🎁",
    ]

    static let defaultEmoji = "⏳"

    static let colors: [String] = [
        "#6c5ce7", "#e17055", "#00b894", "#0984e3",
        "#fdcb6e", "#e84393", "#2d3436", "#00cec9",
    ]

    static let defaultColor = "#6c5ce7"

    /// Devuelve la categoría por id; si no existe, "Otros".
    static func category(id: String) -> EventCategory {
        categories.first { $0.id == id } ?? categories.first { $0.id == defaultCategoryId }!
    }
}
