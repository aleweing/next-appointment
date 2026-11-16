import XCTest

/// Tests de la fase 2: archivado automático, celebración, orden, filtro e importación.
final class MaintenanceAndListTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        calendar.locale = Locale(identifier: "es_ES")
        return calendar
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func ms(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }

    private func event(
        _ id: String, _ date: String, _ time: String = "00:00", name: String = "Evento",
        category: String = "other", unit: RecurrenceUnit = .none,
        endDate: String? = nil, maxCount: Int? = nil, archivedAt: Double? = nil, celebrated: Bool = false
    ) -> Event {
        Event(
            id: id, name: name, date: date, time: time, category: category,
            recurrenceUnit: unit, recurrenceEndDate: endDate, recurrenceMaxCount: maxCount,
            archivedAt: archivedAt, celebrated: celebrated
        )
    }

    private func maintain(_ events: [Event], _ now: Date) -> [Event] {
        Countdown.archiveMaintenance(events, now: now, calendar: calendar)
    }

    // MARK: - Archivado automático

    func testEventoUnicoSeArchivaALas24Horas() {
        let e = event("a", "2026-11-10", "08:00")
        XCTAssertNil(maintain([e], at(2026, 11, 9))[0].archivedAt, "aún no ha llegado")
        XCTAssertNil(maintain([e], at(2026, 11, 11, 7, 59))[0].archivedAt, "pasó hace menos de 24 h")
        let now = at(2026, 11, 11, 8, 0)
        XCTAssertEqual(maintain([e], now)[0].archivedAt, ms(now), "pasó hace 24 h justas")
    }

    func testSerieTerminadaSeArchivaAlInstante() {
        let serie = event("a", "2026-11-10", "08:00", unit: .day, maxCount: 3) // 10, 11 y 12
        XCTAssertNil(maintain([serie], at(2026, 11, 12, 8, 0))[0].archivedAt)
        let now = at(2026, 11, 12, 8, 1)
        XCTAssertEqual(maintain([serie], now)[0].archivedAt, ms(now), "sin esperar 24 h")
    }

    func testSerieSinLimiteNuncaSeArchiva() {
        let cumple = event("a", "1990-05-20", unit: .year)
        XCTAssertNil(maintain([cumple], at(2090, 1, 1))[0].archivedAt)
    }

    func testArchivadoSeBorraALos30Dias() {
        let archivedAt = at(2026, 10, 1, 12, 0)
        let e = event("a", "2026-09-30", archivedAt: ms(archivedAt))
        // 30 días de 24 horas después son las 11:00 del 31: el 25 de octubre se retrasa el reloj.
        XCTAssertEqual(maintain([e], at(2026, 10, 31, 10, 59)).count, 1, "todavía no han pasado 30 días")
        XCTAssertEqual(maintain([e], at(2026, 10, 31, 11, 0)).count, 0)
    }

    func testMantenimientoNoTocaLoDemas() {
        let futuro = event("a", "2027-01-01")
        let yaArchivado = event("b", "2026-01-01", archivedAt: ms(at(2026, 11, 1)))
        let result = maintain([futuro, yaArchivado], at(2026, 11, 15))
        XCTAssertEqual(result, [futuro, yaArchivado])
    }

    func testDiasHastaElBorrado() {
        let archivedAt = at(2026, 11, 1, 12, 0)
        let e = event("a", "2026-10-30", archivedAt: ms(archivedAt))
        XCTAssertEqual(Countdown.daysUntilDeletion(e, now: archivedAt), 30)
        XCTAssertEqual(Countdown.daysUntilDeletion(e, now: archivedAt.addingTimeInterval(10 * 86_400 + 60)), 20)
        XCTAssertEqual(Countdown.daysUntilDeletion(e, now: archivedAt.addingTimeInterval(40 * 86_400)), 0)
        XCTAssertEqual(Countdown.daysUntilDeletion(event("b", "2027-01-01"), now: archivedAt), 30)
    }

    // MARK: - Celebración

    func testEventosPorCelebrar() {
        let now = at(2026, 11, 15, 10, 0)
        let recienLlegado = event("a", "2026-11-15", "09:00")
        let llegoAyer = event("b", "2026-11-14", "20:00")
        let futuro = event("c", "2026-12-25")
        let yaCelebrado = event("d", "2026-11-15", "08:00", celebrated: true)
        let archivado = event("e", "2026-11-01", archivedAt: ms(at(2026, 11, 2)))
        let serieTerminada = event("f", "2026-11-01", unit: .day, maxCount: 2)

        let pending = Countdown.eventsToCelebrate(
            [llegoAyer, futuro, recienLlegado, yaCelebrado, archivado, serieTerminada], now: now, calendar: calendar
        )
        XCTAssertEqual(pending.map(\.id), ["a", "b"], "solo únicos activos sin celebrar, el más reciente primero")
    }

    // MARK: - Orden

    func testOrdenPorFecha() {
        let now = at(2026, 11, 15)
        let events = [
            event("lejos", "2027-06-01"),
            event("pasado", "2026-11-01"),
            event("cerca", "2026-11-20"),
            event("cumple", "1990-12-01", unit: .year), // próxima ocurrencia: 1-dic-2026
        ]
        XCTAssertEqual(
            EventList.sorted(events, by: .dateAsc, now: now, calendar: calendar).map(\.id),
            ["pasado", "cerca", "cumple", "lejos"]
        )
        XCTAssertEqual(
            EventList.sorted(events, by: .dateDesc, now: now, calendar: calendar).map(\.id),
            ["lejos", "cumple", "cerca", "pasado"]
        )
    }

    func testOrdenPorNombreIgnoraMayusculasYAcentos() {
        let events = [
            event("1", "2027-01-01", name: "zapatos"),
            event("2", "2027-01-01", name: "Ópera"),
            event("3", "2027-01-01", name: "ana"),
            event("4", "2027-01-01", name: "Navidad"),
        ]
        XCTAssertEqual(EventList.sorted(events, by: .name).map(\.name), ["ana", "Navidad", "Ópera", "zapatos"])
    }

    func testOrdenPorCreacion() {
        // El segundo tramo del id es el momento de creación en base 36.
        let events = [
            event("evt_\(String(1_000, radix: 36))_aaaaaa", "2027-01-01"),
            event("evt_\(String(3_000, radix: 36))_bbbbbb", "2027-01-01"),
            event("sin-formato", "2027-01-01"),
            event("evt_\(String(2_000, radix: 36))_cccccc", "2027-01-01"),
        ]
        XCTAssertEqual(
            EventList.sorted(events, by: .created).map { EventList.creationStamp($0.id) },
            [3_000, 2_000, 1_000, 0]
        )
    }

    func testValoresDeOrdenIgualesALosDeLaWeb() {
        XCTAssertEqual(SortMode.allCases.map(\.rawValue), ["date-asc", "date-desc", "name", "created"])
        XCTAssertEqual(SortMode.dateAsc.label, "Próximos primero")
    }

    // MARK: - Filtro

    func testFiltroPorCategoriaYTexto() {
        let events = [
            event("1", "2027-01-01", name: "Viaje a Japón", category: "travel"),
            event("2", "2027-01-01", name: "Viaje a Lisboa", category: "travel"),
            event("3", "2027-01-01", name: "Cumple de Ana", category: "birthday"),
        ]
        XCTAssertEqual(EventList.filtered(events).count, 3)
        XCTAssertEqual(EventList.filtered(events, category: "travel").map(\.id), ["1", "2"])
        XCTAssertEqual(EventList.filtered(events, query: "  japon ").map(\.id), ["1"], "sin acentos ni mayúsculas")
        XCTAssertEqual(EventList.filtered(events, category: "birthday", query: "viaje").count, 0)
        XCTAssertEqual(EventList.filtered(events, category: "travel", query: "LIS").map(\.id), ["2"])
    }

    func testCategoriasEnUso() {
        let events = [
            event("1", "2027-01-01", category: "travel"),
            event("2", "2027-01-01", category: "birthday"),
            event("3", "2027-01-01", category: "no-existe"), // cuenta como "Otros"
        ]
        XCTAssertEqual(EventList.categoriesInUse(events).map(\.id), ["birthday", "travel", "other"])
    }

    // MARK: - Importar el archivo de la web

    private let exportJSON = """
    {
      "version": 1,
      "app": "next-appointment",
      "events": [
        { "id": "evt_1", "name": "Viaje a Japón", "date": "2026-09-01", "time": "08:00", "emoji": "✈️",
          "color": "#0984e3", "category": "travel", "recurrenceUnit": "none", "recurrenceInterval": 1,
          "recurrenceEndDate": null, "recurrenceMaxCount": null, "notifyBefore": 3600 },
        { "id": "evt_2", "name": "Cumple", "date": "1990-05-20", "recurrence": "yearly" },
        { "id": "evt_3", "name": "Aniversario", "date": "2015-06-06", "recurring": true },
        { "id": "evt_4", "date": "2026-01-01" },
        { "id": "evt_1", "name": "Repetido en el archivo", "date": "2026-01-01" },
        "esto no es un evento"
      ]
    }
    """

    func testLeeElArchivoDeExportacion() throws {
        let events = try EventImport.parse(Data(exportJSON.utf8))
        XCTAssertEqual(events.map(\.id), ["evt_1", "evt_2", "evt_3"], "sin nombre, repetidos e ilegibles fuera")
        XCTAssertEqual(events[0].name, "Viaje a Japón")
        XCTAssertEqual(events[0].notifyBefore, 3600)
        XCTAssertEqual(events[1].recurrenceUnit, .year, "formato intermedio de recurrencia")
        XCTAssertEqual(events[2].recurrenceUnit, .year, "formato más antiguo de recurrencia")
    }

    func testLoImportadoEntraActivoYSinCelebrar() throws {
        let json = """
        { "app": "next-appointment", "events": [
          { "id": "a", "name": "A", "date": "2020-01-01", "archivedAt": 1700000000000, "_celebrated": true } ] }
        """
        let events = try EventImport.parse(Data(json.utf8))
        XCTAssertNil(events[0].archivedAt)
        XCTAssertFalse(events[0].celebrated)
    }

    func testRechazaArchivosQueNoSonDeLaApp() {
        for text in ["no es json", #"{ "app": "otra-app", "events": [] }"#, #"{ "events": [] }"#, #"{ "app": "next-appointment" }"#] {
            XCTAssertThrowsError(try EventImport.parse(Data(text.utf8))) { error in
                XCTAssertEqual(error as? EventImport.ImportError, .notAnExportFile)
            }
        }
    }

    func testPlanDeImportacionOmiteDuplicadosPorId() throws {
        let incoming = try EventImport.parse(Data(exportJSON.utf8))
        let plan = EventImport.plan(incoming: incoming, existingIds: ["evt_2", "otro"])
        XCTAssertEqual(plan.total, 3)
        XCTAssertEqual(plan.newEvents.map(\.id), ["evt_1", "evt_3"])
        XCTAssertEqual(plan.skipped, 1)
        XCTAssertEqual(plan.summary, "El archivo contiene 3 eventos. Se añadirán 2 nuevos. Se omitirán 1 ya existente.")

        let todoRepetido = EventImport.plan(incoming: incoming, existingIds: ["evt_1", "evt_2", "evt_3"])
        XCTAssertEqual(todoRepetido.summary, "El archivo contiene 3 eventos. Se omitirán 3 ya existentes.")

        let uno = EventImport.plan(incoming: [incoming[0]], existingIds: [])
        XCTAssertEqual(uno.summary, "El archivo contiene 1 evento. Se añadirán 1 nuevo.")
    }

    func testMensajeDeResultado() {
        XCTAssertEqual(EventImport.resultMessage(imported: 1), "✅ 1 evento importado correctamente.")
        XCTAssertEqual(EventImport.resultMessage(imported: 3), "✅ 3 eventos importados correctamente.")
    }

    func testElArchivoPropioDeLaAppTambienSeImporta() throws {
        let original = [event("a", "2027-01-01", name: "Uno"), event("b", "2027-02-01", name: "Dos", unit: .month)]
        let data = try JSONEncoder().encode(EventFile(events: original))
        XCTAssertEqual(try EventImport.parse(data), original)
    }
}
