import SwiftUI

/// Formulario para crear o editar un evento. Lo básico (nombre, fecha y hora)
/// está a la vista; "Más opciones" despliega icono, color, categoría,
/// repetición y aviso.
struct EventFormView: View {
    @Environment(EventStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Event?
    @State private var draft: EventDraft
    @State private var showAdvanced: Bool
    @State private var alertMessage: String?
    @State private var dismissAfterAlert = false
    @State private var confirmDelete = false
    @FocusState private var nameFocused: Bool

    init(event: Event?) {
        existing = event
        let draft = event.map { EventDraft(event: $0) } ?? EventDraft()
        _draft = State(initialValue: draft)
        // Al editar, las opciones se despliegan si hay algo configurado.
        _showAdvanced = State(initialValue: event != nil && draft.hasNonDefaultOptions)
    }

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                advancedToggleSection
                if showAdvanced {
                    appearanceSection
                    categorySection
                    repeatSection
                    notifySection
                }
                previewSection
                if existing != nil {
                    deleteSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(existing == nil ? "Nuevo evento" : "Editar evento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(draft.trimmedName.isEmpty)
                }
            }
            .alert("Aviso", isPresented: alertBinding) {
                Button("Entendido") {
                    if dismissAfterAlert { dismiss() }
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .confirmationDialog("¿Eliminar este evento?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { delete() }
                Button("Cancelar", role: .cancel) {}
            }
            .onAppear {
                if existing == nil { nameFocused = true }
            }
        }
        .tint(Theme.brand)
    }

    // MARK: - Secciones

    private var basicSection: some View {
        Section {
            TextField("Ej: Viaje a Japón", text: $draft.name)
                .focused($nameFocused)
                .submitLabel(.done)
                .onChange(of: draft.name) { _, newValue in
                    if newValue.count > Event.maxNameLength {
                        draft.name = String(newValue.prefix(Event.maxNameLength))
                    }
                }
            DatePicker("Fecha", selection: $draft.when, displayedComponents: .date)
            DatePicker("Hora", selection: $draft.when, displayedComponents: .hourAndMinute)
        } header: {
            Text("Nombre del evento")
        }
        .listRowBackground(Theme.card)
    }

    private var advancedToggleSection: some View {
        Section {
            Button {
                nameFocused = false
                withAnimation { showAdvanced.toggle() }
            } label: {
                HStack {
                    Label("Más opciones", systemImage: "slider.horizontal.3")
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(showAdvanced ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } footer: {
            if !showAdvanced {
                Text("\(summary) — puedes cambiarlo luego editando el evento.")
            }
        }
        .listRowBackground(Theme.card)
    }

    private var appearanceSection: some View {
        Group {
            Section("Icono") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 8) {
                    ForEach(Catalog.emojis, id: \.self) { emoji in
                        Button {
                            draft.emoji = emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(
                                    draft.emoji == emoji ? Theme.brand.opacity(0.18) : Theme.background,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(draft.emoji == emoji ? Theme.brand : .clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Icono \(emoji)")
                        .accessibilityAddTraits(draft.emoji == emoji ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.card)

            Section("Color de acento") {
                HStack(spacing: 0) {
                    ForEach(Catalog.colors, id: \.self) { hex in
                        Button {
                            draft.color = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if draft.color == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(3)
                                .overlay(
                                    Circle().strokeBorder(draft.color == hex ? Color(hex: hex) : .clear, lineWidth: 2)
                                )
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(hex)")
                        .accessibilityAddTraits(draft.color == hex ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.card)
        }
    }

    private var categorySection: some View {
        Section("Categoría") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(Catalog.categories) { category in
                    let selected = draft.category == category.id
                    Button {
                        draft.category = category.id
                    } label: {
                        Text("\(category.emoji) \(category.label)")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(selected ? Theme.brand : Theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                selected ? Theme.brand.opacity(0.14) : Theme.background,
                                in: Capsule()
                            )
                            .overlay(Capsule().strokeBorder(selected ? Theme.brand : Theme.border, lineWidth: selected ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Theme.card)
    }

    private var repeatSection: some View {
        Section {
            Toggle("Repetir este evento", isOn: $draft.repeats.animation())
            if draft.repeats {
                Stepper(value: $draft.interval, in: 1...999) {
                    Text("Cada \(draft.interval) \(unitName(draft.unit, count: draft.interval))")
                }
                Picker("Unidad", selection: $draft.unit) {
                    Text("Días").tag(RecurrenceUnit.day)
                    Text("Semanas").tag(RecurrenceUnit.week)
                    Text("Meses").tag(RecurrenceUnit.month)
                    Text("Años").tag(RecurrenceUnit.year)
                }
                .pickerStyle(.segmented)

                Toggle("Repetir hasta una fecha", isOn: $draft.hasEndDate.animation())
                if draft.hasEndDate {
                    DatePicker("Hasta", selection: $draft.endDate, displayedComponents: .date)
                }
                Toggle("Limitar el número de veces", isOn: $draft.hasMaxCount.animation())
                if draft.hasMaxCount {
                    Stepper(value: $draft.maxCount, in: 1...9_999) {
                        Text("\(draft.maxCount) \(draft.maxCount == 1 ? "vez" : "veces")")
                    }
                }
            }
        } header: {
            Text("Repetición")
        } footer: {
            if draft.repeats {
                Text("Ej: cada 2 semanas, cada 3 días, cada 1 año (cumpleaños, aniversarios...). Sin límites, se repite indefinidamente.")
            }
        }
        .listRowBackground(Theme.card)
    }

    private var notifySection: some View {
        Section {
            Toggle("Avisarme antes", isOn: $draft.notifies.animation())
            if draft.notifies {
                HStack(spacing: 0) {
                    wheel($draft.notifyDays, 0...365) { "\($0) \($0 == 1 ? "día" : "días")" }
                    wheel($draft.notifyHours, 0...23) { "\($0) \($0 == 1 ? "hora" : "horas")" }
                    wheel($draft.notifyMinutes, 0...59) { "\($0) min" }
                }
                .frame(height: 120)
            }
        } header: {
            Text("Aviso")
        } footer: {
            if draft.notifies {
                Text(
                    draft.notifyBefore == nil
                        ? "Con todo a 0 no se avisa."
                        : "Recibirás una notificación en este iPhone \(noticeText) antes del evento."
                )
            }
        }
        .listRowBackground(Theme.card)
    }

    private var previewSection: some View {
        Section("Vista previa") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let preview = draft.makeEvent(editing: existing)
                let accent = Theme.accent(preview.color)
                VStack(spacing: 10) {
                    Text(preview.emoji)
                        .font(.system(size: 44))
                    Text(preview.name.isEmpty ? "Nombre del evento" : preview.name)
                        .font(.headline)
                        .foregroundStyle(preview.name.isEmpty ? Theme.muted : Theme.text)
                        .multilineTextAlignment(.center)
                    if Countdown.hasElapsed(preview, now: context.date) {
                        Text("🎉 ¡Ya llegó el día!")
                            .font(.headline)
                            .foregroundStyle(accent)
                    } else {
                        CountdownUnitsView(
                            breakdown: Countdown.breakdown(Countdown.remaining(preview, now: context.date)),
                            accent: accent,
                            compact: true
                        )
                    }
                    Text(Countdown.formatDate(preview, now: context.date))
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                    if preview.recurrence.unit != .none {
                        Text("🔁 \(Countdown.recurrenceLabel(preview.recurrence))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .listRowBackground(Theme.card)
    }

    private var deleteSection: some View {
        Section {
            Button("Eliminar evento", role: .destructive) {
                confirmDelete = true
            }
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Theme.card)
    }

    // MARK: - Piezas

    private func wheel(_ value: Binding<Int>, _ range: ClosedRange<Int>, label: @escaping (Int) -> String) -> some View {
        Picker("", selection: value) {
            ForEach(range, id: \.self) { number in
                Text(label(number)).tag(number)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func unitName(_ unit: RecurrenceUnit, count: Int) -> String {
        switch unit {
        case .none: ""
        case .day: count == 1 ? "día" : "días"
        case .week: count == 1 ? "semana" : "semanas"
        case .month: count == 1 ? "mes" : "meses"
        case .year: count == 1 ? "año" : "años"
        }
    }

    /// Resumen de las opciones cuando están plegadas: "Icono ⏳ · Categoría Otros · ...".
    private var summary: String {
        let preview = draft.makeEvent(editing: existing)
        let recurrence = Countdown.recurrenceLabel(preview.recurrence)
        return [
            "Icono \(draft.emoji)",
            "Categoría \(Catalog.category(id: draft.category).label)",
            recurrence.isEmpty ? "Sin repetición" : recurrence,
            draft.notifyBefore == nil ? "Sin aviso" : "Aviso \(noticeText) antes",
        ].joined(separator: " · ")
    }

    /// Antelación del aviso en palabras: "1 día y 2 horas".
    private var noticeText: String {
        var parts: [String] = []
        if draft.notifyDays > 0 { parts.append("\(draft.notifyDays) \(draft.notifyDays == 1 ? "día" : "días")") }
        if draft.notifyHours > 0 { parts.append("\(draft.notifyHours) \(draft.notifyHours == 1 ? "hora" : "horas")") }
        if draft.notifyMinutes > 0 { parts.append("\(draft.notifyMinutes) min") }
        return ListFormatter.localizedString(byJoining: parts)
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }

    // MARK: - Acciones

    private func save() {
        guard !draft.trimmedName.isEmpty else { return }
        guard draft.endDateIsValid() else {
            dismissAfterAlert = false
            alertMessage = "La fecha de fin de la repetición no puede ser anterior a la fecha del evento."
            return
        }

        let event = draft.makeEvent(editing: existing)
        store.upsert(event)

        Task {
            if event.notifyBefore != nil {
                // Si deniega el permiso, el evento se guarda igual, sin aviso.
                guard await NotificationScheduler.requestAuthorization() else {
                    dismissAfterAlert = true
                    alertMessage = "Para recibir avisos, permite las notificaciones de la app en Ajustes. El evento se ha guardado sin aviso activo."
                    return
                }
            }
            await NotificationScheduler.schedule(event)
            dismiss()
        }
    }

    private func delete() {
        guard let existing else { return }
        NotificationScheduler.cancel(id: existing.id)
        store.delete(id: existing.id)
        dismiss()
    }
}
