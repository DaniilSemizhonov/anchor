// Имитация жеста двумя пальцами на трекпаде для проверки свайпов в CI.
// scroll X Y DX DY [full|hold|end]: hold — начать и не отпускать, end — только отпустить.
import CoreGraphics
import Foundation

let args = CommandLine.arguments
let point = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
let dx = Int32(args[3])!, dy = Int32(args[4])!
let mode = args.count > 5 ? args[5] : "full"

CGWarpMouseCursorPosition(point)
usleep(100_000)

func post(phase: Int64, dx: Int32, dy: Int32) {
    let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)!
    event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
    event.location = point
    event.post(tap: .cghidEventTap)
    usleep(16_000)
}

if mode != "end" {
    post(phase: 1, dx: 0, dy: 0) // began
    let steps: Int32 = 10
    for _ in 0..<steps { post(phase: 2, dx: dx / steps, dy: dy / steps) } // changed
}
if mode != "hold" {
    post(phase: 4, dx: 0, dy: 0) // ended
}
