import SwiftUI

/// Pantalla de celebración cuando un evento llega: emoji, mensaje y confeti.
struct CelebrationView: View {
    let event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !reduceMotion {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 16) {
                Spacer()
                Text(event.emoji)
                    .font(.system(size: 96))
                    .offset(y: bounce ? -14 : 0)
                Text("¡Ya llegó el día!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.text)
                Text("\"\(event.name)\" — ¡hoy es el día!")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Volver al inicio")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

/// Confeti que cae: 60 piezas con los colores de la app, como en la web.
struct ConfettiView: View {
    private struct Piece {
        let x: Double        // posición horizontal, de 0 a 1
        let delay: Double    // segundos antes de empezar a caer
        let duration: Double // segundos que tarda en cruzar la pantalla
        let spin: Double     // vueltas por segundo
        let color: Color
    }

    private let pieces: [Piece]
    private let start = Date()

    init(count: Int = 60) {
        pieces = (0..<count).map { _ in
            Piece(
                x: .random(in: 0...1),
                delay: .random(in: 0...1.5),
                duration: .random(in: 2...4),
                spin: .random(in: 0.3...1.2) * (Bool.random() ? 1 : -1),
                color: Color(hex: Catalog.colors.randomElement() ?? Catalog.defaultColor)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(start)
                for piece in pieces {
                    // Cada pieza cae en bucle: al llegar abajo vuelve a salir por arriba.
                    let time = elapsed - piece.delay
                    guard time > 0 else { continue }
                    let progress = time.truncatingRemainder(dividingBy: piece.duration) / piece.duration
                    let position = CGPoint(x: piece.x * size.width, y: -20 + progress * (size.height + 40))

                    var layer = canvas
                    layer.translateBy(x: position.x, y: position.y)
                    layer.rotate(by: .degrees(time * piece.spin * 360))
                    layer.opacity = 0.9
                    layer.fill(
                        Path(CGRect(x: -4, y: -8, width: 8, height: 16)),
                        with: .color(piece.color)
                    )
                }
            }
        }
    }
}
