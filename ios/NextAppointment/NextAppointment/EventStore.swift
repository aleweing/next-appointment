import Foundation
import Observation

/// Guarda los eventos en un archivo JSON dentro de la carpeta de documentos de la app.
/// El archivo tiene el mismo formato que el de exportación de la web.
@Observable
final class EventStore {
    private(set) var events: [Event] = []

    private let fileURL: URL

    init(fileURL: URL = EventStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    static var defaultFileURL: URL {
        URL.documentsDirectory.appending(path: "events.json")
    }

    /// Eventos no archivados: los que se ven en el carrusel y en la lista.
    var activeEvents: [Event] {
        events.filter { $0.archivedAt == nil }
    }

    /// Eventos activos con "Próximos primero": menos tiempo restante, antes.
    func upcomingEvents(now: Date = Date()) -> [Event] {
        activeEvents
            .map { (event: $0, remaining: Countdown.remaining($0, now: now)) }
            .sorted { $0.remaining < $1.remaining }
            .map(\.event)
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

    // MARK: - Disco

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return } // primera apertura
        do {
            events = try JSONDecoder().decode(EventFile.self, from: data).events
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
    }
}
