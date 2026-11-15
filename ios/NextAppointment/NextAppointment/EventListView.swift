import SwiftUI

/// Lista "Mis eventos": todos los eventos activos, con búsqueda por nombre
/// y orden "Próximos primero".
struct EventListView: View {
    @Environment(EventStore.self) private var store
    @State private var query = ""
    @State private var editor: EditorTarget?

    var body: some View {
        let all = store.upcomingEvents()
        let events = filter(all)

        List {
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
                        }
                    }
                } header: {
                    Text("\(events.count) \(events.count == 1 ? "evento" : "eventos") · Próximos primero")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .textCase(nil)
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if events.isEmpty {
                emptyState(hasEvents: !all.isEmpty)
            }
        }
        .navigationTitle("Mis eventos")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar evento...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = .new
                } label: {
                    Label("Crear evento", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editor) { target in
            EventFormView(event: target.event)
        }
    }

    @ViewBuilder
    private func emptyState(hasEvents: Bool) -> some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if hasEvents, !trimmed.isEmpty {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "Sin resultados",
                subtitle: "Nada coincide con \"\(trimmed)\"."
            )
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

    /// Búsqueda por nombre, sin distinguir mayúsculas ni acentos.
    private func filter(_ events: [Event]) -> [Event] {
        let needle = normalize(query.trimmingCharacters(in: .whitespaces))
        guard !needle.isEmpty else { return events }
        return events.filter { normalize($0.name).contains(needle) }
    }

    private func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Countdown.spanish)
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

            Spacer(minLength: 8)

            Text(Countdown.shortLabel(event, now: now))
                .font(.callout.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(accent)
                .multilineTextAlignment(.trailing)
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
