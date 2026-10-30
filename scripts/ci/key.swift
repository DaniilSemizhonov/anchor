// Нажатие клавиши по коду для CI: key 36 — Return. cliclick иногда терял Return.
import CoreGraphics
import Foundation

let code = CGKeyCode(CommandLine.arguments[1])!
for isDown in [true, false] {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: isDown)!
    event.flags = []
    event.post(tap: .cghidEventTap)
    usleep(30_000)
}
