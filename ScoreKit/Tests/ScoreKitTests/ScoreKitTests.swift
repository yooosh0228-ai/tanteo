import XCTest
@testable import ScoreKit

final class ScoreKitTests: XCTestCase {

    private func padel(_ rule: DeuceRule = .goldenPoint, superTB: Bool = false) -> ScoreState {
        ScoreState(config: MatchConfig(sport: .padel, deuceRule: rule, superTiebreakDecider: superTB))
    }

    private func win(game team: Team, in s: inout ScoreState) {
        for _ in 0..<4 { s.addPoint(to: team) }
    }

    func testPointLabels() {
        var s = padel()
        XCTAssertEqual(s.pointLabel(for: .a), "0")
        s.addPoint(to: .a)
        XCTAssertEqual(s.pointLabel(for: .a), "15")
        s.addPoint(to: .a)
        XCTAssertEqual(s.pointLabel(for: .a), "30")
        s.addPoint(to: .a)
        XCTAssertEqual(s.pointLabel(for: .a), "40")
        s.addPoint(to: .a)
        XCTAssertEqual(s.games, Pair(1, 0))
        XCTAssertEqual(s.points, Pair(0, 0))
    }

    func testGoldenPointWinsAtDeuce() {
        var s = padel(.goldenPoint)
        for _ in 0..<3 { s.addPoint(to: .a); s.addPoint(to: .b) }
        XCTAssertEqual(s.statusLabel, "Punto de oro")
        s.addPoint(to: .b)
        XCTAssertEqual(s.games, Pair(0, 1))
    }

    func testAdvantageNeedsTwoPoints() {
        var s = padel(.advantage)
        for _ in 0..<3 { s.addPoint(to: .a); s.addPoint(to: .b) }
        XCTAssertEqual(s.statusLabel, "Iguales")
        s.addPoint(to: .a)
        XCTAssertEqual(s.pointLabel(for: .a), "AD")
        XCTAssertEqual(s.statusLabel, "Ventaja Equipo A")
        s.addPoint(to: .b) // vuelve a iguales
        XCTAssertEqual(s.games, Pair(0, 0))
        XCTAssertEqual(s.pointLabel(for: .a), "40")
        s.addPoint(to: .b)
        s.addPoint(to: .b)
        XCTAssertEqual(s.games, Pair(0, 1))
    }

    func testSetAtSixFour() {
        var s = padel()
        for _ in 0..<4 { win(game: .a, in: &s); win(game: .b, in: &s) } // 4-4
        win(game: .a, in: &s)
        win(game: .a, in: &s) // 6-4
        XCTAssertEqual(s.sets.count, 1)
        XCTAssertEqual(s.sets[0].label, "6-4")
        XCTAssertEqual(s.games, Pair(0, 0))
    }

    func testSevenFiveAndTiebreak() {
        var s = padel()
        for _ in 0..<5 { win(game: .a, in: &s); win(game: .b, in: &s) } // 5-5
        win(game: .a, in: &s) // 6-5, no hay set aún
        XCTAssertTrue(s.sets.isEmpty)
        win(game: .b, in: &s) // 6-6 → tie-break
        XCTAssertTrue(s.inTiebreak)
        XCTAssertEqual(s.statusLabel, "Tie-break")
        for _ in 0..<6 { s.addPoint(to: .a); s.addPoint(to: .b) } // 6-6 en el tie-break
        s.addPoint(to: .a) // 7-6, falta diferencia de dos
        XCTAssertTrue(s.inTiebreak)
        s.addPoint(to: .a) // 8-6
        XCTAssertFalse(s.inTiebreak)
        XCTAssertEqual(s.sets.first?.label, "7-6 (8-6)")
    }

    func testTiebreakServeRotation() {
        var s = padel()
        for _ in 0..<6 { win(game: .a, in: &s); win(game: .b, in: &s) } // 6-6
        let first = s.server
        s.addPoint(to: .a) // tras 1 punto cambia
        XCTAssertEqual(s.server, first.other)
        s.addPoint(to: .a) // tras 2 sigue igual
        XCTAssertEqual(s.server, first.other)
        s.addPoint(to: .a) // tras 3 cambia
        XCTAssertEqual(s.server, first)
    }

    func testServeAlternatesEachGame() {
        var s = padel()
        XCTAssertEqual(s.server, .a)
        win(game: .b, in: &s)
        XCTAssertEqual(s.server, .b)
        win(game: .b, in: &s)
        XCTAssertEqual(s.server, .a)
    }

    func testMatchBestOfThree() {
        var s = padel()
        for _ in 0..<6 { win(game: .a, in: &s) } // 6-0
        for _ in 0..<6 { win(game: .b, in: &s) } // 0-6
        XCTAssertNil(s.winner)
        for _ in 0..<6 { win(game: .a, in: &s) }
        XCTAssertEqual(s.winner, .a)
        XCTAssertEqual(s.setsSummary, "6-0  0-6  6-0")
        s.addPoint(to: .b) // no cuenta después de terminar
        XCTAssertEqual(s.points, Pair(0, 0))
    }

    func testSuperTiebreakDecider() {
        var s = padel(superTB: true)
        for _ in 0..<6 { win(game: .a, in: &s) }
        for _ in 0..<6 { win(game: .b, in: &s) }
        XCTAssertTrue(s.inTiebreak)
        XCTAssertTrue(s.isSuperTiebreak)
        for _ in 0..<9 { s.addPoint(to: .b) }
        XCTAssertNil(s.winner)
        s.addPoint(to: .b)
        XCTAssertEqual(s.winner, .b)
        XCTAssertEqual(s.sets.last?.label, "0-10")
    }

    func testGenericWinByTwo() {
        var s = ScoreState(config: MatchConfig(sport: .generic, targetPoints: 11, winByTwo: true))
        for _ in 0..<10 { s.addPoint(to: .a); s.addPoint(to: .b) } // 10-10
        XCTAssertEqual(s.statusLabel, "Iguales")
        s.addPoint(to: .a) // 11-10
        XCTAssertNil(s.winner)
        s.addPoint(to: .a) // 12-10
        XCTAssertEqual(s.winner, .a)
    }

    func testGenericFirstToTarget() {
        var s = ScoreState(config: MatchConfig(sport: .generic, targetPoints: 5, winByTwo: false))
        for _ in 0..<4 { s.addPoint(to: .a); s.addPoint(to: .b) }
        s.addPoint(to: .b)
        XCTAssertEqual(s.winner, .b)
    }

    func testUndoAndSync() throws {
        var m = Match(config: MatchConfig())
        let start = m.updatedAt
        m.addPoint(to: .a)
        m.addPoint(to: .b)
        XCTAssertEqual(m.state.points, Pair(1, 1))
        XCTAssertGreaterThan(m.updatedAt, start)
        m.undo()
        XCTAssertEqual(m.state.points, Pair(1, 0))
        XCTAssertEqual(m.pointLog, [.a])

        let data = try JSONEncoder().encode(m)
        let copy = try JSONDecoder().decode(Match.self, from: data)
        XCTAssertEqual(copy, m)
        XCTAssertEqual(copy.state, m.state)
    }

    func testUndoAcrossGame() {
        var m = Match(config: MatchConfig())
        for _ in 0..<4 { m.addPoint(to: .a) }
        XCTAssertEqual(m.state.games, Pair(1, 0))
        m.undo()
        XCTAssertEqual(m.state.games, Pair(0, 0))
        XCTAssertEqual(m.state.pointLabel(for: .a), "40")
    }

    func testChangeOfEnds() {
        var m = Match(config: MatchConfig())
        for _ in 0..<3 { m.addPoint(to: .a) }
        XCTAssertFalse(m.changeOfEnds)
        m.addPoint(to: .a) // 1-0: juego impar → cambio
        XCTAssertTrue(m.changeOfEnds)
        for _ in 0..<4 { m.addPoint(to: .b) } // 1-1
        XCTAssertFalse(m.changeOfEnds)
        for _ in 0..<4 { m.addPoint(to: .b) } // 1-2
        XCTAssertTrue(m.changeOfEnds)
    }

    func testChangeOfEndsInTiebreak() {
        var m = Match(config: MatchConfig())
        for _ in 0..<6 {
            for _ in 0..<4 { m.addPoint(to: .a) }
            for _ in 0..<4 { m.addPoint(to: .b) }
        }
        XCTAssertTrue(m.state.inTiebreak)
        for i in 1...6 {
            m.addPoint(to: i % 2 == 0 ? .a : .b)
            XCTAssertEqual(m.changeOfEnds, i == 6)
        }
    }

    func testServerOverrideAndUndoReplay() throws {
        var m = Match(config: MatchConfig())
        m.addPoint(to: .a)
        m.setServer(.b)
        XCTAssertEqual(m.state.server, .b)
        m.undo() // quita el punto y el cambio de saque posterior
        XCTAssertEqual(m.state.points, Pair(0, 0))
        XCTAssertEqual(m.state.server, .a)
        XCTAssertFalse(m.canUndo)

        for _ in 0..<10 { m.addPoint(to: .b) }
        let copy = try JSONDecoder().decode(Match.self, from: JSONEncoder().encode(m))
        XCTAssertEqual(copy.state, m.state)
    }

    func testLongestStreak() {
        var m = Match(config: MatchConfig(sport: .generic, targetPoints: 50))
        for t: Team in [.a, .a, .b, .a, .a, .a, .b, .b] { m.addPoint(to: t) }
        XCTAssertEqual(m.longestStreak, Pair(3, 2))
    }
}
