import Foundation
import Observation
import ScoreKit

/// Estado de la app (igual en el reloj y en el iPhone): partido en curso, historial y sincronización.
@MainActor
@Observable
final class MatchStore {
    private(set) var current: Match?
    private(set) var history: [Match] = []
    private(set) var otherDeviceReachable = false
    /// Última configuración usada, para no tener que elegir todo cada vez.
    var lastConfig: MatchConfig

    @ObservationIgnored private let sync = SyncService()
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("tanteo.json")
        lastConfig = MatchConfig()
        load()

        sync.onPayload = { [weak self] payload in self?.receive(payload) }
        sync.onFinished = { [weak self] match in self?.archive(match, notify: false) }
        sync.onReachability = { [weak self] reachable in self?.otherDeviceReachable = reachable }
        sync.activate()
    }

    // MARK: - Acciones

    func start(config: MatchConfig, firstServer: Team) {
        lastConfig = config
        current = Match(config: config, firstServer: firstServer)
        commit()
    }

    func point(_ team: Team) {
        guard var m = current else { return }
        m.addPoint(to: team)
        current = m
        commit()
    }

    func undo() {
        guard var m = current else { return }
        m.undo()
        current = m
        commit()
    }

    func setServer(_ team: Team) {
        guard var m = current else { return }
        m.setServer(team)
        current = m
        commit()
    }

    /// Cierra el partido en curso. Si tuvo al menos un punto, queda en el historial.
    func endMatch() {
        guard var m = current else { return }
        m.markEnded()
        current = nil
        if !m.pointLog.isEmpty { archive(m, notify: true) }
        save()
        sync.send(SyncPayload(match: nil, clearedMatchID: m.id, sentAt: Date()))
    }

    func deleteFromHistory(_ ids: Set<UUID>) {
        history.removeAll { ids.contains($0.id) }
        save()
    }

    // MARK: - Sincronización

    private func commit() {
        save()
        sync.send(SyncPayload(match: current, clearedMatchID: nil, sentAt: Date()))
    }

    private func receive(_ payload: SyncPayload) {
        if let cleared = payload.clearedMatchID {
            if let m = current, m.id == cleared, payload.sentAt >= m.updatedAt {
                current = nil
                save()
            }
            return
        }
        guard let incoming = payload.match else { return }
        if let local = current, local.updatedAt >= incoming.updatedAt { return }
        if history.contains(where: { $0.id == incoming.id }) { return }
        current = incoming
        lastConfig = incoming.config
        save()
    }

    private func archive(_ match: Match, notify: Bool) {
        history.removeAll { $0.id == match.id }
        history.insert(match, at: 0)
        if let m = current, m.id == match.id { current = nil }
        save()
        if notify { sync.sendFinished(match) }
    }

    // MARK: - Guardado

    private struct Saved: Codable {
        var current: Match?
        var history: [Match]
        var lastConfig: MatchConfig
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        current = saved.current
        history = saved.history
        lastConfig = saved.lastConfig
    }

    private func save() {
        let saved = Saved(current: current, history: history, lastConfig: lastConfig)
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
