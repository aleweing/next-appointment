import Foundation
import Observation
import WidgetKit

/// Guarda los eventos en un archivo JSON con el mismo formato que el de
/// exportación de la web. El archivo está en el App Group, para el widget.
@Observable
final class EventStore {
    private(set) var events: [Event] = []

    private let fileURL: URL

    /// Sin argumentos usa el archivo compartido (y migra el de la fase 1 si existe).
    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            SharedStorage.migrateLegacyFileIfNeeded()
            self.fileURL = SharedStorage.eventsFileURL
        }
        load()
    }

    /// Eventos no archivados: los que se ven en el carrusel y en la lista.
    var activeEvents: [Event] {
        events.filter { $0.archivedAt == nil }
    }

    /// Eventos archivados, el archivado más reciente primero.
    var archivedEvents: [Event] {
        events.filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? 0) > ($1.archivedAt ?? 0) }
    }

    /// Eventos activos con "Próximos primero": menos tiempo restante, antes.
    func upcomingEvents(now: Date = Date()) -> [Event] {
        EventList.sorted(activeEvents, by: .dateAsc, now: now)
    }

    /// Añade un evento o sustituye el que tenga el mismo id.
    func upsert(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        save()
    }

    func delete(id: String) {
        events.removeAll { $0.id == id }
        save()
    }

    func replaceAll(with newEvents: [Event]) {
        events = newEvents
        save()
    }

    /// Archivado automático al abrir la app. Devuelve los ids de los eventos que
    /// han dejado de estar activos (archivados o borrados), para cancelar sus avisos.
    @discardableResult
    func runMaintenance(now: Date = Date()) -> [String] {
        let updated = Countdown.archiveMaintenance(events, now: now)
        guard updated != events else { return [] }
        let stillActive = Set(updated.filter { $0.archivedAt == nil }.map(\.id))
        let noLongerActive = activeEvents.map(\.id).filter { !stillActive.contains($0) }
        events = updated
        save()
        return noLongerActive
    }

    /// Devuelve un evento archivado a la lista activa.
    func restore(id: String) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].archivedAt = nil
        // Si ya pasó, se da por celebrado: restaurar no debe lanzar el confeti.
        if Countdown.hasElapsed(events[index]) { events[index].celebrated = true }
        save()
    }

    /// Añade los eventos importados. Los que ya pasaron entran como celebrados,
    /// para que no salte la celebración de algo antiguo. Devuelve cuántos se añadieron.
    @discardableResult
    func importEvents(_ newEvents: [Event], now: Date = Date()) -> Int {
        let existing = Set(events.map(\.id))
        let toAdd = newEvents
            .filter { !existing.contains($0.id) }
            .map { event -> Event in
                var event = event
                event.celebrated = Countdown.hasElapsed(event, now: now)
                return event
            }
        guard !toAdd.isEmpty else { return 0 }
        events.append(contentsOf: toAdd)
        save()
        return toAdd.count
    }

    func markCelebrated(ids: [String]) {
        var changed = false
        for index in events.indices where ids.contains(events[index].id) && !events[index].celebrated {
            events[index].celebrated = true
            changed = true
        }
        if changed { save() }
    }

    // MARK: - Disco

    private func load() {
        do {
            events = try SharedStorage.loadEvents(from: fileURL) ?? [] // sin archivo: primera apertura
        } catch {
            // Archivo ilegible: se aparta en vez de pisarlo, para no perder datos.
            let backup = fileURL.deletingLastPathComponent().appending(path: "events.ilegible.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            print("No se pudo leer events.json: \(error)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(EventFile(events: events))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("No se pudo guardar events.json: \(error)")
        }
        // El widget lee este archivo: hay que avisarle de que ha cambiado.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
