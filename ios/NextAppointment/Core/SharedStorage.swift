import Foundation

/// Dónde se guardan los eventos. El archivo vive en un App Group para que el
/// widget pueda leerlo; si el grupo no está disponible, en Documentos.
nonisolated enum SharedStorage {
    static let appGroup = "group.com.aleweing.nextappointment"
    static let fileName = "events.json"

    /// Archivo de eventos compartido entre la app y el widget.
    static var eventsFileURL: URL {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        return (container ?? URL.documentsDirectory).appending(path: fileName)
    }

    /// Ubicación de la fase 1 (Documentos de la app), para migrar los datos.
    static var legacyFileURL: URL {
        URL.documentsDirectory.appending(path: fileName)
    }

    /// Si existe el archivo antiguo y aún no el compartido, lo mueve.
    static func migrateLegacyFileIfNeeded() {
        let manager = FileManager.default
        let shared = eventsFileURL, legacy = legacyFileURL
        guard shared != legacy, manager.fileExists(atPath: legacy.path), !manager.fileExists(atPath: shared.path)
        else { return }
        try? manager.moveItem(at: legacy, to: shared)
    }

    /// Lee los eventos de un archivo. `nil` si el archivo no existe; error si es ilegible.
    static func loadEvents(from url: URL = eventsFileURL) throws -> [Event]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try JSONDecoder().decode(EventFile.self, from: data).events
    }
}
