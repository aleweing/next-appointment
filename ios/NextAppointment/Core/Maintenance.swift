import Foundation

/// Archivado automático y celebración (portado de `runArchiveMaintenance`
/// y `checkCelebrations` de `js/app.js`).
nonisolated extension Countdown {
    /// Un evento único se archiva cuando hace 24 horas que pasó.
    static let archiveDelay: TimeInterval = 24 * 60 * 60
    /// Un evento archivado se borra definitivamente a los 30 días.
    static let deleteDelay: TimeInterval = 30 * 24 * 60 * 60

    /// Aplica el mantenimiento que se hace al abrir la app y devuelve la lista resultante:
    /// - evento no recurrente que pasó hace 24 horas o más → se archiva;
    /// - serie recurrente terminada → se archiva al instante;
    /// - archivado hace 30 días o más → se elimina.
    /// Las series sin límite nunca se archivan.
    static func archiveMaintenance(_ events: [Event], now: Date = Date(), calendar: Calendar = .current) -> [Event] {
        let nowMs = now.timeIntervalSince1970 * 1000
        var result: [Event] = []
        for var event in events {
            if let archivedAt = event.archivedAt {
                if nowMs - archivedAt >= deleteDelay * 1000 { continue } // toca borrarlo
                result.append(event)
                continue
            }
            if event.recurrence.unit != .none {
                if isRecurrenceFinished(event, now: now, calendar: calendar) {
                    event.archivedAt = nowMs
                }
            } else if hasElapsed(event, now: now, calendar: calendar),
                      now.timeIntervalSince(targetDate(event, now: now, calendar: calendar)) >= archiveDelay {
                event.archivedAt = nowMs
            }
            result.append(event)
        }
        return result
    }

    /// Días que faltan para que un evento archivado se elimine (30 si no está archivado).
    static func daysUntilDeletion(_ event: Event, now: Date = Date()) -> Int {
        guard let archivedAt = event.archivedAt else { return 30 }
        let elapsedDays = Int(((now.timeIntervalSince1970 * 1000 - archivedAt) / 86_400_000).rounded(.down))
        return max(0, 30 - elapsedDays)
    }

    /// Eventos que han llegado y todavía no se han celebrado, el más reciente primero.
    /// Solo cuentan los eventos únicos y activos: las series no se celebran, como en la web.
    static func eventsToCelebrate(_ events: [Event], now: Date = Date(), calendar: Calendar = .current) -> [Event] {
        events
            .filter { event in
                event.archivedAt == nil && !event.celebrated
                    && event.recurrence.unit == .none
                    && hasElapsed(event, now: now, calendar: calendar)
            }
            .sorted { anchorDate($0, calendar: calendar) > anchorDate($1, calendar: calendar) }
    }
}
