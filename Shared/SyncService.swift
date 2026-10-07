import Foundation
import WatchConnectivity
import ScoreKit

/// Lo que viaja entre el reloj y el iPhone.
struct SyncPayload: Codable {
    /// El partido en curso (nil si se cerró).
    var match: Match?
    /// Si se cerró un partido, cuál fue.
    var clearedMatchID: UUID?
    var sentAt: Date
}

/// Puente con WatchConnectivity. Es igual en el reloj y en el iPhone.
final class SyncService: NSObject, WCSessionDelegate {
    var onPayload: (@MainActor (SyncPayload) -> Void)?
    var onFinished: (@MainActor (Match) -> Void)?
    var onReachability: (@MainActor (Bool) -> Void)?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    private var canSend: Bool {
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return true
        #endif
    }

    /// Manda el estado más reciente. Si el otro aparato está despierto llega al instante;
    /// si no, le llega en cuanto abra la app.
    func send(_ payload: SyncPayload) {
        guard canSend, let session, let data = try? encoder.encode(payload) else { return }
        try? session.updateApplicationContext(["payload": data])
        if session.isReachable {
            session.sendMessage(["payload": data], replyHandler: nil, errorHandler: nil)
        }
    }

    /// Manda un partido terminado con entrega garantizada (para el historial).
    func sendFinished(_ match: Match) {
        guard canSend, let session, let data = try? encoder.encode(match) else { return }
        session.transferUserInfo(["finished": data])
    }

    // MARK: - Recibir

    private func handle(_ dict: [String: Any]) {
        if let data = dict["payload"] as? Data, let payload = try? decoder.decode(SyncPayload.self, from: data) {
            Task { @MainActor in self.onPayload?(payload) }
        }
        if let data = dict["finished"] as? Data, let match = try? decoder.decode(Match.self, from: data) {
            Task { @MainActor in self.onFinished?(match) }
        }
    }

    private func reportReachability(_ session: WCSession) {
        let reachable = session.activationState == .activated && session.isReachable
        Task { @MainActor in self.onReachability?(reachable) }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        reportReachability(session)
        if activationState == .activated {
            handle(session.receivedApplicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        reportReachability(session)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Si cambian de reloj, volver a activar con el nuevo.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        reportReachability(session)
    }
    #endif
}
