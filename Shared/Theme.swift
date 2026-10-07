import SwiftUI
import ScoreKit

enum Theme {
    static let teamA = Color(red: 0.20, green: 0.78, blue: 0.55)   // verde cancha
    static let teamB = Color(red: 0.98, green: 0.62, blue: 0.20)   // naranja pelota
    static let accent = Color(red: 0.86, green: 1.00, blue: 0.25)  // amarillo pelota

    static func color(_ team: Team) -> Color {
        team == .a ? teamA : teamB
    }
}

extension MatchConfig {
    /// Descripción corta de las reglas: "Al mejor de 3 · Punto de oro".
    var rulesSummary: String {
        switch sport {
        case .generic:
            return "A \(targetPoints) puntos" + (winByTwo ? " · diferencia de 2" : "")
        case .padel:
            var parts = [setsToWin == 1 ? "A 1 set" : "Al mejor de \(setsToWin * 2 - 1)"]
            parts.append(deuceRule.displayName)
            if superTiebreakDecider && setsToWin > 1 { parts.append("súper tie-break") }
            return parts.joined(separator: " · ")
        }
    }
}
