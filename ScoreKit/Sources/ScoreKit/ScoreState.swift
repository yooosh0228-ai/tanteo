import Foundation

/// Un set terminado.
public struct SetResult: Codable, Equatable, Sendable {
    /// Juegos de cada equipo (en un súper tie-break se guarda 1-0).
    public var games: Pair
    /// Puntos del tie-break, si el set se definió así.
    public var tiebreak: Pair?
    /// El set fue un súper tie-break completo (set decisivo a 10).
    public var isSuperTiebreak: Bool

    public init(games: Pair, tiebreak: Pair? = nil, isSuperTiebreak: Bool = false) {
        self.games = games
        self.tiebreak = tiebreak
        self.isSuperTiebreak = isSuperTiebreak
    }

    public var winner: Team { games.a > games.b ? .a : .b }

    /// Texto corto: "6-4", "7-6 (7-5)", "10-8".
    public var label: String {
        if isSuperTiebreak, let tb = tiebreak { return "\(tb.a)-\(tb.b)" }
        if let tb = tiebreak { return "\(games.a)-\(games.b) (\(tb.a)-\(tb.b))" }
        return "\(games.a)-\(games.b)"
    }
}

/// El marcador en un instante. Es un valor: cada punto produce un estado nuevo.
public struct ScoreState: Codable, Equatable, Sendable {
    public var config: MatchConfig
    public var sets: [SetResult]
    public var games: Pair
    public var points: Pair
    public var inTiebreak: Bool
    public var isSuperTiebreak: Bool
    public var server: Team
    /// Quién sacó primero en el tie-break en curso (para saber quién saca después).
    public var tiebreakFirstServer: Team?
    public var winner: Team?

    public init(config: MatchConfig, firstServer: Team = .a) {
        self.config = config
        self.sets = []
        self.games = Pair()
        self.points = Pair()
        self.inTiebreak = false
        self.isSuperTiebreak = false
        self.server = firstServer
        self.tiebreakFirstServer = nil
        self.winner = nil
    }

    public var isFinished: Bool { winner != nil }

    public var setsWon: Pair {
        var won = Pair()
        for set in sets { won[set.winner] += 1 }
        return won
    }

    // MARK: - Sumar un punto

    public mutating func addPoint(to team: Team) {
        guard winner == nil else { return }
        switch config.sport {
        case .generic: addGenericPoint(to: team)
        case .padel: addPadelPoint(to: team)
        }
    }

    private mutating func addGenericPoint(to team: Team) {
        points[team] += 1
        let target = max(1, config.targetPoints)
        let lead = points[team] - points[team.other]
        if points[team] >= target && (!config.winByTwo || lead >= 2) {
            winner = team
        }
    }

    private mutating func addPadelPoint(to team: Team) {
        points[team] += 1
        let mine = points[team]
        let theirs = points[team.other]

        if inTiebreak {
            let target = isSuperTiebreak ? config.superTiebreakPoints : config.tiebreakPoints
            if mine >= target && mine - theirs >= 2 {
                finishTiebreak(wonBy: team)
            } else if points.total % 2 == 1 {
                // En el tie-break el saque cambia tras el primer punto y luego cada dos.
                server = server.other
            }
            return
        }

        let gameWon: Bool
        switch config.deuceRule {
        case .goldenPoint:
            gameWon = mine >= 4
        case .advantage:
            gameWon = mine >= 4 && mine - theirs >= 2
        }
        if gameWon { winGame(team) }
    }

    private mutating func winGame(_ team: Team) {
        games[team] += 1
        points = Pair()
        server = server.other

        let mine = games[team]
        let theirs = games[team.other]
        let perSet = config.gamesPerSet

        if mine >= perSet && mine - theirs >= 2 {
            closeSet(wonBy: team, tiebreak: nil)
        } else if mine == perSet && theirs == perSet {
            inTiebreak = true
            isSuperTiebreak = false
            tiebreakFirstServer = server
        }
    }

    private mutating func finishTiebreak(wonBy team: Team) {
        let tb = points
        let wasSuper = isSuperTiebreak
        // Después del tie-break saca quien recibió el primer punto.
        if let first = tiebreakFirstServer { server = first.other }

        if wasSuper {
            var g = Pair()
            g[team] = 1
            sets.append(SetResult(games: g, tiebreak: tb, isSuperTiebreak: true))
            resetForNextSet()
            checkMatchWinner()
        } else {
            games[team] += 1
            closeSet(wonBy: team, tiebreak: tb)
        }
    }

    private mutating func closeSet(wonBy team: Team, tiebreak: Pair?) {
        sets.append(SetResult(games: games, tiebreak: tiebreak))
        resetForNextSet()
        checkMatchWinner()
    }

    private mutating func resetForNextSet() {
        games = Pair()
        points = Pair()
        inTiebreak = false
        isSuperTiebreak = false
        tiebreakFirstServer = nil
    }

    private mutating func checkMatchWinner() {
        let won = setsWon
        let need = max(1, config.setsToWin)
        if won.a >= need { winner = .a; return }
        if won.b >= need { winner = .b; return }

        // Set decisivo como súper tie-break.
        if config.superTiebreakDecider && need > 1 && won.a == need - 1 && won.b == need - 1 {
            inTiebreak = true
            isSuperTiebreak = true
            tiebreakFirstServer = server
        }
    }

    // MARK: - Textos para la pantalla

    /// Lo que se muestra como puntos de un equipo: "15", "40", "AD", "7"…
    public func pointLabel(for team: Team) -> String {
        if config.sport == .generic || inTiebreak { return "\(points[team])" }

        let mine = points[team]
        let theirs = points[team.other]
        if config.deuceRule == .advantage && mine >= 3 && theirs >= 3 {
            if mine == theirs { return "40" }
            return mine > theirs ? "AD" : "40"
        }
        switch mine {
        case 0: return "0"
        case 1: return "15"
        case 2: return "30"
        default: return "40"
        }
    }

    /// Una línea de estado: "Punto de oro", "Ventaja Equipo A", "Tie-break"… o nil si no hay nada especial.
    public var statusLabel: String? {
        if let winner { return "Ganó \(config.name(of: winner))" }
        if config.sport == .generic {
            let target = config.targetPoints
            if config.winByTwo && points.a >= target - 1 && points.b >= target - 1 && points.a == points.b {
                return "Iguales"
            }
            return nil
        }
        if isSuperTiebreak { return "Súper tie-break" }
        if inTiebreak { return "Tie-break" }
        if points.a >= 3 && points.b >= 3 {
            if points.a == points.b {
                return config.deuceRule == .goldenPoint ? "Punto de oro" : "Iguales"
            }
            let leader: Team = points.a > points.b ? .a : .b
            return "Ventaja \(config.name(of: leader))"
        }
        return nil
    }

    /// Sets terminados en una línea: "6-4  3-6".
    public var setsSummary: String {
        sets.map(\.label).joined(separator: "  ")
    }
}
