import XCTest

/// Tests de la lectura del emoji elegido con el teclado del sistema.
final class EmojiInputTests: XCTestCase {

    func testReconoceEmojis() {
        for emoji in ["😀", "🎂", "❤️", "☀️", "👨‍👩‍👧", "👍🏽", "🇦🇷", "🇪🇸", "1️⃣", "🏳️‍🌈", "🫶"] {
            XCTAssertTrue(EmojiInput.isEmoji(Character(emoji)), emoji)
        }
    }

    func testDescartaLetrasNumerosYSimbolos() {
        for character in ["a", "Ñ", "7", "#", "*", "©", "€", " ", "♥"] {
            XCTAssertFalse(EmojiInput.isEmoji(Character(character)), character)
        }
    }

    func testUltimoEmojiDelTexto() {
        XCTAssertEqual(EmojiInput.lastEmoji(in: "🎂"), "🎂")
        XCTAssertEqual(EmojiInput.lastEmoji(in: "🎂🌴"), "🌴", "se queda con el último")
        XCTAssertEqual(EmojiInput.lastEmoji(in: "hola 🇦🇷 adiós"), "🇦🇷")
        XCTAssertEqual(EmojiInput.lastEmoji(in: "👨‍👩‍👧"), "👨‍👩‍👧", "familia: un solo carácter")
        XCTAssertNil(EmojiInput.lastEmoji(in: "sin emoji 123"))
        XCTAssertNil(EmojiInput.lastEmoji(in: ""))
    }

    func testCualquierEmojiSeGuardaYSeLeeIgual() throws {
        let event = Event(id: "a", name: "Mundial", date: "2026-06-11", emoji: "🇦🇷")
        let restored = try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event))
        XCTAssertEqual(restored.emoji, "🇦🇷")
    }
}
