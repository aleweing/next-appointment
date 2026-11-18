import Foundation

/// Lectura del emoji que el usuario escribe con el teclado de emojis del sistema.
nonisolated enum EmojiInput {

    /// ¿Este carácter es un emoji (y no una letra, un número o un símbolo de texto)?
    static func isEmoji(_ character: Character) -> Bool {
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return false }
        // Emojis que se ven como tales por defecto (😀, 🎂...).
        if first.properties.isEmojiPresentation { return true }
        // Emojis compuestos o con selector de variante: ❤️, ☀️, 1️⃣, banderas...
        return first.properties.isEmoji && scalars.count > 1
    }

    /// El último emoji de un texto, o `nil` si no hay ninguno.
    /// Se usa el último porque el campo puede contener el emoji anterior.
    static func lastEmoji(in text: String) -> String? {
        text.last(where: isEmoji).map(String.init)
    }
}
