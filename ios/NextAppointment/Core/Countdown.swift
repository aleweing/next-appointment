import Foundation

/// Lógica de cuenta atrás y recurrencia, portada de `js/countdown.js`.
///
/// Todas las funciones son puras: reciben `now` y `calendar` para poder probarlas
/// con fechas y husos horarios fijos. En la app se usan los valores por defecto.
///
/// Diferencia conocida con la web: cada ocurrencia se calcula desde el ancla
/// (ancla + N × intervalo) en vez de encadenar sumas sobre la ocurrencia anterior.
/// Así un evento mensual del día 31 cae en 28/29 de febrero y vuelve al 31 en
/// marzo; en JavaScript el 31 de enero + 1 mes desborda al 3 de marzo y la serie
/// se queda desplazada.
nonisolated enum Countdown {
    static let spanish = Locale(identifier: "es_ES")

    // MARK: - Ancla y ocurrencias

    /// Primera ocurrencia, tal como la escribió el usuario (`date` + `time` en hora local).
    static func anchorDate(_ event: Event, calendar: Calendar = .current) -> Date {
        localDate(day: event.date, time: event.time.isEmpty ? "00:00" : event.time, second: 0, calendar: calendar)
            ?? .distantPast
    }

    /// Avanza una fecha una "unidad × cantidad" de calendario (`advanceByRecurrence`).
    static func advance(_ date: Date, unit: RecurrenceUnit, interval: Int = 1, calendar: Calendar = .current) -> Date {
        occurrence(1, anchor: date, unit: unit, interval: interval, calendar: calendar)
    }

    /// Ocurrencia número `index` de la serie (0 = el ancla).
    static func occurrence(
        _ index: Int, anchor: Date, unit: RecurrenceUnit, interval: Int, calendar: Calendar = .current
    ) -> Date {
        guard index > 0 else { return anchor }
        let component: Calendar.Component
        let value: Int
        switch unit {
        case .none: return anchor
        case .day: (component, value) = (.day, interval * index)
        case .week: (component, value) = (.day, interval * 7 * index)
        case .month: (component, value) = (.month, interval * index)
        case .year: (component, value) = (.year, interval * index)
        }
        return calendar.date(byAdding: component, value: value, to: anchor) ?? anchor
    }

    /// Última ocurrencia válida de una serie limitada (`getLastOccurrence`).
    /// `nil` si el evento no es recurrente o la serie es indefinida.
    /// Si hay fecha de fin y máximo de repeticiones, gana el que se cumpla antes.
    static func lastOccurrence(_ event: Event, calendar: Calendar = .current) -> Date? {
        guard let index = lastOccurrenceIndex(event, calendar: calendar) else { return nil }
        let recurrence = event.recurrence
        return occurrence(
            index, anchor: anchorDate(event, calendar: calendar),
            unit: recurrence.unit, interval: recurrence.interval, calendar: calendar
        )
    }

    /// ¿La serie ya agotó su límite? (`isRecurrenceFinished`)
    static func isRecurrenceFinished(_ event: Event, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let last = lastOccurrence(event, calendar: calendar) else { return false }
        return now > last
    }

    /// Fecha objetivo (`getTargetDate`): el ancla si no es recurrente; si lo es,
    /// la primera ocurrencia posterior a `now`, sin pasar de la última válida.
    static func targetDate(_ event: Event, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let anchor = anchorDate(event, calendar: calendar)
        let recurrence = event.recurrence
        guard recurrence.unit != .none else { return anchor }

        let lastIndex = lastOccurrenceIndex(event, calendar: calendar) // nil = serie indefinida
        var index = startIndex(
            anchor: anchor, limit: now, unit: recurrence.unit, interval: recurrence.interval, calendar: calendar
        )
        if let lastIndex { index = min(index, lastIndex) }

        var target = occurrence(index, anchor: anchor, unit: recurrence.unit, interval: recurrence.interval, calendar: calendar)
        var guardCount = 0 // evita bucles infinitos ante fechas corruptas
        while target <= now, guardCount < 100_000 {
            if let lastIndex, index >= lastIndex { break }
            index += 1
            target = occurrence(index, anchor: anchor, unit: recurrence.unit, interval: recurrence.interval, calendar: calendar)
            guardCount += 1
        }
        return target
    }

    // MARK: - Cuenta atrás

    /// Segundos que faltan para la fecha objetivo. Negativo si ya pasó.
    static func remaining(_ event: Event, now: Date = Date(), calendar: Calendar = .current) -> TimeInterval {
        targetDate(event, now: now, calendar: calendar).timeIntervalSince(now)
    }

    struct Breakdown: Equatable, Sendable {
        var days: Int
        var hours: Int
        var minutes: Int
        var seconds: Int
    }

    /// Descompone unos segundos en días, horas, minutos y segundos (`breakdown`).
    static func breakdown(_ remaining: TimeInterval) -> Breakdown {
        let total = Int(max(remaining, 0).rounded(.down))
        return Breakdown(
            days: total / 86_400,
            hours: (total % 86_400) / 3_600,
            minutes: (total % 3_600) / 60,
            seconds: total % 60
        )
    }

    /// ¿Ya llegó? (`hasElapsed`). Una serie indefinida nunca "llega".
    static func hasElapsed(_ event: Event, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if event.recurrence.unit != .none {
            return isRecurrenceFinished(event, now: now, calendar: calendar)
        }
        return remaining(event, now: now, calendar: calendar) <= 0
    }

    // MARK: - Textos

    static let elapsedLabel = "¡Ya llegó! 🎉"

    /// Texto corto de la cuenta atrás: "12d 04h", "3h 07m", "15m" o "¡Ya llegó! 🎉".
    static func shortLabel(_ event: Event, now: Date = Date(), calendar: Calendar = .current) -> String {
        if hasElapsed(event, now: now, calendar: calendar) { return elapsedLabel }
        return shortLabel(remaining: remaining(event, now: now, calendar: calendar))
    }

    /// Igual que `shortLabel`, a partir de los segundos que faltan.
    static func shortLabel(remaining: TimeInterval) -> String {
        let b = breakdown(remaining)
        if b.days > 0 { return "\(b.days)d \(pad(b.hours))h" }
        if b.hours > 0 { return "\(b.hours)h \(pad(b.minutes))m" }
        return "\(b.minutes)m"
    }

    /// Fecha legible: "Jueves, 1 de abril de 2027 · 08:00". La hora se omite si es 00:00.
    static func formatDate(_ event: Event, now: Date = Date(), calendar: Calendar = .current) -> String {
        let target = targetDate(event, now: now, calendar: calendar)
        let style = Date.FormatStyle(locale: spanish, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().month(.wide).year()
        var text = target.formatted(style)
        text = text.prefix(1).uppercased(with: spanish) + text.dropFirst()
        if !event.time.isEmpty, event.time != "00:00" {
            text += " · \(event.time)"
        }
        return text
    }

    /// Formatea `YYYY-MM-DD` como "30 nov" (`formatShortDate` de `js/ui.js`).
    static func formatShortDate(_ isoDate: String, calendar: Calendar = .current) -> String {
        guard let date = localDate(day: isoDate, time: "00:00", second: 0, calendar: calendar) else { return isoDate }
        let style = Date.FormatStyle(locale: spanish, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated)
        return date.formatted(style).replacingOccurrences(of: ".", with: "")
    }

    /// Etiqueta de recurrencia (`recurrenceLabel` de `js/ui.js`): "Anual",
    /// "Cada 3 días", con sufijos " · 5 reps" y " · hasta 30 nov". Vacía si no repite.
    static func recurrenceLabel(_ recurrence: Recurrence, calendar: Calendar = .current) -> String {
        var label: String
        if recurrence.interval == 1 {
            switch recurrence.unit {
            case .none: return ""
            case .day: label = "Diario"
            case .week: label = "Semanal"
            case .month: label = "Mensual"
            case .year: label = "Anual"
            }
        } else {
            let plural: String
            switch recurrence.unit {
            case .none: return ""
            case .day: plural = "días"
            case .week: plural = "semanas"
            case .month: plural = "meses"
            case .year: plural = "años"
            }
            label = "Cada \(recurrence.interval) \(plural)"
        }
        if let maxCount = recurrence.maxCount {
            label += " · \(maxCount) rep\(maxCount != 1 ? "s" : "")"
        }
        if let endDate = recurrence.endDate {
            label += " · hasta \(formatShortDate(endDate, calendar: calendar))"
        }
        return label
    }

    // MARK: - Fechas en texto

    /// Convierte `YYYY-MM-DD` y `HH:MM` en un `Date` en la hora local del calendario.
    static func localDate(day: String, time: String, second: Int, calendar: Calendar = .current) -> Date? {
        let dayParts = day.split(separator: "-").map { Int($0) }
        let timeParts = time.split(separator: ":").map { Int($0) }
        guard dayParts.count == 3, timeParts.count >= 2,
              let year = dayParts[0], let month = dayParts[1], let dayOfMonth = dayParts[2],
              let hour = timeParts[0], let minute = timeParts[1],
              (1...12).contains(month), (1...31).contains(dayOfMonth),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        let components = DateComponents(
            year: year, month: month, day: dayOfMonth, hour: hour, minute: minute, second: second
        )
        return calendar.date(from: components)
    }

    /// Texto `YYYY-MM-DD` de una fecha en la hora local del calendario.
    static func dayString(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Texto `HH:MM` de una fecha en la hora local del calendario.
    static func timeString(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    // MARK: - Internos

    /// Índice de la última ocurrencia válida, o `nil` si no hay límite.
    private static func lastOccurrenceIndex(_ event: Event, calendar: Calendar) -> Int? {
        let recurrence = event.recurrence
        guard recurrence.unit != .none else { return nil }

        // La fecha de fin incluye ese día entero, hasta las 23:59:59.
        let end = recurrence.endDate.flatMap { localDate(day: $0, time: "23:59", second: 59, calendar: calendar) }
        if end == nil, recurrence.maxCount == nil { return nil } // serie indefinida

        // La primera ocurrencia siempre existe: el índice mínimo es 0.
        let maxIndex = recurrence.maxCount.map { $0 - 1 } ?? Int.max
        guard let end else { return maxIndex }

        let anchor = anchorDate(event, calendar: calendar)
        var index = min(
            maxIndex,
            startIndex(anchor: anchor, limit: end, unit: recurrence.unit, interval: recurrence.interval, calendar: calendar)
        )
        var guardCount = 0
        while index < maxIndex, guardCount < 100_000 {
            let next = occurrence(
                index + 1, anchor: anchor, unit: recurrence.unit, interval: recurrence.interval, calendar: calendar
            )
            if next > end { break } // gana la fecha de fin
            index += 1
            guardCount += 1
        }
        return index
    }

    /// Un índice cuya ocurrencia no es posterior a `limit`, cercano al mayor posible.
    /// Sirve para no recorrer la serie desde el ancla en eventos con años de historia:
    /// el resultado es el mismo que avanzando de uno en uno, solo que más rápido.
    private static func startIndex(
        anchor: Date, limit: Date, unit: RecurrenceUnit, interval: Int, calendar: Calendar
    ) -> Int {
        let elapsed = limit.timeIntervalSince(anchor)
        guard elapsed > 0 else { return 0 }

        // Duración máxima de un paso: ninguna ocurrencia puede ir más lejos que esto.
        let maxDays: Double
        switch unit {
        case .none: return 0
        case .day: maxDays = 1
        case .week: maxDays = 7
        case .month: maxDays = 31
        case .year: maxDays = 366
        }
        let maxStep = maxDays * 86_400 * Double(interval)
        var index = max(0, Int(elapsed / maxStep) - 1)

        // Red de seguridad por si el calendario hace algo inesperado.
        while index > 0, occurrence(index, anchor: anchor, unit: unit, interval: interval, calendar: calendar) > limit {
            index -= 1
        }
        return index
    }

    private static func pad(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}
