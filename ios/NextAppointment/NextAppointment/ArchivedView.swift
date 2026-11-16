import SwiftUI

/// Eventos archivados, con un botón para restaurar cada uno.
struct ArchivedView: View {
    @Environment(EventStore.self) private var store

    var body: some View {
        let events = store.archivedEvents

        List {
            Section {
                ForEach(events) { event in
                    ArchivedRowView(event: event) {
                        withAnimation { store.restore(id: event.id) }
                        Task { await NotificationScheduler.rescheduleAll([event]) }
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Los eventos pasados se archivan automáticamente a las 24 h y se eliminan a los 30 días de archivados.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .textCase(nil)
                    .padding(.bottom, 6)
            }
            .listSectionSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if events.isEmpty {
                EmptyStateView(
                    systemImage: "archivebox",
                    title: "No hay eventos archivados",
                    subtitle: "Aquí aparecerán los eventos pasados que se archiven automáticamente."
                )
                .padding(.top, 60)
            }
        }
        .navigationTitle("Archivados")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct ArchivedRowView: View {
    let event: Event
    let onRestore: () -> Void

    var body: some View {
        let category = Catalog.category(id: event.category)
        let daysLeft = Countdown.daysUntilDeletion(event)

        HStack(spacing: 14) {
            Text(event.emoji)
                .font(.system(size: 30))
                .frame(width: 50, height: 50)
                .background(Color(hex: event.color).opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                Text("\(category.emoji) \(category.label)")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(Countdown.formatDate(event))
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(daysLeft > 0 ? "Se eliminará en \(daysLeft) día\(daysLeft == 1 ? "" : "s")" : "Se eliminará pronto")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onRestore) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 44, height: 44)
                    .background(Theme.brand.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restaurar evento")
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).strokeBorder(Theme.border)
        )
    }
}
