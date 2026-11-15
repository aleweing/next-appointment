import Foundation
import UserNotifications

/// Avisos locales antes de cada evento. El identificador de la notificación es
/// el `id` del evento, así que al reprogramar se sustituye la anterior.
enum NotificationScheduler {

    /// Pide permiso de notificaciones si hace falta. Devuelve `true` si está concedido.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default:
            return false
        }
    }

    /// ¿Ya hay permiso? No muestra ningún diálogo.
    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    /// Programa (o reprograma) el aviso de un evento. Si no tiene aviso, lo cancela.
    static func schedule(_ event: Event, now: Date = Date()) async {
        cancel(id: event.id)
        guard let fireDate = Countdown.nextNotificationDate(for: event, now: now),
              let notifyBefore = event.notifyBefore
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(event.emoji) \(event.name)"
        content.body = "Queda \(Countdown.shortLabel(remaining: TimeInterval(notifyBefore))) para este evento."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("No se pudo programar el aviso de \(event.id): \(error)")
        }
    }

    static func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Reprograma los avisos de todos los eventos (se llama al abrir la app, para
    /// que las series tengan siempre programado el aviso de su próxima ocurrencia).
    static func rescheduleAll(_ events: [Event]) async {
        guard await isAuthorized() else { return }
        for event in events {
            await schedule(event)
        }
    }
}

/// Permite que el aviso se vea también con la app abierta en primer plano.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
