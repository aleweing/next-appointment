import SwiftUI

/// Tarjeta grande de un evento, con la cuenta atrás en vivo.
struct EventCardView: View {
    let event: Event
    var onEdit: (() -> Void)?

    var body: some View {
        // Se redibuja cada segundo para que la cuenta atrás avance.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            card(now: context.date)
        }
    }

    private func card(now: Date) -> some View {
        let accent = Theme.accent(event.color)
        let elapsed = Countdown.hasElapsed(event, now: now)
        let category = Catalog.category(id: event.category)
        let recurrence = event.recurrence

        return VStack(spacing: 14) {
            HStack(alignment: .top) {
                Text("\(category.emoji) \(category.label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.background, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.border))
                Spacer(minLength: 8)
                if recurrence.unit != .none {
                    Text("🔁 \(Countdown.recurrenceLabel(recurrence))")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: event.color), in: Capsule())
                }
            }

            Spacer(minLength: 0)

            Text(event.emoji)
                .font(.system(size: 76))

            Text(event.name)
                .font(.title2.bold())
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)

            if elapsed {
                Text("🎉 ¡Ya llegó el día!")
                    .font(.title3.bold())
                    .foregroundStyle(accent)
                    .padding(.vertical, 12)
            } else {
                CountdownUnitsView(
                    breakdown: Countdown.breakdown(Countdown.remaining(event, now: now)),
                    accent: accent
                )
                .padding(.vertical, 4)
            }

            Text(Countdown.formatDate(event, now: now))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            if let onEdit {
                HStack(spacing: 14) {
                    CardActionButton(systemImage: "pencil", label: "Editar", tint: Theme.muted, action: onEdit)
                    CardActionButton(
                        systemImage: event.notifyBefore != nil ? "bell.fill" : "bell.slash",
                        label: event.notifyBefore != nil ? "Aviso activado" : "Sin aviso",
                        tint: event.notifyBefore != nil ? accent : Theme.muted,
                        action: onEdit
                    )
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            // El color del evento tiñe suavemente la parte alta de la tarjeta.
            LinearGradient(
                colors: [Color(hex: event.color).opacity(0.20), Color(hex: event.color).opacity(0)],
                startPoint: .top, endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        )
        .cardBackground(
            border: elapsed ? accent : Theme.border,
            borderWidth: elapsed ? 2 : 1
        )
    }
}

/// Los cuatro números de la cuenta atrás: días, horas, minutos y segundos.
struct CountdownUnitsView: View {
    let breakdown: Countdown.Breakdown
    let accent: Color
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            unit(breakdown.days, "Días")
            unit(breakdown.hours, "Horas")
            unit(breakdown.minutes, "Min")
            unit(breakdown.seconds, "Seg")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Faltan \(breakdown.days) días, \(breakdown.hours) horas, \(breakdown.minutes) minutos y \(breakdown.seconds) segundos"
        )
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: compact ? 24 : 32, weight: .heavy, design: .rounded))
                .monospacedDigit() // dígitos de ancho fijo: los números no bailan
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 12)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
    }
}

private struct CardActionButton: View {
    let systemImage: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Theme.background, in: Circle())
                .overlay(Circle().strokeBorder(Theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
