import SwiftUI
import UIKit

/// Campo que abre el teclado de emojis del sistema para elegir cualquier emoji,
/// con su buscador. Al elegir uno, lo devuelve y cierra el teclado.
struct EmojiField: UIViewRepresentable {
    let placeholder: String
    let onPick: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextField {
        let field = EmojiTextField()
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.textColor = .label
        field.tintColor = .clear // sin cursor: el campo hace de botón
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.accessibilityHint = "Abre el teclado de emojis"
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: EmojiTextField, context: Context) {
        context.coordinator.onPick = onPick
        field.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var onPick: (String) -> Void

        init(onPick: @escaping (String) -> Void) { self.onPick = onPick }

        @objc func textChanged(_ field: UITextField) {
            guard let emoji = EmojiInput.lastEmoji(in: field.text ?? "") else {
                field.text = "" // letras u otros símbolos: se ignoran
                return
            }
            field.text = ""
            onPick(emoji)
            field.resignFirstResponder()
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

/// Campo de texto que pide al sistema el teclado de emojis en vez del normal.
/// Si el teclado de emojis no está activado en el iPhone, sale el normal y se
/// puede cambiar al de emojis con el botón 🌐 / 😀.
final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "" } // evita que iOS recuerde otro teclado

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}
