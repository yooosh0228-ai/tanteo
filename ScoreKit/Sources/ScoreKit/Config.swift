import Foundation

/// Uno de los dos lados de la cancha.
public enum Team: String, Codable, CaseIterable, Sendable {
    case a, b

    public var other: Team { self == .a ? .b : .a }
}

/// Un par de números, uno por equipo.
public struct Pair: Codable, Equatable, Sendable {
    public var a: Int
    public var b: Int

    public init(_ a: Int = 0, _ b: Int = 0) {
        self.a = a
        self.b = b
    }

    public subscript(team: Team) -> Int {
        get { team == .a ? a : b }
        set {
            if team == .a { a = newValue } else { b = newValue }
        }
    }

    public var total: Int { a + b }
}

/// Deporte o modo de conteo.
public enum Sport: String, Codable, CaseIterable, Sendable {
    /// Pádel (y tenis): 15-30-40, juegos, sets y tie-break.
    case padel
    /// Cualquier deporte que se cuente por puntos hasta un objetivo (vóleibol, ping-pong, bádminton…).
    case generic

    public var displayName: String {
        switch self {
        case .padel: return "Pádel"
        case .generic: return "Por puntos"
        }
    }
}

/// Qué pasa cuando el juego llega a 40-40.
public enum DeuceRule: String, Codable, CaseIterable, Sendable {
    /// El siguiente punto gana el juego.
    case goldenPoint
    /// Hay que ganar dos puntos seguidos (ventaja).
    case advantage

    public var displayName: String {
        switch self {
        case .goldenPoint: return "Punto de oro"
        case .advantage: return "Ventaja"
        }
    }
}

/// Reglas del partido, elegidas antes de empezar.
public struct MatchConfig: Codable, Equatable, Sendable {
    public var sport: Sport
    public var teamA: String
    public var teamB: String

    // Pádel
    public var deuceRule: DeuceRule
    /// Sets que hay que ganar: 1 = a un set, 2 = al mejor de tres.
    public var setsToWin: Int
    public var gamesPerSet: Int
    public var tiebreakPoints: Int
    /// Si el set decisivo se juega como súper tie-break a 10.
    public var superTiebreakDecider: Bool
    public var superTiebreakPoints: Int

    // Por puntos
    public var targetPoints: Int
    public var winByTwo: Bool

    public init(
        sport: Sport = .padel,
        teamA: String = "Equipo A",
        teamB: String = "Equipo B",
        deuceRule: DeuceRule = .goldenPoint,
        setsToWin: Int = 2,
        gamesPerSet: Int = 6,
        tiebreakPoints: Int = 7,
        superTiebreakDecider: Bool = false,
        superTiebreakPoints: Int = 10,
        targetPoints: Int = 21,
        winByTwo: Bool = true
    ) {
        self.sport = sport
        self.teamA = teamA
        self.teamB = teamB
        self.deuceRule = deuceRule
        self.setsToWin = setsToWin
        self.gamesPerSet = gamesPerSet
        self.tiebreakPoints = tiebreakPoints
        self.superTiebreakDecider = superTiebreakDecider
        self.superTiebreakPoints = superTiebreakPoints
        self.targetPoints = targetPoints
        self.winByTwo = winByTwo
    }

    public func name(of team: Team) -> String {
        let raw = team == .a ? teamA : teamB
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return team == .a ? "Equipo A" : "Equipo B" }
        return trimmed
    }
}
