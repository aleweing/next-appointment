import Foundation

/// Unidad de repetición de un evento. Los valores coinciden con los de la web.
nonisolated enum RecurrenceUnit: String, Codable, CaseIterable, Sendable {
    case none, day, week, month, year
}

/// Recurrencia normalizada de un evento (equivale a `getRecurrence` de `js/countdown.js`).
nonisolated struct Recurrence: Equatable, Sendable {
    var unit: RecurrenceUnit
    var interval: Int
    /// Último día de la serie, incluido, en formato `YYYY-MM-DD`. `nil` = sin fecha de fin.
    var endDate: String?
    /// Número total de ocurrencias contando la primera. `nil` = sin máximo.
    var maxCount: Int?
}

/// Un evento con cuenta atrás. Mismo modelo que la web (`localStorage`):
/// `date` y `time` se guardan como texto y significan "esa hora, donde esté el usuario".
nonisolated struct Event: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    /// `YYYY-MM-DD`, en hora local del dispositivo.
    var date: String
    /// `HH:MM`; `00:00` si no se indica hora.
    var time: String
    var emoji: String
    var color: String
    var category: String
    var recurrenceUnit: RecurrenceUnit
    var recurrenceInterval: Int
    var recurrenceEndDate: String?
    var recurrenceMaxCount: Int?
    /// Segundos de antelación del aviso, o `nil` si no hay aviso.
    var notifyBefore: Int?
    /// Marca de archivado en milisegundos (como en la web), o `nil`.
    var archivedAt: Double?
    /// Si ya se mostró la celebración de este evento (`_celebrated` en la web).
    var celebrated: Bool

    static let maxNameLength = 40

    init(
        id: String = Event.generateId(),
        name: String,
        date: String,
        time: String = "00:00",
        emoji: String = Catalog.defaultEmoji,
        color: String = Catalog.defaultColor,
        category: String = Catalog.defaultCategoryId,
        recurrenceUnit: RecurrenceUnit = .none,
        recurrenceInterval: Int = 1,
        recurrenceEndDate: String? = nil,
        recurrenceMaxCount: Int? = nil,
        notifyBefore: Int? = nil,
        archivedAt: Double? = nil,
        celebrated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.time = time
        self.emoji = emoji
        self.color = color
        self.category = category
        self.recurrenceUnit = recurrenceUnit
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceEndDate = recurrenceEndDate
        self.recurrenceMaxCount = recurrenceMaxCount
        self.notifyBefore = notifyBefore
        self.archivedAt = archivedAt
        self.celebrated = celebrated
    }

    /// Recurrencia normalizada: intervalo mínimo 1 y límites vacíos como `nil`.
    var recurrence: Recurrence {
        let endDate = (recurrenceEndDate?.isEmpty ?? true) ? nil : recurrenceEndDate
        let maxCount = recurrenceMaxCount.flatMap { $0 > 0 ? $0 : nil }
        return Recurrence(
            unit: recurrenceUnit,
            interval: max(1, recurrenceInterval),
            endDate: endDate,
            maxCount: maxCount
        )
    }

    /// Mismo formato de id que la web: `evt_<tiempo en base 36>_<6 caracteres al azar>`.
    static func generateId() -> String {
        let millis = Int(Date().timeIntervalSince1970 * 1000)
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        let random = String((0..<6).map { _ in alphabet.randomElement()! })
        return "evt_" + String(millis, radix: 36) + "_" + random
    }

    // MARK: - Codable (compatible con el JSON de la web)

    private enum CodingKeys: String, CodingKey {
        case id, name, date, time, emoji, color, category
        case recurrenceUnit, recurrenceInterval, recurrenceEndDate, recurrenceMaxCount
        case notifyBefore, archivedAt
        case celebrated = "_celebrated"
        // Formatos antiguos de la web, solo para leer.
        case recurrence, recurring
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decodeIfPresent(String.self, forKey: .id) ?? Event.generateId()
        name = String((try c.decodeIfPresent(String.self, forKey: .name) ?? "").prefix(Event.maxNameLength))
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        let rawTime = try c.decodeIfPresent(String.self, forKey: .time) ?? ""
        time = rawTime.isEmpty ? "00:00" : rawTime
        emoji = Event.nonEmpty(try c.decodeIfPresent(String.self, forKey: .emoji)) ?? Catalog.defaultEmoji
        color = Event.nonEmpty(try c.decodeIfPresent(String.self, forKey: .color)) ?? Catalog.defaultColor
        category = Event.nonEmpty(try c.decodeIfPresent(String.self, forKey: .category)) ?? Catalog.defaultCategoryId

        // Recurrencia, con los dos formatos anteriores de la web (ver `getRecurrence`).
        if let unitText = Event.nonEmpty(try? c.decodeIfPresent(String.self, forKey: .recurrenceUnit)) {
            recurrenceUnit = RecurrenceUnit(rawValue: unitText) ?? .none
            recurrenceInterval = max(1, Event.lenientInt(c, .recurrenceInterval) ?? 1)
        } else if let legacy = Event.nonEmpty(try? c.decodeIfPresent(String.self, forKey: .recurrence)) {
            let legacyMap: [String: RecurrenceUnit] = [
                "daily": .day, "weekly": .week, "monthly": .month, "yearly": .year, "none": .none,
            ]
            recurrenceUnit = legacyMap[legacy] ?? .none
            recurrenceInterval = 1
        } else {
            let recurring = (try? c.decodeIfPresent(Bool.self, forKey: .recurring)) ?? false
            recurrenceUnit = recurring ? .year : .none
            recurrenceInterval = 1
        }

        recurrenceEndDate = Event.nonEmpty(try? c.decodeIfPresent(String.self, forKey: .recurrenceEndDate))
        recurrenceMaxCount = Event.lenientInt(c, .recurrenceMaxCount).flatMap { $0 > 0 ? $0 : nil }
        notifyBefore = Event.lenientInt(c, .notifyBefore).flatMap { $0 > 0 ? $0 : nil }
        archivedAt = (try? c.decodeIfPresent(Double.self, forKey: .archivedAt)) ?? nil
        celebrated = (try? c.decodeIfPresent(Bool.self, forKey: .celebrated)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(date, forKey: .date)
        try c.encode(time, forKey: .time)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(color, forKey: .color)
        try c.encode(category, forKey: .category)
        try c.encode(recurrenceUnit, forKey: .recurrenceUnit)
        try c.encode(recurrenceInterval, forKey: .recurrenceInterval)
        // Los opcionales se escriben como `null`, igual que en el archivo de la web.
        try c.encode(recurrenceEndDate, forKey: .recurrenceEndDate)
        try c.encode(recurrenceMaxCount, forKey: .recurrenceMaxCount)
        try c.encode(notifyBefore, forKey: .notifyBefore)
        try c.encode(archivedAt, forKey: .archivedAt)
        try c.encode(celebrated, forKey: .celebrated)
    }

    private static func nonEmpty(_ text: String??) -> String? {
        guard let text = text ?? nil, !text.isEmpty else { return nil }
        return text
    }

    /// Lee un entero aunque venga como número decimal o como texto (la web usa `parseInt`).
    private static func lenientInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Double.self, forKey: key), value.isFinite { return Int(value) }
        if let text = try? c.decodeIfPresent(String.self, forKey: key) { return Int(text) }
        return nil
    }
}

/// Archivo de eventos en disco. Mismo formato que el archivo de exportación de la web.
nonisolated struct EventFile: Codable, Sendable {
    var version: Int = 1
    var app: String = "next-appointment"
    var events: [Event]
}
