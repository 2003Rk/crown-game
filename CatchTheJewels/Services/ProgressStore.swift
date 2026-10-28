import Foundation
import Observation
import os

/// What changed when a finished run was recorded.
struct RunSummary: Equatable {
    let result: GameResult
    let previousBest: Int
    let isNewBest: Bool
    let newlyUnlocked: [Achievement]
    /// Non-nil for daily runs.
    let dailyCompleted: Bool?
    /// True only the first time today's challenge is completed.
    let dailyCompletedForFirstTime: Bool
    /// False if this run had already been recorded and was ignored.
    var wasRecorded = true
}

/// Owns the player's lifetime progress and saves it as a single JSON document.
@MainActor
@Observable
final class ProgressStore {
    static let storageKey = "progress.v1"

    private(set) var progress: PlayerProgress

    @ObservationIgnored private let store: KeyValueStore
    @ObservationIgnored private let logger = Logger(subsystem: "CatchTheJewels", category: "Progress")

    init(store: KeyValueStore) {
        self.store = store
        progress = Self.load(from: store)
    }

    private static func load(from store: KeyValueStore) -> PlayerProgress {
        guard let data: Data = store.typedValue(forKey: storageKey) else { return PlayerProgress() }
        do {
            return try JSONDecoder().decode(PlayerProgress.self, from: data).sanitized()
        } catch {
            // Unreadable save: start fresh rather than crash. Nothing personal is lost.
            Logger(subsystem: "CatchTheJewels", category: "Progress").error("Discarding unreadable progress: \(error.localizedDescription)")
            return PlayerProgress()
        }
    }

    private func save() {
        do {
            store.set(try JSONEncoder().encode(progress), forKey: Self.storageKey)
        } catch {
            logger.error("Failed to save progress: \(error.localizedDescription)")
        }
    }

    // MARK: - Queries

    func dailyRecord(for challenge: DailyChallenge) -> PlayerProgress.DailyRecord {
        progress.dailyRecords[challenge.dateKey] ?? PlayerProgress.DailyRecord()
    }

    func bestScore(for mode: GameMode) -> Int {
        switch mode {
        case .classic: return progress.bestScore
        case .timeChallenge: return progress.bestTimeChallengeScore
        case .daily(let challenge): return dailyRecord(for: challenge).bestScore
        }
    }

    // MARK: - Recording

    /// Records a finished run. Calling it again with the same run is a no-op, so a
    /// run can never be counted twice.
    @discardableResult
    func record(_ result: GameResult, at date: Date = Date()) -> RunSummary {
        let previousBest = bestScore(for: result.mode)
        guard progress.lastRecordedRunID != result.runID else {
            return RunSummary(result: result, previousBest: previousBest, isNewBest: false, newlyUnlocked: [],
                              dailyCompleted: nil, dailyCompletedForFirstTime: false, wasRecorded: false)
        }

        var updated = progress.merging(result, completed: true)
        updated.lastRecordedRunID = result.runID
        updated.lastRun = RunRecord(mode: result.mode.kind, score: result.score, jewels: result.jewelsCaught,
                                    maxCombo: result.maxCombo, duration: result.duration, date: date)

        var dailyCompleted: Bool?
        var firstDailyCompletion = false
        if case .daily(let challenge) = result.mode {
            var record = updated.dailyRecords[challenge.dateKey] ?? PlayerProgress.DailyRecord()
            record.bestScore = max(record.bestScore, result.score)
            let completedNow = challenge.isCompleted(by: result)
            // Each day's challenge counts toward totals and achievements only once.
            if completedNow && !record.completed {
                record.completed = true
                updated.dailyChallengesCompleted += 1
                firstDailyCompletion = true
            }
            updated.dailyRecords[challenge.dateKey] = record
            updated.pruneDailyRecords()
            dailyCompleted = completedNow
        }

        let newlyUnlocked = updated.pendingAchievements
        for achievement in newlyUnlocked {
            updated.unlockedAchievements[achievement.rawValue] = date
        }

        progress = updated
        save()

        return RunSummary(
            result: result,
            previousBest: previousBest,
            isNewBest: result.score > previousBest && result.score > 0,
            newlyUnlocked: newlyUnlocked,
            dailyCompleted: dailyCompleted,
            dailyCompletedForFirstTime: firstDailyCompletion
        )
    }

    /// Unlocks achievements already earned by a run that is still in progress (e.g.
    /// First Catch), so the player sees them the moment they happen. The run's
    /// statistics are not saved until `record(_:)`.
    func unlockAchievements(duringRun result: GameResult, at date: Date = Date()) -> [Achievement] {
        let earned = progress.merging(result, completed: false).pendingAchievements
        guard !earned.isEmpty else { return [] }
        var updated = progress
        for achievement in earned {
            updated.unlockedAchievements[achievement.rawValue] = date
        }
        progress = updated
        save()
        return earned
    }

    /// Erases game progress only: scores, statistics, achievements and daily records.
    /// Preferences and the player's nickname and avatar are kept.
    func resetAll() {
        progress = PlayerProgress()
        store.removeObject(forKey: Self.storageKey)
    }
}
