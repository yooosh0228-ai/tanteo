import Foundation
import HealthKit
import Observation
import ScoreKit

/// Registra el partido como entrenamiento. Además de guardar tiempo, pulso y calorías en Salud,
/// mantiene la app en la pantalla del reloj mientras dura el partido (al bajar y subir la muñeca).
@MainActor
@Observable
final class WorkoutManager: NSObject {
    private(set) var heartRate: Double = 0
    private(set) var activeCalories: Double = 0
    private(set) var isRunning = false

    @ObservationIgnored private let healthStore = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var matchID: UUID?

    private var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard available else { return }
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        let read: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
        ]
        try? await healthStore.requestAuthorization(toShare: share, read: read)
    }

    /// Empieza a registrar el partido (si ya se registra ese mismo partido, no hace nada).
    func start(for match: Match) async {
        guard available, matchID != match.id else { return }
        if session != nil { end() }
        await requestAuthorization() // solo pregunta la primera vez

        let config = HKWorkoutConfiguration()
        config.activityType = match.config.sport == .padel ? .tennis : .other
        config.locationType = .unknown

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder
            self.matchID = match.id
            heartRate = 0
            activeCalories = 0

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)
            isRunning = true
        } catch {
            session = nil
            builder = nil
            matchID = nil
            isRunning = false
        }
    }

    /// Termina y guarda el entrenamiento en Salud.
    func end() {
        session?.end()
        matchID = nil
        isRunning = false
    }

    private func finish() async {
        guard let builder else { return }
        try? await builder.endCollection(at: Date())
        _ = try? await builder.finishWorkout()
        self.builder = nil
        self.session = nil
    }

    fileprivate func update(_ statistics: HKStatistics?) {
        guard let statistics else { return }
        switch statistics.quantityType {
        case HKQuantityType(.heartRate):
            let unit = HKUnit.count().unitDivided(by: .minute())
            heartRate = statistics.mostRecentQuantity()?.doubleValue(for: unit) ?? heartRate
        case HKQuantityType(.activeEnergyBurned):
            activeCalories = statistics.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? activeCalories
        default:
            break
        }
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        guard toState == .ended else { return }
        Task { @MainActor in await self.finish() }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.isRunning = false
            self.matchID = nil
        }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let stats = collectedTypes.compactMap { $0 as? HKQuantityType }.map { workoutBuilder.statistics(for: $0) }
        Task { @MainActor in
            for s in stats { self.update(s) }
        }
    }
}
