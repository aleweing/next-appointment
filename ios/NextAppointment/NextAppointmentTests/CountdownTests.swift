import XCTest

/// Tests de la lógica de recurrencia portada de `js/countdown.js`.
/// Usan un calendario fijo (gregoriano, Europe/Madrid) para no depender del Mac.
final class CountdownTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        calendar.locale = Locale(identifier: "es_ES")
        return calendar
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute, second: second
        ))!
    }

    private func event(
        _ date: String, _ time: String = "00:00",
        unit: RecurrenceUnit = .none, interval: Int = 1,
        endDate: String? = nil, maxCount: Int? = nil
    ) -> Event {
        Event(
            id: "evt_test", name: "Prueba", date: date, time: time,
            recurrenceUnit: unit, recurrenceInterval: interval,
            recurrenceEndDate: endDate, recurrenceMaxCount: maxCount
        )
    }

    private func target(_ event: Event, _ now: Date) -> Date {
        Countdown.targetDate(event, now: now, calendar: calendar)
    }

    private func elapsed(_ event: Event, _ now: Date) -> Bool {
        Countdown.hasElapsed(event, now: now, calendar: calendar)
    }

    private func last(_ event: Event) -> Date? {
        Countdown.lastOccurrence(event, calendar: calendar)
    }

    // MARK: - Evento único

    func testEventoUnicoFuturo() {
        let e = event("2026-12-25", "08:00")
        let now = at(2026, 11, 15, 10, 0)
        XCTAssertEqual(target(e, now), at(2026, 12, 25, 8, 0))
        XCTAssertFalse(elapsed(e, now))
        XCTAssertNil(last(e))
        XCTAssertEqual(Countdown.shortLabel(e, now: now, calendar: calendar), "39d 22h")
    }

    func testEventoUnicoPasado() {
        let e = event("2026-11-01", "08:00")
        let now = at(2026, 11, 15, 10, 0)
        XCTAssertEqual(target(e, now), at(2026, 11, 1, 8, 0), "el ancla no se mueve")
        XCTAssertTrue(elapsed(e, now))
        XCTAssertLessThan(Countdown.remaining(e, now: now, calendar: calendar), 0)
        XCTAssertEqual(Countdown.shortLabel(e, now: now, calendar: calendar), "¡Ya llegó! 🎉")
    }

    func testEventoUnicoLlegaEnElInstanteExacto() {
        let e = event("2026-11-15", "10:00")
        XCTAssertFalse(elapsed(e, at(2026, 11, 15, 9, 59, 59)))
        XCTAssertTrue(elapsed(e, at(2026, 11, 15, 10, 0, 0)))
    }

    func testSinHoraEsMedianoche() {
        var e = event("2026-12-25")
        e.time = ""
        XCTAssertEqual(Countdown.anchorDate(e, calendar: calendar), at(2026, 12, 25, 0, 0))
    }

    // MARK: - Series indefinidas

    func testAnualConAnclaDeHaceAnios() {
        let cumple = event("1990-05-20", unit: .year)
        XCTAssertEqual(target(cumple, at(2026, 11, 15, 10, 0)), at(2027, 5, 20))
        XCTAssertEqual(target(cumple, at(2027, 5, 19, 23, 59, 59)), at(2027, 5, 20))
        // En el instante exacto la serie ya apunta al año siguiente.
        XCTAssertEqual(target(cumple, at(2027, 5, 20)), at(2028, 5, 20))
        XCTAssertFalse(elapsed(cumple, at(2026, 11, 15)), "una serie indefinida nunca llega")
        XCTAssertNil(last(cumple))
        XCTAssertFalse(Countdown.isRecurrenceFinished(cumple, now: at(2090, 1, 1), calendar: calendar))
    }

    func testAnualAntesDeLaPrimeraOcurrencia() {
        let e = event("2030-01-01", "12:00", unit: .year)
        XCTAssertEqual(target(e, at(2026, 11, 15)), at(2030, 1, 1, 12, 0))
    }

    func testCadaTresDias() {
        let e = event("2026-11-01", "09:00", unit: .day, interval: 3)
        // Ocurrencias: 1, 4, 7, 10, 13, 16, 19...
        XCTAssertEqual(target(e, at(2026, 11, 15, 10, 0)), at(2026, 11, 16, 9, 0))
        XCTAssertEqual(target(e, at(2026, 11, 16, 8, 59)), at(2026, 11, 16, 9, 0))
        XCTAssertEqual(target(e, at(2026, 11, 16, 9, 0)), at(2026, 11, 19, 9, 0))
    }

    func testCadaDosSemanas() {
        let e = event("2026-11-02", "18:30", unit: .week, interval: 2)
        XCTAssertEqual(target(e, at(2026, 11, 15)), at(2026, 11, 16, 18, 30))
        XCTAssertEqual(target(e, at(2026, 11, 17)), at(2026, 11, 30, 18, 30))
    }

    func testMensualDesdeUnDia31() {
        let e = event("2026-01-31", "08:00", unit: .month)
        XCTAssertEqual(target(e, at(2026, 2, 10)), at(2026, 2, 28, 8, 0), "febrero no tiene 31")
        // Diferencia conocida con la web: aquí la serie vuelve al 31, no se queda en el 28.
        XCTAssertEqual(target(e, at(2026, 3, 1)), at(2026, 3, 31, 8, 0))
        XCTAssertEqual(target(e, at(2026, 4, 1)), at(2026, 4, 30, 8, 0))
        XCTAssertEqual(target(e, at(2028, 2, 1)), at(2028, 2, 29, 8, 0), "año bisiesto")
    }

    func testAnualDesdeUn29DeFebrero() {
        let e = event("2024-02-29", unit: .year)
        XCTAssertEqual(target(e, at(2025, 1, 1)), at(2025, 2, 28))
        XCTAssertEqual(target(e, at(2027, 6, 1)), at(2028, 2, 29))
    }

    func testDiarioEnElCambioDeHoraNoSeDesplaza() {
        // El 29-mar-2026 a las 02:30 no existe en Madrid (el reloj salta de 02:00 a 03:00).
        let e = event("2026-03-27", "02:30", unit: .day)
        XCTAssertEqual(target(e, at(2026, 3, 28, 12, 0)), at(2026, 3, 29, 3, 30))
        XCTAssertEqual(target(e, at(2026, 3, 29, 12, 0)), at(2026, 3, 30, 2, 30), "vuelve a las 02:30")
    }

    func testAvanzarUnaOcurrencia() {
        let start = at(2026, 11, 15, 9, 0)
        XCTAssertEqual(Countdown.advance(start, unit: .day, interval: 3, calendar: calendar), at(2026, 11, 18, 9, 0))
        XCTAssertEqual(Countdown.advance(start, unit: .week, interval: 2, calendar: calendar), at(2026, 11, 29, 9, 0))
        XCTAssertEqual(Countdown.advance(start, unit: .month, interval: 1, calendar: calendar), at(2026, 12, 15, 9, 0))
        XCTAssertEqual(Countdown.advance(start, unit: .year, interval: 2, calendar: calendar), at(2028, 11, 15, 9, 0))
        XCTAssertEqual(Countdown.advance(start, unit: .none, calendar: calendar), start)
    }

    func testAtajoDaElMismoResultadoQueAvanzarDeUnoEnUno() {
        // Serie diaria con más de diez años de historia: el cálculo rápido tiene
        // que coincidir con el bucle de la web (avanzar mientras sea <= ahora).
        let e = event("2015-03-10", "07:15", unit: .day)
        let weekly = event("2015-03-10", "07:15", unit: .week, interval: 3)
        for now in [at(2026, 11, 15, 7, 14), at(2026, 11, 15, 7, 15), at(2026, 11, 15, 7, 16), at(2020, 2, 29), at(2015, 3, 9)] {
            for sample in [e, weekly] {
                var expected = Countdown.anchorDate(sample, calendar: calendar)
                while expected <= now {
                    expected = Countdown.advance(
                        expected, unit: sample.recurrenceUnit, interval: sample.recurrenceInterval, calendar: calendar
                    )
                }
                XCTAssertEqual(target(sample, now), expected)
            }
        }
    }

    // MARK: - Series limitadas

    func testSerieConFechaDeFin() {
        // Semanal desde el lunes 2-nov hasta el 30-nov: 2, 9, 16, 23 y 30.
        let e = event("2026-11-02", "18:00", unit: .week, endDate: "2026-11-30")
        XCTAssertEqual(last(e), at(2026, 11, 30, 18, 0), "el día de fin está incluido")
        XCTAssertEqual(target(e, at(2026, 11, 15)), at(2026, 11, 16, 18, 0))
        XCTAssertFalse(elapsed(e, at(2026, 11, 30, 17, 0)))
        XCTAssertFalse(elapsed(e, at(2026, 11, 30, 18, 0)), "en el instante exacto aún no ha terminado")
        XCTAssertTrue(elapsed(e, at(2026, 11, 30, 18, 0, 1)))
    }

    func testFechaDeFinIncluyeHastaLas235959() {
        let e = event("2026-11-10", "23:30", unit: .day, endDate: "2026-11-12")
        XCTAssertEqual(last(e), at(2026, 11, 12, 23, 30))
    }

    func testFechaDeFinQueNoCoincideConUnaOcurrencia() {
        let e = event("2026-11-02", "18:00", unit: .week, endDate: "2026-11-29")
        XCTAssertEqual(last(e), at(2026, 11, 23, 18, 0))
    }

    func testFechaDeFinAnteriorAlAncla() {
        let e = event("2026-11-10", "08:00", unit: .day, endDate: "2026-11-01")
        XCTAssertEqual(last(e), at(2026, 11, 10, 8, 0), "la primera ocurrencia siempre existe")
    }

    func testSerieConMaximoDeRepeticiones() {
        // Diario desde el 10-nov, 5 veces: 10, 11, 12, 13 y 14.
        let e = event("2026-11-10", "08:00", unit: .day, maxCount: 5)
        XCTAssertEqual(last(e), at(2026, 11, 14, 8, 0))
        XCTAssertEqual(target(e, at(2026, 11, 12, 9, 0)), at(2026, 11, 13, 8, 0))
        XCTAssertFalse(elapsed(e, at(2026, 11, 14, 8, 0)))
        XCTAssertTrue(elapsed(e, at(2026, 11, 14, 8, 0, 1)))
    }

    func testUnaSolaRepeticion() {
        let e = event("2026-11-10", "08:00", unit: .year, maxCount: 1)
        XCTAssertEqual(last(e), at(2026, 11, 10, 8, 0))
        XCTAssertTrue(elapsed(e, at(2026, 11, 11)))
    }

    func testMaximoDeRepeticionesEnMeses() {
        let e = event("2026-01-31", "08:00", unit: .month, maxCount: 4)
        XCTAssertEqual(last(e), at(2026, 4, 30, 8, 0))
    }

    func testSerieConLosDosLimites() {
        // Gana la fecha de fin: 10 repeticiones llegarían al 19, pero termina el 14.
        let ganaFecha = event("2026-11-10", "08:00", unit: .day, endDate: "2026-11-14", maxCount: 10)
        XCTAssertEqual(last(ganaFecha), at(2026, 11, 14, 8, 0))
        // Gana el máximo: 3 repeticiones terminan el 12, antes de la fecha de fin.
        let ganaMaximo = event("2026-11-10", "08:00", unit: .day, endDate: "2026-11-30", maxCount: 3)
        XCTAssertEqual(last(ganaMaximo), at(2026, 11, 12, 8, 0))
    }

    func testSerieYaTerminada() {
        let e = event("2026-01-05", "09:00", unit: .week, maxCount: 3) // 5, 12 y 19 de enero
        let now = at(2026, 11, 15)
        XCTAssertTrue(Countdown.isRecurrenceFinished(e, now: now, calendar: calendar))
        XCTAssertTrue(elapsed(e, now))
        XCTAssertEqual(target(e, now), at(2026, 1, 19, 9, 0), "no pasa de la última ocurrencia")
        XCTAssertEqual(Countdown.shortLabel(e, now: now, calendar: calendar), "¡Ya llegó! 🎉")
    }

    func testSerieLimitadaAunSinTerminar() {
        let e = event("2026-01-05", "09:00", unit: .month, endDate: "2027-12-31")
        let now = at(2026, 11, 15)
        XCTAssertFalse(elapsed(e, now))
        XCTAssertEqual(target(e, now), at(2026, 12, 5, 9, 0))
        XCTAssertEqual(last(e), at(2027, 12, 5, 9, 0))
    }

    func testLimitesIgnoradosSiNoRepite() {
        let e = event("2026-11-10", "08:00", unit: .none, endDate: "2026-11-30", maxCount: 5)
        XCTAssertNil(last(e))
        XCTAssertFalse(Countdown.isRecurrenceFinished(e, now: at(2027, 1, 1), calendar: calendar))
    }

    // MARK: - Textos

    func testDesglose() {
        XCTAssertEqual(Countdown.breakdown(0), .init(days: 0, hours: 0, minutes: 0, seconds: 0))
        XCTAssertEqual(Countdown.breakdown(-50), .init(days: 0, hours: 0, minutes: 0, seconds: 0))
        XCTAssertEqual(Countdown.breakdown(59.9), .init(days: 0, hours: 0, minutes: 0, seconds: 59))
        XCTAssertEqual(
            Countdown.breakdown(2 * 86_400 + 3 * 3_600 + 4 * 60 + 5),
            .init(days: 2, hours: 3, minutes: 4, seconds: 5)
        )
    }

    func testTextoCorto() {
        XCTAssertEqual(Countdown.shortLabel(remaining: 12 * 86_400 + 4 * 3_600 + 30 * 60), "12d 04h")
        XCTAssertEqual(Countdown.shortLabel(remaining: 3 * 3_600 + 7 * 60 + 59), "3h 07m")
        XCTAssertEqual(Countdown.shortLabel(remaining: 15 * 60 + 20), "15m")
        XCTAssertEqual(Countdown.shortLabel(remaining: 30), "0m")
    }

    func testFechaLegible() {
        let conHora = event("2027-04-01", "08:00")
        XCTAssertEqual(
            Countdown.formatDate(conHora, now: at(2026, 11, 15), calendar: calendar),
            "Jueves, 1 de abril de 2027 · 08:00"
        )
        let sinHora = event("2027-04-01")
        XCTAssertEqual(
            Countdown.formatDate(sinHora, now: at(2026, 11, 15), calendar: calendar),
            "Jueves, 1 de abril de 2027"
        )
    }

    func testFechaLegibleDeUnaSerieMuestraLaProximaOcurrencia() {
        let cumple = event("1990-05-20", unit: .year)
        XCTAssertEqual(
            Countdown.formatDate(cumple, now: at(2026, 11, 15), calendar: calendar),
            "Jueves, 20 de mayo de 2027"
        )
    }

    func testEtiquetaDeRecurrencia() {
        func label(_ unit: RecurrenceUnit, _ interval: Int = 1, end: String? = nil, max: Int? = nil) -> String {
            Countdown.recurrenceLabel(
                Recurrence(unit: unit, interval: interval, endDate: end, maxCount: max), calendar: calendar
            )
        }
        XCTAssertEqual(label(.none), "")
        XCTAssertEqual(label(.day), "Diario")
        XCTAssertEqual(label(.week), "Semanal")
        XCTAssertEqual(label(.month), "Mensual")
        XCTAssertEqual(label(.year), "Anual")
        XCTAssertEqual(label(.day, 3), "Cada 3 días")
        XCTAssertEqual(label(.week, 2), "Cada 2 semanas")
        XCTAssertEqual(label(.month, 6), "Cada 6 meses")
        XCTAssertEqual(label(.year, 2), "Cada 2 años")
        XCTAssertEqual(label(.year, max: 5), "Anual · 5 reps")
        XCTAssertEqual(label(.year, max: 1), "Anual · 1 rep")
        XCTAssertEqual(label(.week, end: "2026-11-30"), "Semanal · hasta 30 nov")
        XCTAssertEqual(label(.day, 3, end: "2026-11-30", max: 5), "Cada 3 días · 5 reps · hasta 30 nov")
    }

    func testFechasEnTexto() {
        let date = at(2026, 3, 5, 7, 9)
        XCTAssertEqual(Countdown.dayString(date, calendar: calendar), "2026-03-05")
        XCTAssertEqual(Countdown.timeString(date, calendar: calendar), "07:09")
        XCTAssertNil(Countdown.localDate(day: "no-es-fecha", time: "00:00", second: 0, calendar: calendar))
        XCTAssertNil(Countdown.localDate(day: "2026-13-01", time: "00:00", second: 0, calendar: calendar))
    }
}
