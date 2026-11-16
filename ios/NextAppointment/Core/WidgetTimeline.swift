import Foundation

/// Qué enseña el widget en cada momento y cuándo hay que refrescarlo.
nonisolated enum WidgetTimeline {

    /// Próximos eventos en un momento dado: activos, sin llegar todavía, el más cercano primero.
    static func upcoming(
        _ events: [Event], at date: Date, limit: Int = 3, calendar: Calendar = .current
    ) -> [Event] {
        let pending = events.filter {
            $0.archivedAt == nil && Countdown.targetDate($0, now: date, calendar: calendar) > date
        }
        return Array(EventList.sorted(pending, by: .dateAsc, now: date, calendar: calendar).prefix(limit))
    }

    /// Momentos en los que cambia lo que muestra el widget durante los próximos días:
    /// cuando baja el número de días de alguno de los próximos eventos y cuando uno llega.
    /// Por debajo de un día el widget usa un contador en vivo y no necesita refrescos.
    static func refreshDates(
        _ events: [Event], from now: Date, days: Int = 7, limit: Int = 3, calendar: Calendar = .current
    ) -> [Date] {
        let horizon = now.addingTimeInterval(Double(days) * 86_400)
        var dates: Set<Date> = [now]
        for event in upcoming(events, at: now, limit: limit, calendar: calendar) {
            let target = Countdown.targetDate(event, now: now, calendar: calendar)
            // Justo después de llegar: el widget pasa al siguiente evento (o a la siguiente ocurrencia).
            let arrival = target.addingTimeInterval(1)
            if arrival <= horizon { dates.insert(arrival) }
            // Cada vez que queda un día entero menos.
            var wholeDays = Int(target.timeIntervalSince(now) / 86_400)
            while wholeDays >= 1 {
                let boundary = target.addingTimeInterval(-Double(wholeDays) * 86_400)
                if boundary > now, boundary <= horizon { dates.insert(boundary) }
                wholeDays -= 1
            }
        }
        return dates.sorted()
    }

    /// Texto grande del widget cuando falta un día o más: ("12", "días") o ("1", "día").
    static func daysLabel(remaining: TimeInterval) -> (value: String, unit: String)? {
        let days = Countdown.breakdown(remaining).days
        guard days >= 1 else { return nil }
        return ("\(days)", days == 1 ? "día" : "días")
    }
}
