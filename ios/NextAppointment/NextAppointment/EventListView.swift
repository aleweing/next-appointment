import SwiftUI
import UniformTypeIdentifiers

/// Lista "Mis eventos": todos los eventos activos, con búsqueda por nombre,
/// filtro por categoría, orden, acceso a los archivados e importación.
struct EventListView: View {
    @Environment(EventStore.self) private var store
    @AppStorage("next-appointment:sort") private var sortRaw = SortMode.dateAsc.rawValue
    @State private var query = ""
    @State private var category: String?
    @State private var editor: EditorTarget?
    @State private var showArchived = false
    @State private var showImporter = false
    @State private var importAlert: ImportAlert?
    @State private var didRunDebugImport = false

    private var sort: SortMode { SortMode(rawValue: sortRaw) ?? .dateAsc }

    var body: some View {
        let all = store.activeEvents
        let categories = EventList.categoriesInUse(all)
        let events = EventList.sorted(EventList.filtered(all, category: category, query: query), by: sort)

        List {
            if !all.isEmpty {
                categoryBar(categories)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            if !events.isEmpty {
                Section {
                    ForEach(events) { event in
                        Button {
                            editor = .edit(event)
                        } label: {
                            EventRowView(event: event)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                delete(event)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .tint(.red) // el tinte de marca de la app taparía el rojo
                        }
                    }
                } header: {
                    Text("\(events.count) \(events.count == 1 ? "evento" : "eventos") · \(sort.label)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .environment(\.defaultMinListHeaderHeight, 0)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if events.isEmpty {
                emptyState(hasEvents: !all.isEmpty)
                    .padding(.top, all.isEmpty ? 0 : 60) // deja a la vista los chips de categoría
            }
        }
        .navigationTitle("Mis eventos")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar evento...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Ordenar", selection: $sortRaw) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                    Divider()
                    Button {
                        showArchived = true
                    } label: {
                        Label("Archivados", systemImage: "archivebox")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Importar eventos…", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label("Más opciones", systemImage: "ellipsis")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = .new
                } label: {
                    Label("Crear evento", systemImage: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showArchived) {
            ArchivedView()
        }
        .sheet(item: $editor) { target in
            EventFormView(event: target.event)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert(
            importAlert?.title ?? "", isPresented: importAlertBinding, presenting: importAlert
        ) { alert in
            switch alert {
            case .confirm(let plan) where !plan.newEvents.isEmpty:
                Button("Importar") { applyImport(plan) }
                Button("Cancelar", role: .cancel) {}
            default:
                Button("Entendido", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        .task {
            #if DEBUG
            // Para pruebas: `-import-file <ruta>` importa ese archivo sin pasar por el selector.
            if !didRunDebugImport, let path = UserDefaults.standard.string(forKey: "import-file") {
                didRunDebugImport = true
                handleImport(.success(URL(fileURLWithPath: path)))
            }
            #endif
        }
        .onChange(of: categories) { _, newValue in
            // Si la categoría elegida se queda sin eventos, se vuelve a "Todas".
            if let category, !newValue.contains(where: { $0.id == category }) {
                self.category = nil
            }
        }
    }

    // MARK: - Categorías

    private func categoryBar(_ categories: [EventCategory]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                categoryChip("Todas", selected: category == nil) { category = nil }
                ForEach(categories) { item in
                    categoryChip("\(item.emoji) \(item.label)", selected: category == item.id) {
                        category = item.id
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
    }

    private func categoryChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(selected ? .white : Theme.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.brand : Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Theme.brand : Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Estados vacíos

    @ViewBuilder
    private func emptyState(hasEvents: Bool) -> some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if hasEvents, !trimmed.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "Sin resultados",
                subtitle: "Nada coincide con \"\(trimmed)\"."
            )
        } else if hasEvents, let category {
            EmptyStateView(
                systemImage: "tray",
                title: "Nada por aquí",
                subtitle: "No tienes eventos en \"\(Catalog.category(id: category).label)\" todavía.",
                actionTitle: "Ver todas las categorías"
            ) {
                self.category = nil
            }
        } else {
            EmptyStateView(
                title: "Nada en el horizonte todavía",
                subtitle: "No hay eventos creados todavía.",
                actionTitle: "Crear evento"
            ) {
                editor = .new
            }
        }
    }

    // MARK: - Importar

    private enum ImportAlert {
        case confirm(EventImport.Plan)
        case result(String)
        case failure

        var title: String {
            switch self {
            case .confirm: "Importar eventos"
            case .result: "Importación terminada"
            case .failure: "No se pudo importar"
            }
        }

        var message: String {
            switch self {
            case .confirm(let plan): plan.summary
            case .result(let text): text
            case .failure: "El archivo no parece una exportación de Next Appointment."
            }
        }
    }

    private var importAlertBinding: Binding<Bool> {
        Binding(get: { importAlert != nil }, set: { if !$0 { importAlert = nil } })
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return } // cancelado
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let incoming = try EventImport.parse(Data(contentsOf: url))
            importAlert = .confirm(
                EventImport.plan(incoming: incoming, existingIds: Set(store.events.map(\.id)))
            )
        } catch {
            importAlert = .failure
        }
    }

    private func applyImport(_ plan: EventImport.Plan) {
        let count = store.importEvents(plan.newEvents)
        let imported = plan.newEvents
        Task {
            await NotificationScheduler.rescheduleAll(imported)
            // Deja que se cierre la alerta de confirmación antes de mostrar el resultado.
            try? await Task.sleep(for: .milliseconds(400))
            importAlert = .result(EventImport.resultMessage(imported: count))
        }
    }

    private func delete(_ event: Event) {
        NotificationScheduler.cancel(id: event.id)
        withAnimation {
            store.delete(id: event.id)
        }
    }
}

/// Fila de la lista: emoji, nombre, categoría, fecha y cuenta atrás corta.
struct EventRowView: View {
    let event: Event

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            row(now: context.date)
        }
    }

    private func row(now: Date) -> some View {
        let category = Catalog.category(id: event.category)
        let recurrence = event.recurrence
        let accent = Theme.accent(event.color)

        return HStack(spacing: 14) {
            Text(event.emoji)
                .font(.system(size: 30))
                .frame(width: 50, height: 50)
                .background(Color(hex: event.color).opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text(
                    recurrence.unit != .none
                        ? "\(category.emoji) \(category.label) · 🔁 \(Countdown.recurrenceLabel(recurrence))"
                        : "\(category.emoji) \(category.label)"
                )
                .font(.caption)
                .foregroundStyle(Theme.muted)
                Text(Countdown.formatDate(event, now: now))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(Countdown.shortLabel(event, now: now))
                .font(Countdown.hasElapsed(event, now: now) ? .footnote.weight(.bold) : .callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .multilineTextAlignment(.trailing)
                .fixedSize()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).strokeBorder(Theme.border)
        )
        .contentShape(Rectangle())
    }
}
