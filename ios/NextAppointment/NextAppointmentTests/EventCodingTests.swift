import XCTest

/// Tests del modelo `Event`: lectura del JSON de la web (incluidos los formatos
/// antiguos de recurrencia) y escritura compatible.
final class EventCodingTests: XCTestCase {

    private func decode(_ json: String) throws -> Event {
        try JSONDecoder().decode(Event.self, from: Data(json.utf8))
    }

    func testLeeUnEventoCompletoDeLaWeb() throws {
        let e = try decode("""
        {
          "id": "evt_abc_123456", "name": "Viaje a Japón", "date": "2026-09-01", "time": "08:00",
          "emoji": "✈️", "color": "#0984e3", "category": "travel",
          "recurrenceUnit": "week", "recurrenceInterval": 2,
          "recurrenceEndDate": "2026-12-31", "recurrenceMaxCount": 5,
          "notifyBefore": 3600, "archivedAt": null,
          "_celebrated": false, "_notifiedKey": null
        }
        """)
        XCTAssertEqual(e.id, "evt_abc_123456")
        XCTAssertEqual(e.name, "Viaje a Japón")
        XCTAssertEqual(e.date, "2026-09-01")
        XCTAssertEqual(e.time, "08:00")
        XCTAssertEqual(e.emoji, "✈️")
        XCTAssertEqual(e.color, "#0984e3")
        XCTAssertEqual(e.category, "travel")
        XCTAssertEqual(e.recurrence, Recurrence(unit: .week, interval: 2, endDate: "2026-12-31", maxCount: 5))
        XCTAssertEqual(e.notifyBefore, 3600)
        XCTAssertNil(e.archivedAt)
    }

    func testValoresPorDefecto() throws {
        let e = try decode(#"{ "id": "evt_1", "name": "Mínimo", "date": "2026-09-01" }"#)
        XCTAssertEqual(e.time, "00:00")
        XCTAssertEqual(e.emoji, "⏳")
        XCTAssertEqual(e.color, "#6c5ce7")
        XCTAssertEqual(e.category, "other")
        XCTAssertEqual(e.recurrence, Recurrence(unit: .none, interval: 1, endDate: nil, maxCount: nil))
        XCTAssertNil(e.notifyBefore)
    }

    func testFormatoIntermedioDeRecurrencia() throws {
        let anual = try decode(#"{ "id": "a", "name": "A", "date": "2020-05-20", "recurrence": "yearly" }"#)
        XCTAssertEqual(anual.recurrence.unit, .year)
        XCTAssertEqual(anual.recurrence.interval, 1)
        let mensual = try decode(#"{ "id": "b", "name": "B", "date": "2020-05-20", "recurrence": "monthly" }"#)
        XCTAssertEqual(mensual.recurrence.unit, .month)
        let ninguna = try decode(#"{ "id": "c", "name": "C", "date": "2020-05-20", "recurrence": "none" }"#)
        XCTAssertEqual(ninguna.recurrence.unit, .none)
    }

    func testFormatoMasAntiguoDeRecurrencia() throws {
        let anual = try decode(#"{ "id": "a", "name": "A", "date": "2020-05-20", "recurring": true }"#)
        XCTAssertEqual(anual.recurrence.unit, .year)
        let unico = try decode(#"{ "id": "b", "name": "B", "date": "2020-05-20", "recurring": false }"#)
        XCTAssertEqual(unico.recurrence.unit, .none)
    }

    func testNumerosComoTextoYValoresNoValidos() throws {
        let e = try decode("""
        { "id": "a", "name": "A", "date": "2026-01-01", "recurrenceUnit": "day",
          "recurrenceInterval": "3", "recurrenceMaxCount": "5", "notifyBefore": 0 }
        """)
        XCTAssertEqual(e.recurrence.interval, 3)
        XCTAssertEqual(e.recurrence.maxCount, 5)
        XCTAssertNil(e.notifyBefore, "0 segundos equivale a no avisar")

        let raro = try decode("""
        { "id": "b", "name": "B", "date": "2026-01-01", "recurrenceUnit": "day",
          "recurrenceInterval": 0, "recurrenceMaxCount": -2, "recurrenceEndDate": "" }
        """)
        XCTAssertEqual(raro.recurrence, Recurrence(unit: .day, interval: 1, endDate: nil, maxCount: nil))
    }

    func testNombreSeRecortaA40Caracteres() throws {
        let largo = String(repeating: "x", count: 60)
        let e = try decode(#"{ "id": "a", "name": "\#(largo)", "date": "2026-01-01" }"#)
        XCTAssertEqual(e.name.count, 40)
    }

    func testIdaYVuelta() throws {
        let original = Event(
            id: "evt_x", name: "Cumple de Ana", date: "1990-05-20", time: "09:30",
            emoji: "🎂", color: "#e84393", category: "birthday",
            recurrenceUnit: .year, recurrenceInterval: 1,
            recurrenceEndDate: nil, recurrenceMaxCount: 10, notifyBefore: 86_400
        )
        let file = EventFile(events: [original])
        let data = try JSONEncoder().encode(file)
        let restored = try JSONDecoder().decode(EventFile.self, from: data)
        XCTAssertEqual(restored.events, [original])
        XCTAssertEqual(restored.version, 1)
        XCTAssertEqual(restored.app, "next-appointment")

        // Los opcionales vacíos se escriben como null, como en la web.
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
        XCTAssertTrue(object?["recurrenceEndDate"] is NSNull)
        XCTAssertTrue(object?["archivedAt"] is NSNull)
    }

    func testIdGenerado() {
        let id = Event.generateId()
        XCTAssertTrue(id.hasPrefix("evt_"))
        XCTAssertEqual(id.split(separator: "_").count, 3)
        XCTAssertNotEqual(id, Event.generateId())
    }

    func testCategoriaDesconocidaEsOtros() {
        XCTAssertEqual(Catalog.category(id: "travel").label, "Viajes")
        XCTAssertEqual(Catalog.category(id: "no-existe").id, "other")
    }
}
