import Foundation

/// Orden de la lista "Mis eventos". Los valores coinciden con los de la web.
nonisolated enum SortMode: String, CaseIterable, Identifiable, Sendable {
    case dateAsc = "date-asc"
    case dateDesc = "date-desc"
    case name
    case created

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAsc: "Próximos primero"
        case .dateDesc: "Lejanos primero"
        case .name: "Nombre A-Z"
        case .created: "Recién creados"
        }
    }
}

/// Ordenar y filtrar eventos (portado de `sortEvents` y `filterEvents` de `js/ui.js`).
nonisolated enum EventList {

    static func sorted(
        _ events: [Event], by mode: SortMode, now: Date = Date(), calendar: Calendar = .current
    ) -> [Event] {
        switch mode {
        case .dateAsc, .dateDesc:
            let keyed = events.map { (event: $0, remaining: Countdown.remaining($0, now: now, calendar: calendar)) }
            let ordered = mode == .dateAsc
                ? keyed.sorted { $0.remaining < $1.remaining }
                : keyed.sorted { $0.remaining > $1.remaining }
            return ordered.map(\.event)
        case .name:
            return events.sorted {
                $0.name.compare(
                    $1.name, options: [.caseInsensitive, .diacriticInsensitive], locale: Countdown.spanish
                ) == .orderedAscending
            }
        case .created:
            return events.sorted { creationStamp($0.id) > creationStamp($1.id) }
        }
    }

    /// Filtra por categoría (`nil` = todas) y por texto en el nombre,
    /// sin distinguir mayúsculas ni acentos.
    static func filtered(_ events: [Event], category: String? = nil, query: String = "") -> [Event] {
        var result = events
        if let category {
            result = result.filter { $0.category == category }
        }
        let needle = normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        if !needle.isEmpty {
            result = result.filter { normalize($0.name).contains(needle) }
        }
        return result
    }

    /// Categorías que tienen al menos un evento, en el orden del catálogo.
    static func categoriesInUse(_ events: [Event]) -> [EventCategory] {
        let used = Set(events.map { Catalog.category(id: $0.category).id })
        return Catalog.categories.filter { used.contains($0.id) }
    }

    /// Momento de creación sacado del id (`evt_<tiempo en base 36>_<azar>`); 0 si no lo tiene.
    static func creationStamp(_ id: String) -> Int {
        let parts = id.split(separator: "_", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return 0 }
        return Int(parts[1], radix: 36) ?? 0
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Countdown.spanish)
    }
}
