import CoreGraphics
import XCTest
@testable import CatchTheJewels

final class DifficultyAndSpawnTests: XCTestCase {
    // MARK: - Difficulty

    func testDifficultyStartsAtLevelZero() {
        let start = DifficultyCurve.difficulty(at: 0)
        XCTAssertEqual(start.level, 0)
        XCTAssertEqual(start.fallSpeed, DifficultyCurve.baseFallSpeed, accuracy: 1e-9)
        XCTAssertEqual(start.spawnInterval, DifficultyCurve.baseSpawnInterval, accuracy: 1e-9)
        XCTAssertEqual(start.patterns, [.single])
    }

    func testDifficultyIncreasesMonotonically() {
        var previous = DifficultyCurve.difficulty(forLevel: 0)
        for level in 1...DifficultyCurve.maxLevel {
            let next = DifficultyCurve.difficulty(forLevel: level)
            XCTAssertGreaterThanOrEqual(next.fallSpeed, previous.fallSpeed)
            XCTAssertLessThanOrEqual(next.spawnInterval, previous.spawnInterval)
            XCTAssertGreaterThanOrEqual(next.bombChance, previous.bombChance)
            XCTAssertGreaterThanOrEqual(next.patterns.count, previous.patterns.count)
            previous = next
        }
    }

    func testDifficultyLevelFollowsPlayTime() {
        XCTAssertEqual(DifficultyCurve.level(at: DifficultyCurve.secondsPerLevel - 0.01), 0)
        XCTAssertEqual(DifficultyCurve.level(at: DifficultyCurve.secondsPerLevel), 1)
        XCTAssertEqual(DifficultyCurve.level(at: DifficultyCurve.secondsPerLevel * 5.5), 5)
    }

    func testDifficultyIsCapped() {
        let extreme = DifficultyCurve.difficulty(at: 100_000)
        XCTAssertEqual(extreme.level, DifficultyCurve.maxLevel)
        XCTAssertLessThanOrEqual(extreme.fallSpeed, DifficultyCurve.maxFallSpeed)
        XCTAssertGreaterThanOrEqual(extreme.spawnInterval, DifficultyCurve.minSpawnInterval)
        XCTAssertLessThanOrEqual(extreme.bombChance, DifficultyCurve.maxBombChance)
        XCTAssertEqual(Set(extreme.patterns), Set(SpawnPattern.allCases))
        XCTAssertEqual(DifficultyCurve.level(at: -5), 0)
        XCTAssertEqual(DifficultyCurve.level(at: .nan), 0)
    }

    func testSessionDifficultyFollowsElapsedTime() {
        var session = GameSession(mode: .classic)
        session.advance(by: 3)
        session.advance(by: DifficultyCurve.secondsPerLevel * 3)
        XCTAssertEqual(session.difficulty.level, 3)
    }

    // MARK: - Spawning

    func testSameSeedProducesSameWaves() {
        var first = SpawnPlanner(seed: 42)
        var second = SpawnPlanner(seed: 42)
        let difficulty = DifficultyCurve.difficulty(forLevel: DifficultyCurve.maxLevel)
        for _ in 0..<200 {
            XCTAssertEqual(first.nextWave(difficulty: difficulty, canAwardHeart: true),
                           second.nextWave(difficulty: difficulty, canAwardHeart: true))
        }
    }

    func testDifferentSeedsProduceDifferentWaves() {
        var first = SpawnPlanner(seed: 1)
        var second = SpawnPlanner(seed: 2)
        let difficulty = DifficultyCurve.difficulty(forLevel: 6)
        let a = (0..<30).flatMap { _ in first.nextWave(difficulty: difficulty, canAwardHeart: false) }
        let b = (0..<30).flatMap { _ in second.nextWave(difficulty: difficulty, canAwardHeart: false) }
        XCTAssertNotEqual(a, b)
    }

    func testSpawnsStayWithinLaneAndUsePatternSizes() {
        var planner = SpawnPlanner(seed: 7)
        let difficulty = DifficultyCurve.difficulty(forLevel: DifficultyCurve.maxLevel)
        for _ in 0..<1_000 {
            let wave = planner.nextWave(difficulty: difficulty, canAwardHeart: true)
            XCTAssertTrue([1, 2, 3, 4].contains(wave.count))
            for request in wave {
                guard case .lane(let x) = request.placement else { return XCTFail("Unexpected placement") }
                XCTAssertTrue((0...1).contains(x))
                XCTAssertGreaterThanOrEqual(request.delay, 0)
                XCTAssertGreaterThan(request.speedMultiplier, 0)
            }
            XCTAssertLessThanOrEqual(wave.filter { $0.kind == .bomb }.count, 1, "At most one bomb per wave")
        }
    }

    func testEarlyGameOnlySpawnsSingles() {
        var planner = SpawnPlanner(seed: 3)
        let difficulty = DifficultyCurve.difficulty(forLevel: 0)
        for _ in 0..<200 {
            XCTAssertEqual(planner.nextWave(difficulty: difficulty, canAwardHeart: false).count, 1)
        }
    }

    func testHeartsOnlyWhenALifeIsMissing() {
        let difficulty = DifficultyCurve.difficulty(forLevel: 3)
        var withoutHearts = SpawnPlanner(seed: 9)
        let kinds = (0..<2_000).flatMap { _ in withoutHearts.nextWave(difficulty: difficulty, canAwardHeart: false) }.map(\.kind)
        XCTAssertFalse(kinds.contains(.heart))

        var withHearts = SpawnPlanner(seed: 9)
        let allowed = (0..<2_000).flatMap { _ in withHearts.nextWave(difficulty: difficulty, canAwardHeart: true) }.map(\.kind)
        XCTAssertTrue(allowed.contains(.heart))
    }

    func testAllJewelKindsAppear() {
        var planner = SpawnPlanner(seed: 11)
        let difficulty = DifficultyCurve.difficulty(forLevel: 0)
        var seen = Set<JewelKind>()
        for _ in 0..<2_000 {
            for request in planner.nextWave(difficulty: difficulty, canAwardHeart: false) {
                if case .jewel(let kind) = request.kind { seen.insert(kind) }
            }
        }
        XCTAssertEqual(seen, Set(JewelKind.allCases))
    }

    func testBombsOnlyScenarioTargetsCatcher() {
        var planner = SpawnPlanner(seed: 1, scenario: .bombsOnly)
        let wave = planner.nextWave(difficulty: DifficultyCurve.difficulty(forLevel: 0), canAwardHeart: true)
        XCTAssertEqual(wave.map(\.kind), [.bomb])
        XCTAssertEqual(wave.first?.placement, .aboveCatcher)
    }

    // MARK: - Geometry

    func testSpawnPositionsAreAlwaysInsidePlayfield() {
        let width: CGFloat = 375
        let radius: CGFloat = 20
        for fraction in stride(from: -0.5, through: 1.5, by: 0.05) {
            let x = GameGeometry.spawnX(fraction: fraction, playfieldWidth: width, objectRadius: radius)
            XCTAssertGreaterThanOrEqual(x - radius, 0)
            XCTAssertLessThanOrEqual(x + radius, width)
        }
    }

    func testCatcherIsClampedToScreen() {
        let width: CGFloat = 400
        XCTAssertEqual(GameGeometry.clampCatcherX(-100, catcherWidth: 100, playfieldWidth: width), 50)
        XCTAssertEqual(GameGeometry.clampCatcherX(1_000, catcherWidth: 100, playfieldWidth: width), 350)
        XCTAssertEqual(GameGeometry.clampCatcherX(200, catcherWidth: 100, playfieldWidth: width), 200)
    }

    func testCollisionDetection() {
        let zone = CGRect(x: 100, y: 100, width: 100, height: 40)
        XCTAssertTrue(GameGeometry.intersects(center: CGPoint(x: 150, y: 120), radius: 5, zone: zone))
        XCTAssertTrue(GameGeometry.intersects(center: CGPoint(x: 150, y: 150), radius: 12, zone: zone), "Touching the top edge")
        XCTAssertFalse(GameGeometry.intersects(center: CGPoint(x: 150, y: 160), radius: 12, zone: zone))
        XCTAssertFalse(GameGeometry.intersects(center: CGPoint(x: 80, y: 120), radius: 10, zone: zone))
        XCTAssertFalse(GameGeometry.intersects(center: CGPoint(x: 92, y: 92), radius: 10, zone: zone), "Corner gap")
    }

    func testSizesScaleWithinBounds() {
        let phone = CGSize(width: 320, height: 568)
        let pad = CGSize(width: 1366, height: 1024)
        XCTAssertGreaterThanOrEqual(GameGeometry.catcherWidth(for: phone, enlarged: false), 84)
        XCTAssertLessThanOrEqual(GameGeometry.catcherWidth(for: pad, enlarged: false), 150)
        XCTAssertGreaterThan(GameGeometry.catcherWidth(for: phone, enlarged: true), GameGeometry.catcherWidth(for: phone, enlarged: false))
        XCTAssertGreaterThanOrEqual(GameGeometry.objectRadius(for: phone), 17)
        XCTAssertLessThanOrEqual(GameGeometry.objectRadius(for: pad), 32)
    }

    func testTiltNormalisation() {
        XCTAssertEqual(TiltInput.normalizedTilt(0.01), 0)
        XCTAssertEqual(TiltInput.normalizedTilt(-0.02), 0)
        XCTAssertEqual(TiltInput.normalizedTilt(1), 1)
        XCTAssertEqual(TiltInput.normalizedTilt(-1), -1)
        let half = TiltInput.normalizedTilt((TiltInput.deadZone + TiltInput.fullTilt) / 2)
        XCTAssertEqual(half, 0.5, accuracy: 1e-9)
    }
}
