import SwiftUI
import UserNotifications

@main
struct NextAppointmentApp: App {
    @State private var store: EventStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = EventStore()
        #if DEBUG
        // Para capturas y pruebas: `-demo-data` sustituye los eventos por unos de ejemplo.
        if ProcessInfo.processInfo.arguments.contains("-demo-data") {
            store.replaceAll(with: DemoData.events())
        }
        #endif
        _store = State(initialValue: store)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(store)
                // La interfaz está en español de España, también fechas y selectores.
                .environment(\.locale, Countdown.spanish)
                .tint(Theme.brand)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Al abrir la app se reprograman los avisos, para que las series
            // tengan siempre el de su próxima ocurrencia.
            let events = store.activeEvents
            Task { await NotificationScheduler.rescheduleAll(events) }
        }
    }
}
