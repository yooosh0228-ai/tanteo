import Foundation

/// Algo que pasó en el partido. El marcador se calcula repitiendo estos eventos en orden,
/// así deshacer es quitar el último y lo que viaja entre reloj e iPhone es muy poco.
public enum MatchEvent: Codable, Equatable, Sendable {
    case point(Team)
    case server(Team)
}

/// Un partido: reglas + lista de eventos. El marcador (`state`) se deriva de ahí.
public struct Match: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let config: MatchConfig
    public let firstServer: Team
    public let startedAt: Date
    /// Cambia con cada acción; sirve para que el reloj y el iPhone sepan cuál versión es la más nueva.
    public private(set) var updatedAt: Date
    public private(set) var events: [MatchEvent]
    /// Cuándo terminó (se marca al cerrarlo).
    public private(set) var endedAt: Date?

    /// Marcador actual (calculado; no se guarda ni se envía).
    public private(set) var state: ScoreState

    /// Hubo cambio de lado con el último punto.
    public private(set) var changeOfEnds: Bool = false

    public init(config: MatchConfig, firstServer: Team = .a, now: Date = Date()) {
        self.id = UUID()
        self.config = config
        self.firstServer = firstServer
        self.startedAt = now
        self.updatedAt = now
        self.events = []
        self.endedAt = nil
        self.state = ScoreState(config: config, firstServer: firstServer)
    }

    private enum CodingKeys: String, CodingKey {
        case id, config, firstServer, startedAt, updatedAt, events, endedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        config = try c.decode(MatchConfig.self, forKey: .config)
        firstServer = try c.decode(Team.self, forKey: .firstServer)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        events = try c.decode([MatchEvent].self, forKey: .events)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        state = ScoreState(config: config, firstServer: firstServer)
        replay()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(config, forKey: .config)
        try c.encode(firstServer, forKey: .firstServer)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(events, forKey: .events)
        try c.encodeIfPresent(endedAt, forKey: .endedAt)
    }

    public static func == (l: Match, r: Match) -> Bool {
        l.id == r.id && l.updatedAt == r.updatedAt && l.events == r.events && l.endedAt == r.endedAt
    }

    // MARK: - Acciones

    public var canUndo: Bool { events.contains { if case .point = $0 { return true } else { return false } } }

    public mutating func addPoint(to team: Team, now: Date = Date()) {
        guard !state.isFinished else { return }
        let before = state
        events.append(.point(team))
        state.addPoint(to: team)
        changeOfEnds = ScoreState.isChangeOfEnds(before: before, after: state)
        touch(now)
    }

    /// Deshace el último punto (y cualquier cambio de saque hecho después de él).
    public mutating func undo(now: Date = Date()) {
        guard let last = events.lastIndex(where: { if case .point = $0 { return true } else { return false } }) else { return }
        events.removeSubrange(last...)
        replay()
        changeOfEnds = false
        touch(now)
    }

    /// Corrige quién saca ahora.
    public mutating func setServer(_ team: Team, now: Date = Date()) {
        events.append(.server(team))
        state.server = team
        changeOfEnds = false
        touch(now)
    }

    public mutating func markEnded(now: Date = Date()) {
        endedAt = now
        touch(now)
    }

    private mutating func touch(_ now: Date) {
        updatedAt = max(now, updatedAt.addingTimeInterval(0.001))
    }

    private mutating func replay() {
        var s = ScoreState(config: config, firstServer: firstServer)
        var changed = false
        for e in events {
            switch e {
            case .point(let t):
                let before = s
                s.addPoint(to: t)
                changed = ScoreState.isChangeOfEnds(before: before, after: s)
            case .server(let t):
                s.server = t
                changed = false
            }
        }
        state = s
        changeOfEnds = changed
    }

    // MARK: - Datos

    public var pointLog: [Team] {
        events.compactMap { if case .point(let t) = $0 { return t } else { return nil } }
    }

    public var pointsWon: Pair {
        var p = Pair()
        for t in pointLog { p[t] += 1 }
        return p
    }

    /// La racha más larga de puntos seguidos de cada equipo.
    public var longestStreak: Pair {
        var best = Pair(), run = Pair()
        var last: Team?
        for t in pointLog {
            run[t] = (last == t ? run[t] : 0) + 1
            best[t] = max(best[t], run[t])
            last = t
        }
        return best
    }

    public var duration: TimeInterval {
        (endedAt ?? updatedAt).timeIntervalSince(startedAt)
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
