enum KanbanColumnDragPayload {
    static let prefix = "myjira-column:"

    static func title(from payload: String) -> String? {
        guard payload.hasPrefix(prefix) else { return nil }
        return String(payload.dropFirst(prefix.count))
    }
}
