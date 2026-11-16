import Foundation

/// Valores del formulario mientras se crea o edita un evento.
struct EventDraft: Equatable {
    var name = ""
    /// Fecha y hora del evento (hora local).
    var when: Date
    var emoji = Catalog.defaultEmoji
    var color = Catalog.defaultColor
    var category = Catalog.defaultCategoryId

    var repeats = false
    var interval = 1
    var unit: RecurrenceUnit = .year
    var hasEndDate = false
    var endDate: Date
    var hasMaxCount = false
    var maxCount = 5

    var notifies = false
    var notifyDays = 0
    var notifyHours = 1
    var notifyMinutes = 0

    /// Formulario de evento nuevo: mañana a las 00:00, como en la web.
    init(now: Date = Date(), calendar: Calendar = .current) {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        when = tomorrow
        endDate = calendar.date(byAdding: .year, value: 1, to: tomorrow) ?? tomorrow
    }

    /// Formulario de edición, relleno con los datos del evento.
    init(event: Event, now: Date = Date(), calendar: Calendar = .current) {
        self.init(now: now, calendar: calendar)
        name = event.name
        when = Countdown.anchorDate(event, calendar: calendar)
        emoji = event.emoji
        color = event.color
        category = event.category

        let recurrence = event.recurrence
        repeats = recurrence.unit != .none
        interval = recurrence.interval
        unit = repeats ? recurrence.unit : .year
        if let end = recurrence.endDate,
           let date = Countdown.localDate(day: end, time: "00:00", second: 0, calendar: calendar) {
            hasEndDate = true
            endDate = date
        } else {
            endDate = calendar.date(byAdding: .year, value: 1, to: when) ?? when
        }
        if let max = recurrence.maxCount {
            hasMaxCount = true
            maxCount = max
        }

        if let seconds = event.notifyBefore, seconds > 0 {
            notifies = true
            notifyDays = seconds / 86_400
            notifyHours = (seconds % 86_400) / 3_600
            notifyMinutes = (seconds % 3_600) / 60
        }
    }

    var trimmedName: String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Event.maxNameLength))
    }

    /// Segundos de antelación del aviso, o `nil` si no hay aviso (todo a 0 = sin aviso).
    var notifyBefore: Int? {
        guard notifies else { return nil }
        let seconds = notifyDays * 86_400 + notifyHours * 3_600 + notifyMinutes * 60
        return seconds > 0 ? seconds : nil
    }

    /// ¿Hay algo fuera de los valores por defecto en "Más opciones"?
    var hasNonDefaultOptions: Bool {
        emoji != Catalog.defaultEmoji || color != Catalog.defaultColor
            || category != Catalog.defaultCategoryId || repeats || notifyBefore != nil
    }

    /// La fecha de fin de la repetición no puede ser anterior a la fecha del evento.
    func endDateIsValid(calendar: Calendar = .current) -> Bool {
        guard repeats, hasEndDate else { return true }
        return Countdown.dayString(endDate, calendar: calendar) >= Countdown.dayString(when, calendar: calendar)
    }

    /// Construye el evento a guardar. Al editar se conserva el id.
    func makeEvent(editing existing: Event? = nil, now: Date = Date(), calendar: Calendar = .current) -> Event {
        var event = Event(
            id: existing?.id ?? Event.generateId(),
            name: trimmedName,
            date: Countdown.dayString(when, calendar: calendar),
            time: Countdown.timeString(when, calendar: calendar),
            emoji: emoji,
            color: color,
            category: category,
            recurrenceUnit: repeats ? unit : .none,
            recurrenceInterval: repeats ? max(1, interval) : 1,
            recurrenceEndDate: repeats && hasEndDate ? Countdown.dayString(endDate, calendar: calendar) : nil,
            recurrenceMaxCount: repeats && hasMaxCount ? min(max(1, maxCount), 9_999) : nil,
            notifyBefore: notifyBefore,
            archivedAt: existing?.archivedAt
        )

        let elapsed = Countdown.hasElapsed(event, now: now, calendar: calendar)
        if let existing, existing.date == event.date, existing.time == event.time {
            event.celebrated = existing.celebrated
        } else {
            // Fecha nueva: se celebrará al llegar. Si ya nace pasada, no hay nada que celebrar.
            event.celebrated = elapsed
        }
        // Un evento archivado que vuelve a tener futuro se reactiva.
        if event.archivedAt != nil, !elapsed {
            event.archivedAt = nil
        }
        return event
    }
}
