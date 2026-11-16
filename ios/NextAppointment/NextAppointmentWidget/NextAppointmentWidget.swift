import SwiftUI
import WidgetKit

/// Lo que muestra el widget en un momento dado: los próximos eventos.
struct CountdownEntry: TimelineEntry {
    let date: Date
    let events: [Event]
}

/// Lee los eventos del archivo compartido con la app (App Group) y prepara
/// las actualizaciones de los próximos días.
struct CountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: Date(), events: Self.sampleEvents())
    }

    func getSnapshot(in context: Context, completion: @escaping (CountdownEntry) -> Void) {
        let now = Date()
        var events = WidgetTimeline.upcoming(loadEvents(), at: now)
        // En la galería de widgets, sin eventos todavía, se enseña un ejemplo.
        if events.isEmpty, context.isPreview { events = Self.sampleEvents(now: now) }
        completion(CountdownEntry(date: now, events: events))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CountdownEntry>) -> Void) {
        let now = Date()
        let events = loadEvents()
        let entries = WidgetTimeline.refreshDates(events, from: now).map { date in
            CountdownEntry(date: date, events: WidgetTimeline.upcoming(events, at: date))
        }
        // Pasada una semana se vuelve a calcular; la app también refresca el widget al guardar.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(7 * 86_400))))
    }

    private func loadEvents() -> [Event] {
        ((try? SharedStorage.loadEvents()) ?? nil) ?? []
    }

    static func sampleEvents(now: Date = Date()) -> [Event] {
        let day = Countdown.dayString(now.addingTimeInterval(12 * 86_400 + 3_600))
        return [
            Event(id: "ejemplo", name: "Viaje a Japón", date: day, time: "08:00", emoji: "✈️", color: "#0984e3", category: "travel"),
        ]
    }
}

struct NextAppointmentWidget: Widget {
    let kind = "NextAppointmentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
                .environment(\.locale, Countdown.spanish)
        }
        .configurationDisplayName("Próxima cuenta atrás")
        .description("Tu próximo evento y cuánto falta.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CountdownEntry

    var body: some View {
        Group {
            if let first = entry.events.first {
                if family == .systemMedium {
                    HStack(spacing: 14) {
                        MainEventView(event: first, now: entry.date)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if entry.events.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(entry.events.dropFirst().prefix(2)) { event in
                                    SecondaryEventView(event: event, now: entry.date)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    MainEventView(event: first, now: entry.date)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                EmptyWidgetView()
            }
        }
        .containerBackground(for: .widget) {
            WidgetBackground(colorHex: entry.events.first?.color)
        }
    }
}

/// El evento más cercano: emoji, nombre, lo que falta y la fecha.
private struct MainEventView: View {
    let event: Event
    let now: Date

    var body: some View {
        let target = Countdown.targetDate(event, now: now)
        let accent = Theme.accent(event.color)

        VStack(alignment: .leading, spacing: 2) {
            Text(event.emoji)
                .font(.system(size: 26))
            Text(event.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let days = WidgetTimeline.daysLabel(remaining: target.timeIntervalSince(now)) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(days.value)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                    Text(days.unit)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(accent)
                .lineLimit(1)
            } else {
                // Menos de un día: contador en vivo, que el sistema actualiza solo.
                Text(timerInterval: now...max(target, now), countsDown: true)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(dateText(target))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
        }
    }

    /// "25 dic" y, si el evento tiene hora, "25 dic · 08:00".
    private func dateText(_ target: Date) -> String {
        var text = Countdown.formatShortDate(Countdown.dayString(target))
        if !event.time.isEmpty, event.time != "00:00" { text += " · \(event.time)" }
        return text
    }
}

/// Fila pequeña para los siguientes eventos (solo en el tamaño mediano).
private struct SecondaryEventView: View {
    let event: Event
    let now: Date

    /// Días enteros que faltan o, por debajo de un día, un contador en vivo.
    /// No se muestran las horas porque el widget solo se refresca al cambiar el día.
    private var remainingText: Text {
        let target = Countdown.targetDate(event, now: now)
        if let days = WidgetTimeline.daysLabel(remaining: target.timeIntervalSince(now)) {
            return Text("\(days.value) \(days.unit)")
        }
        return Text(timerInterval: now...max(target, now), countsDown: true)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(event.emoji)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text(event.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                remainingText
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent(event.color))
                    .lineLimit(1)
            }
        }
    }
}

private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "hourglass")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.brand)
            Text("Nada en el horizonte")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("Crea un evento en la app")
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
    }
}

/// Fondo de tarjeta teñido suavemente con el color del evento, como en la app.
private struct WidgetBackground: View {
    let colorHex: String?

    var body: some View {
        ZStack {
            Theme.card
            if let colorHex {
                LinearGradient(
                    colors: [Color(hex: colorHex).opacity(0.22), Color(hex: colorHex).opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
    }
}
