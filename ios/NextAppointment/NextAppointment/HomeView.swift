import Combine
import SwiftUI

/// Qué se está editando en la hoja del formulario: un evento nuevo o uno existente.
struct EditorTarget: Identifiable {
    let id: String
    let event: Event?

    static var new: EditorTarget { EditorTarget(id: "nuevo", event: nil) }
    static func edit(_ event: Event) -> EditorTarget { EditorTarget(id: event.id, event: event) }
}

/// Pantalla principal: carrusel horizontal con una tarjeta por evento.
struct HomeView: View {
    @Environment(EventStore.self) private var store
    @State private var editor: EditorTarget?
    @State private var currentId: String?
    @State private var showList = false
    @State private var celebration: Event?

    /// Un tic por segundo para comprobar si algún evento acaba de llegar.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let events = store.upcomingEvents()

        NavigationStack {
            Group {
                if events.isEmpty {
                    EmptyStateView(
                        title: "Nada en el horizonte todavía",
                        subtitle: "Crea tu primera cuenta atrás: un viaje, un cumpleaños, lo que sea que estés esperando.",
                        actionTitle: "Crear evento"
                    ) {
                        editor = .new
                    }
                } else {
                    carousel(events)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("⏳ Next Appointment")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showList = true
                    } label: {
                        Label("Mis eventos", systemImage: "list.bullet")
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
            .navigationDestination(isPresented: $showList) {
                EventListView()
            }
            .sheet(item: $editor) { target in
                EventFormView(event: target.event)
            }
            .fullScreenCover(item: $celebration) { event in
                CelebrationView(event: event)
            }
            .onReceive(ticker) { now in
                checkCelebration(now: now)
            }
        }
    }

    /// Muestra la celebración del evento que acaba de llegar. Solo desde esta
    /// pantalla, para no interrumpir si se está en la lista o editando.
    private func checkCelebration(now: Date) {
        guard editor == nil, !showList, celebration == nil else { return }
        let pending = Countdown.eventsToCelebrate(store.activeEvents, now: now)
        guard let latest = pending.first else { return }
        // Si llegaron varios mientras la app estaba cerrada, se celebra el más reciente.
        store.markCelebrated(ids: pending.map(\.id))
        celebration = latest
    }

    private func carousel(_ events: [Event]) -> some View {
        let currentIndex = events.firstIndex { $0.id == currentId } ?? 0

        return VStack(spacing: 14) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(events) { event in
                        EventCardView(event: event) {
                            editor = .edit(event)
                        }
                        .padding(.horizontal, 20)
                        .containerRelativeFrame(.horizontal)
                        .id(event.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollClipDisabled() // deja ver la sombra de la tarjeta
            .scrollPosition(id: $currentId)

            PageDots(count: events.count, index: currentIndex)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

/// Puntos de página del carrusel.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Theme.brand : Theme.border)
                    .frame(width: i == index ? 20 : 8, height: 8)
            }
        }
        .animation(.snappy, value: index)
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Evento \(index + 1) de \(count)")
    }
}

/// Estado vacío con icono, título, texto y un botón opcional.
struct EmptyStateView: View {
    var systemImage = "hourglass"
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Theme.brand)
                .frame(width: 84, height: 84)
                .background(Theme.brand.opacity(0.12), in: Circle())
                .padding(.bottom, 8)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.body.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
