import Foundation

/// Un partido: el marcador actual más lo necesario para deshacer y sincronizar.
public struct Match: Codable, Equatable, Identifiable, Sendable {
    public static let undoLimit = 60

    public let id: UUID
    public let startedAt: Date
    /// Cambia con cada punto; sirve para que el reloj y el iPhone sepan cuál versión es la más nueva.
    public private(set) var updatedAt: Date
    public private(set) var state: ScoreState
    public private(set) var history: [ScoreState]
    /// Quién ganó cada punto, en orden (para estadísticas).
    public private(set) var pointLog: [Team]

    public init(config: MatchConfig, firstServer: Team = .a, now: Date = Date()) {
        self.id = UUID()
        self.startedAt = now
        self.updatedAt = now
        self.state = ScoreState(config: config, firstServer: firstServer)
        self.history = []
        self.pointLog = []
    }

    public var config: MatchConfig { state.config }
    public var canUndo: Bool { !history.isEmpty }

    public mutating func addPoint(to team: Team, now: Date = Date()) {
        guard !state.isFinished else { return }
        history.append(state)
        if history.count > Match.undoLimit {
            history.removeFirst(history.count - Match.undoLimit)
        }
        state.addPoint(to: team)
        pointLog.append(team)
        updatedAt = max(now, updatedAt.addingTimeInterval(0.001))
    }

    public mutating func undo(now: Date = Date()) {
        guard let previous = history.popLast() else { return }
        state = previous
        if !pointLog.isEmpty { pointLog.removeLast() }
        updatedAt = max(now, updatedAt.addingTimeInterval(0.001))
    }

    /// Cambia quién saca ahora (por si empezaron sacando los otros).
    public mutating func setServer(_ team: Team, now: Date = Date()) {
        state.server = team
        updatedAt = max(now, updatedAt.addingTimeInterval(0.001))
    }

    public var pointsWon: Pair {
        var p = Pair()
        for t in pointLog { p[t] += 1 }
        return p
    }

    /// Resumen de una línea para el historial.
    public var summary: String {
        let s = state
        if s.config.sport == .generic {
            return "\(s.points.a) - \(s.points.b)"
        }
        var parts = s.sets.map(\.label)
        if !s.isFinished && (s.games.total > 0 || s.points.total > 0) {
            parts.append("\(s.games.a)-\(s.games.b)")
        }
        return parts.isEmpty ? "0-0" : parts.joined(separator: "  ")
    }
}
