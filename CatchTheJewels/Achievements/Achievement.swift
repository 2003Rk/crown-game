import Foundation

/// Locally tracked milestones. Purely cosmetic: they award nothing but bragging rights.
/// Every achievement is evaluated from saved `PlayerProgress`, so progress bars and
/// unlocks always agree with the statistics shown elsewhere.
enum Achievement: String, CaseIterable, Codable, Identifiable {
    case firstCatch
    case jewelCollector
    case royalCollector
    case scoreStarter
    case highScorer
    case survivor
    case dailyChampion
    case dedicatedPlayer
    case chainOfGems
    case midasTouch
    case flawlessReign
    case crownJewel
    case sovereign
    case dailyDevotion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstCatch: return "First Catch"
        case .jewelCollector: return "Jewel Collector"
        case .royalCollector: return "Royal Collector"
        case .scoreStarter: return "Score Starter"
        case .highScorer: return "High Scorer"
        case .survivor: return "Survivor"
        case .dailyChampion: return "Daily Champion"
        case .dedicatedPlayer: return "Dedicated Player"
        case .chainOfGems: return "Chain of Gems"
        case .midasTouch: return "Midas Touch"
        case .flawlessReign: return "Flawless Reign"
        case .crownJewel: return "Crown Jewel"
        case .sovereign: return "Sovereign"
        case .dailyDevotion: return "Daily Devotion"
        }
    }

    var detail: String {
        switch self {
        case .firstCatch: return "Collect your first jewel."
        case .jewelCollector: return "Collect 100 jewels in total."
        case .royalCollector: return "Collect 500 jewels in total."
        case .scoreStarter: return "Reach 100 points in a single run."
        case .highScorer: return "Reach 500 points in a single run."
        case .survivor: return "Finish a Time or Daily Challenge without losing a life."
        case .dailyChampion: return "Complete a Daily Challenge."
        case .dedicatedPlayer: return "Finish 10 games."
        case .chainOfGems: return "Catch 20 jewels in a row."
        case .midasTouch: return "Catch 10 Gold Stars in one run."
        case .flawlessReign: return "Score 1,000 points before losing a life."
        case .crownJewel: return "Reach 2,500 points in a single run."
        case .sovereign: return "Reach 5,000 points in a single run."
        case .dailyDevotion: return "Complete 7 Daily Challenges."
        }
    }

    /// SF Symbol shown on the achievement badge.
    var symbol: String {
        switch self {
        case .firstCatch: return "sparkle"
        case .jewelCollector: return "diamond.fill"
        case .royalCollector: return "shippingbox.fill"
        case .scoreStarter: return "star.fill"
        case .highScorer: return "star.circle.fill"
        case .survivor: return "shield.fill"
        case .dailyChampion: return "calendar.badge.checkmark"
        case .dedicatedPlayer: return "gamecontroller.fill"
        case .chainOfGems: return "link"
        case .midasTouch: return "sun.max.fill"
        case .flawlessReign: return "heart.circle.fill"
        case .crownJewel: return "crown.fill"
        case .sovereign: return "rosette"
        case .dailyDevotion: return "calendar"
        }
    }

    /// The statistic that drives this achievement and the value needed.
    func requirement(_ progress: PlayerProgress) -> (current: Int, target: Int) {
        switch self {
        case .firstCatch: return (progress.totalJewels, 1)
        case .jewelCollector: return (progress.totalJewels, 100)
        case .royalCollector: return (progress.totalJewels, 500)
        case .scoreStarter: return (progress.highestScore, 100)
        case .highScorer: return (progress.highestScore, 500)
        case .survivor: return (progress.hasSurvivedRun ? 1 : 0, 1)
        case .dailyChampion: return (progress.dailyChallengesCompleted, 1)
        case .dedicatedPlayer: return (progress.gamesPlayed, 10)
        case .chainOfGems: return (progress.bestCombo, 20)
        case .midasTouch: return (progress.bestGoldInRun, 10)
        case .flawlessReign: return (progress.bestFlawlessScore, 1_000)
        case .crownJewel: return (progress.highestScore, 2_500)
        case .sovereign: return (progress.highestScore, 5_000)
        case .dailyDevotion: return (progress.dailyChallengesCompleted, 7)
        }
    }

    func isEarned(_ progress: PlayerProgress) -> Bool {
        let requirement = requirement(progress)
        return requirement.current >= requirement.target
    }

    /// Progress capped at the target, for progress bars.
    func displayProgress(_ progress: PlayerProgress) -> (current: Int, target: Int) {
        let requirement = requirement(progress)
        return (min(requirement.current, requirement.target), requirement.target)
    }

    func fractionComplete(_ progress: PlayerProgress) -> Double {
        let value = displayProgress(progress)
        return Double(value.current) / Double(max(1, value.target))
    }

    /// True for yes/no achievements that don't need a numeric progress bar.
    var isBinary: Bool {
        switch self {
        case .firstCatch, .survivor, .dailyChampion: return true
        default: return false
        }
    }
}
