import OSLog

public enum AppLog {
    public static let subsystem = "com.translatehotkey.app"
    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    public static let api = Logger(subsystem: subsystem, category: "api")
    public static let codec = Logger(subsystem: subsystem, category: "codec")
}
