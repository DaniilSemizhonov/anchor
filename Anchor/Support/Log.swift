import OSLog

/// Журнал для диагностики: `log show --predicate 'subsystem == "xyz.gelsemium.anchor"' --info`.
enum Log {
    static let capture = Logger(subsystem: "xyz.gelsemium.anchor", category: "capture")
    static let vault = Logger(subsystem: "xyz.gelsemium.anchor", category: "vault")
}
