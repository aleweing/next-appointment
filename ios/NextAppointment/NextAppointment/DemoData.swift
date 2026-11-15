#if DEBUG
import Foundation

/// Eventos de ejemplo para capturas y pruebas. Solo en compilaciones de depuración,
/// y solo si la app se lanza con el argumento `-demo-data`.
enum DemoData {
    static func events(now: Date = Date(), calendar: Calendar = .current) -> [Event] {
        func day(_ offset: Int) -> String {
            Countdown.dayString(calendar.date(byAdding: .day, value: offset, to: now) ?? now, calendar: calendar)
        }
        let inThreeHours = now.addingTimeInterval(3 * 3_600 + 7 * 60)
        let year = calendar.component(.year, from: now)

        return [
            Event(
                id: "evt_demo_japon", name: "Viaje a Japón", date: day(47), time: "08:00",
                emoji: "✈️", color: "#0984e3", category: "travel", notifyBefore: 86_400
            ),
            Event(
                id: "evt_demo_cumple", name: "Cumple de Ana", date: "1990-\(day(12).dropFirst(5))",
                emoji: "🎂", color: "#e84393", category: "birthday", recurrenceUnit: .year
            ),
            Event(
                id: "evt_demo_concierto", name: "Concierto en el Auditori",
                date: Countdown.dayString(inThreeHours, calendar: calendar),
                time: Countdown.timeString(inThreeHours, calendar: calendar),
                emoji: "🎉", color: "#fdcb6e", category: "festival", notifyBefore: 1_800
            ),
            Event(
                id: "evt_demo_dentista", name: "Revisión del dentista", date: day(-60), time: "10:30",
                emoji: "⏳", color: "#00b894", category: "health",
                recurrenceUnit: .month, recurrenceInterval: 6, recurrenceMaxCount: 4
            ),
            Event(
                id: "evt_demo_yoga", name: "Clase de yoga", date: day(-7), time: "19:00",
                emoji: "❤️", color: "#00cec9", category: "other",
                recurrenceUnit: .day, recurrenceInterval: 3, recurrenceEndDate: "\(year + 1)-06-30"
            ),
            Event(
                id: "evt_demo_navidad", name: "Navidad", date: "2020-12-25",
                emoji: "🎄", color: "#e17055", category: "party", recurrenceUnit: .year
            ),
        ]
    }
}
#endif
