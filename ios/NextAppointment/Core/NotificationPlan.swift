import Foundation

nonisolated extension Countdown {
    /// Momento del próximo aviso de un evento (`objetivo − notifyBefore`), o `nil`
    /// si no tiene aviso, está archivado, ya llegó o el aviso ya ha pasado.
    /// En las series, si el aviso de la próxima ocurrencia ya pasó, se usa la siguiente.
    static func nextNotificationDate(for event: Event, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let notifyBefore = event.notifyBefore, notifyBefore > 0,
              event.archivedAt == nil,
              !hasElapsed(event, now: now, calendar: calendar)
        else { return nil }

        var target = targetDate(event, now: now, calendar: calendar)
        for _ in 0..<2 {
            let fireDate = target.addingTimeInterval(-TimeInterval(notifyBefore))
            if fireDate > now { return fireDate }
            // Probar con la ocurrencia siguiente (solo existe en series sin terminar).
            let next = targetDate(event, now: target, calendar: calendar)
            if next <= target { return nil }
            target = next
        }
        return nil
    }
}
