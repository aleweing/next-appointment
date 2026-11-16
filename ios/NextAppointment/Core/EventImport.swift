import Foundation

/// Importación del archivo `.json` que exporta la app web
/// (`{ "version": 1, "app": "next-appointment", "events": [...] }`).
nonisolated enum EventImport {

    enum ImportError: Error, Equatable {
        /// El archivo no es JSON o no lo ha exportado Next Appointment.
        case notAnExportFile
    }

    /// Qué pasaría al importar: cuántos eventos trae el archivo y cuáles son nuevos.
    struct Plan: Equatable, Sendable {
        let total: Int
        let newEvents: [Event]

        var skipped: Int { total - newEvents.count }

        /// "El archivo contiene 5 eventos. Se añadirán 3 nuevos. Se omitirán 2 ya existentes."
        var summary: String {
            var text = "El archivo contiene \(total) evento\(total != 1 ? "s" : "")."
            if !newEvents.isEmpty {
                text += " Se añadirán \(newEvents.count) nuevo\(newEvents.count != 1 ? "s" : "")."
            }
            if skipped > 0 {
                text += " Se omitirán \(skipped) ya existente\(skipped != 1 ? "s" : "")."
            }
            return text
        }
    }

    /// Lee los eventos de un archivo de exportación. Descarta los que no tienen
    /// nombre o fecha y los repetidos dentro del propio archivo.
    static func parse(_ data: Data) throws -> [Event] {
        guard let file = try? JSONDecoder().decode(ExportFile.self, from: data),
              file.app == "next-appointment"
        else { throw ImportError.notAnExportFile }

        var seen = Set<String>()
        var events: [Event] = []
        for case var event? in file.events.map(\.event) {
            guard !event.name.isEmpty, !event.date.isEmpty, seen.insert(event.id).inserted else { continue }
            // Lo importado entra como evento activo y sin celebrar.
            event.archivedAt = nil
            event.celebrated = false
            events.append(event)
        }
        return events
    }

    /// Los duplicados se detectan por `id` y se omiten.
    static func plan(incoming: [Event], existingIds: Set<String>) -> Plan {
        Plan(total: incoming.count, newEvents: incoming.filter { !existingIds.contains($0.id) })
    }

    /// "✅ 3 eventos importados correctamente."
    static func resultMessage(imported count: Int) -> String {
        "✅ \(count) evento\(count != 1 ? "s" : "") importado\(count != 1 ? "s" : "") correctamente."
    }

    private struct ExportFile: Decodable {
        let app: String?
        let events: [LossyEvent]
    }

    /// Un evento que, si no se puede leer, no rompe la lectura del resto.
    private struct LossyEvent: Decodable {
        let event: Event?

        init(from decoder: Decoder) throws {
            event = try? Event(from: decoder)
        }
    }
}
