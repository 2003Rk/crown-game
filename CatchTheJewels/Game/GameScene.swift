import SpriteKit
import UIKit

/// Renders and simulates the falling-jewel playfield.
///
/// Time is advanced manually in `update(_:)` (no repeating SKActions or timers), so
/// pausing simply stops the clock and there is only ever one game loop per scene.
@MainActor
final class GameScene: SKScene {
    /// Largest simulation step. Longer frames (e.g. after a hitch) are clamped so
    /// objects can't tunnel through the catcher.
    static let maxStep: TimeInterval = 1.0 / 30.0
    /// Catcher speed at full tilt, in screen widths per second.
    static let tiltSpeed: CGFloat = 1.5
    /// Gap between the catcher's base and the bottom safe-area edge.
    static let catcherBottomPadding: CGFloat = 18
    /// Darkens the stage artwork so falling objects stand out clearly.
    static let backgroundScrimAlpha: CGFloat = 0.4

    weak var controller: GameController?

    private let textures = TextureCache()
    private let backgroundNode = SKSpriteNode()
    private let scrimNode = SKSpriteNode(color: .black, size: .zero)
    private lazy var stageTexture: SKTexture? = UIImage(named: Theme.Assets.background).map { SKTexture(image: $0) }
    private let playLayer = SKNode()
    private let itemLayer = SKNode()
    private let effectsLayer = SKNode()
    private let catcher = CatcherNode()
    private var ambientMotes: SKEmitterNode?

    private var items: [FallingItemNode] = []
    private var pendingSpawns: [(remaining: TimeInterval, request: SpawnRequest)] = []
    private var planner = SpawnPlanner(seed: 0)
    private var spawnClock: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private var safeInsets: UIEdgeInsets = .zero
    private var isSetUp = false
    private let tilt = TiltInput()

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.02, green: 0.13, blue: 0.09, alpha: 1)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        nil
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        setUpIfNeeded()
        layoutPlayfield()
        applySettings()
    }

    override func willMove(from view: SKView) {
        tilt.stop()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard isSetUp, size != oldSize else { return }
        layoutPlayfield()
    }

    private func setUpIfNeeded() {
        guard !isSetUp else { return }
        isSetUp = true
        backgroundNode.zPosition = -10
        addChild(backgroundNode)
        scrimNode.anchorPoint = .zero
        scrimNode.alpha = Self.backgroundScrimAlpha
        scrimNode.zPosition = -9
        addChild(scrimNode)
        addChild(playLayer)
        playLayer.addChild(itemLayer)
        playLayer.addChild(catcher)
        catcher.zPosition = 5
        effectsLayer.zPosition = 10
        addChild(effectsLayer)
    }

    /// Positions everything for the current size and safe area.
    private func layoutPlayfield() {
        guard size.width > 0, size.height > 0 else { return }
        layoutBackground()

        let enlarged = controller?.settings.largerCatcher ?? false
        catcher.configure(width: GameGeometry.catcherWidth(for: size, enlarged: enlarged), textures: textures)
        catcher.position = CGPoint(
            x: GameGeometry.clampCatcherX(catcher.position.x == 0 ? size.width / 2 : catcher.position.x,
                                          catcherWidth: catcher.size.width, playfieldWidth: size.width),
            y: safeInsets.bottom + Self.catcherBottomPadding + catcher.size.height / 2
        )

        for item in items {
            item.position.x = min(size.width - item.radius, max(item.radius, item.position.x))
        }
        configureAmbientMotes()
    }

    /// Aspect-fills the stage artwork, falling back to the painted gradient if the
    /// image can't be loaded.
    private func layoutBackground() {
        backgroundNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        if let stage = stageTexture, stage.size().width > 0, stage.size().height > 0 {
            let scale = max(size.width / stage.size().width, size.height / stage.size().height)
            backgroundNode.texture = stage
            backgroundNode.size = CGSize(width: stage.size().width * scale, height: stage.size().height * scale)
        } else {
            backgroundNode.texture = SKTexture(image: ArtworkRenderer.backgroundImage(size: size))
            backgroundNode.size = size
        }
        scrimNode.size = size
    }

    func updateSafeInsets(_ insets: UIEdgeInsets) {
        guard insets != safeInsets else { return }
        safeInsets = insets
        layoutPlayfield()
    }

    /// Re-reads player settings (larger catcher, tilt, reduced motion).
    func applySettings() {
        guard let controller else { return }
        if controller.settings.tiltControlsEnabled {
            tilt.start()
        } else {
            tilt.stop()
        }
        layoutPlayfield()
    }

    /// Clears the playfield for a new run.
    func resetRun(seed: UInt64, scenario: GameScenario) {
        items.forEach { $0.removeFromParent() }
        items.removeAll()
        pendingSpawns.removeAll()
        effectsLayer.removeAllChildren()
        planner = SpawnPlanner(seed: seed, scenario: scenario)
        spawnClock = DifficultyCurve.baseSpawnInterval * 0.6
        lastUpdateTime = nil
        catcher.resetAppearance()
        catcher.position.x = size.width / 2
        playLayer.position = .zero
        playLayer.removeAllActions()
    }

    /// Freezes remaining objects once the run is over.
    func runDidEnd() {
        tilt.stop()
        pendingSpawns.removeAll()
    }

    func tearDown() {
        tilt.stop()
        removeAllActions()
        items.removeAll()
        pendingSpawns.removeAll()
        removeAllChildren()
        textures.removeAll()
        controller = nil
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        guard let controller, controller.acceptsTime else {
            // Paused or finished: drop the clock so resuming doesn't jump forward.
            lastUpdateTime = nil
            return
        }
        let delta = lastUpdateTime.map { min(Self.maxStep, max(0, currentTime - $0)) } ?? 0
        lastUpdateTime = currentTime
        guard delta > 0 else { return }

        applyTilt(delta)
        controller.advance(by: delta)
        guard controller.isPlaying else { return }

        let difficulty = controller.session.difficulty
        scheduleWaves(delta, difficulty: difficulty)
        releasePendingSpawns(delta)
        moveItems(delta, difficulty: difficulty)
    }

    private func scheduleWaves(_ delta: TimeInterval, difficulty: Difficulty) {
        guard let controller else { return }
        spawnClock += delta
        guard spawnClock >= difficulty.spawnInterval else { return }
        spawnClock -= difficulty.spawnInterval
        let canAwardHeart = controller.session.lives < controller.session.config.maxLives
        for request in planner.nextWave(difficulty: difficulty, canAwardHeart: canAwardHeart) {
            pendingSpawns.append((request.delay, request))
        }
    }

    private func releasePendingSpawns(_ delta: TimeInterval) {
        guard !pendingSpawns.isEmpty else { return }
        var remaining: [(remaining: TimeInterval, request: SpawnRequest)] = []
        for var pending in pendingSpawns {
            pending.remaining -= delta
            if pending.remaining <= 0 {
                spawn(pending.request)
            } else {
                remaining.append(pending)
            }
        }
        pendingSpawns = remaining
    }

    private func spawn(_ request: SpawnRequest) {
        let radius = GameGeometry.objectRadius(for: size)
        let x: CGFloat
        switch request.placement {
        case .lane(let fraction):
            x = GameGeometry.spawnX(fraction: fraction, playfieldWidth: size.width, objectRadius: radius)
        case .aboveCatcher:
            x = catcher.position.x
        }
        let artwork = ArtworkKind(request.kind)
        let textureHeight = radius * 2 / FallingItemNode.artworkFill
        let reduceMotion = controller?.reduceMotion ?? false
        let spin: CGFloat = reduceMotion ? 0 : CGFloat.random(in: -1.2...1.2)
        let node = FallingItemNode(kind: request.kind, radius: radius,
                                   texture: textures.texture(artwork, height: textureHeight),
                                   speedMultiplier: request.speedMultiplier, spin: spin)
        node.position = CGPoint(x: x, y: size.height + radius)
        node.zPosition = request.kind.isHazard ? 2 : 1
        node.accessibilityLabel = request.kind.accessibilityName
        itemLayer.addChild(node)
        items.append(node)
    }

    private func moveItems(_ delta: TimeInterval, difficulty: Difficulty) {
        guard let controller else { return }
        let zone = catcher.catchZone
        var survivors: [FallingItemNode] = []
        survivors.reserveCapacity(items.count)

        for item in items {
            let distance = CGFloat(difficulty.fallSpeed * item.speedMultiplier * delta) * size.height
            item.position.y -= distance
            item.zRotation += item.spin * CGFloat(delta)

            if GameGeometry.intersects(center: item.position, radius: item.radius * 0.9, zone: zone) {
                let outcome = controller.register(item.kind)
                showEffect(for: outcome, at: item.position)
                item.removeFromParent()
                if !controller.isPlaying { break }
                continue
            }
            if item.position.y < -item.radius {
                controller.registerMiss(item.kind)
                if case .jewel = item.kind { showMissPuff(at: CGPoint(x: item.position.x, y: 6)) }
                item.removeFromParent()
                continue
            }
            survivors.append(item)
        }
        if controller.isPlaying {
            items = survivors
        } else {
            // The run just ended mid-loop; keep remaining objects visible but frozen.
            items = items.filter { $0.parent != nil }
        }
    }

    // MARK: - Input

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let controller, controller.acceptsTime else { return }
        let current = touch.location(in: self)
        let previous = touch.previousLocation(in: self)
        let sensitivity = CGFloat(controller.settings.effectiveSensitivity)
        moveCatcher(by: (current.x - previous.x) * sensitivity)
    }

    private func applyTilt(_ delta: TimeInterval) {
        guard let controller, controller.settings.tiltControlsEnabled, tilt.isAvailable else { return }
        let orientation = view?.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let amount = tilt.horizontalTilt(for: orientation)
        guard amount != 0 else { return }
        let sensitivity = CGFloat(controller.settings.effectiveSensitivity)
        moveCatcher(by: CGFloat(amount) * Self.tiltSpeed * size.width * sensitivity * CGFloat(delta))
    }

    private func moveCatcher(by dx: CGFloat) {
        catcher.position.x = GameGeometry.clampCatcherX(catcher.position.x + dx,
                                                        catcherWidth: catcher.size.width,
                                                        playfieldWidth: size.width)
    }

    // MARK: - Effects

    private func showEffect(for outcome: CatchOutcome, at point: CGPoint) {
        let reduceMotion = controller?.reduceMotion ?? false
        switch outcome {
        case .jewel(let kind, let points, let multiplier):
            catcher.celebrate(reduceMotion: reduceMotion)
            burst(at: point, color: UIColor(artColor: ArtPalette.color(for: kind)),
                  count: reduceMotion ? 6 : (kind == .gold ? 34 : 20), speed: 150)
            if kind == .gold && !reduceMotion {
                burst(at: point, color: .white, count: 14, speed: 240)
            }
            let text = multiplier > 1 ? "+\(points)  ×\(multiplier)" : "+\(points)"
            floatingLabel(text, at: point, color: UIColor(artColor: ArtPalette.goldLight), reduceMotion: reduceMotion)

        case .bomb(let livesRemaining):
            burst(at: point, color: UIColor(red: 1, green: 0.45, blue: 0.15, alpha: 1), count: reduceMotion ? 10 : 40, speed: 260)
            burst(at: point, color: UIColor(white: 0.35, alpha: 1), count: reduceMotion ? 4 : 16, speed: 120)
            floatingLabel(livesRemaining > 0 ? "−1 Life" : "Out of lives", at: point,
                          color: UIColor(red: 1, green: 0.5, blue: 0.5, alpha: 1), reduceMotion: reduceMotion)
            catcher.showHit(duration: controller?.session.config.invulnerabilityDuration ?? 1.2, reduceMotion: reduceMotion)
            flashScreen(reduceMotion: reduceMotion)
            if !reduceMotion { shake() }

        case .bombBlocked:
            burst(at: point, color: UIColor(white: 0.8, alpha: 1), count: 8, speed: 100)

        case .lifeRestored:
            burst(at: point, color: UIColor(artColor: ArtPalette.heart), count: reduceMotion ? 6 : 24, speed: 160)
            floatingLabel("+1 Life", at: point, color: UIColor(artColor: ArtPalette.heart.lighter(0.3)), reduceMotion: reduceMotion)

        case .heartBonus(let points):
            burst(at: point, color: UIColor(artColor: ArtPalette.heart), count: reduceMotion ? 6 : 24, speed: 160)
            floatingLabel("+\(points)", at: point, color: UIColor(artColor: ArtPalette.goldLight), reduceMotion: reduceMotion)

        case .ignored:
            break
        }
    }

    private func burst(at point: CGPoint, color: UIColor, count: Int, speed: CGFloat) {
        let emitter = SKEmitterNode()
        emitter.particleTexture = textures.texture(.spark, height: 32)
        emitter.position = point
        emitter.numParticlesToEmit = count
        emitter.particleBirthRate = CGFloat(count) * 20
        emitter.particleLifetime = 0.55
        emitter.particleLifetimeRange = 0.25
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.5
        emitter.yAcceleration = -260
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -1.8
        emitter.particleScale = 0.45
        emitter.particleScaleRange = 0.2
        emitter.particleScaleSpeed = -0.6
        emitter.particleColor = color
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.zPosition = 20
        effectsLayer.addChild(emitter)
        emitter.run(.sequence([.wait(forDuration: 1.0), .removeFromParent()]))
    }

    private func showMissPuff(at point: CGPoint) {
        let reduceMotion = controller?.reduceMotion ?? false
        burst(at: point, color: UIColor(white: 0.75, alpha: 0.6), count: reduceMotion ? 3 : 8, speed: 60)
    }

    private func floatingLabel(_ text: String, at point: CGPoint, color: UIColor, reduceMotion: Bool) {
        let label = SKLabelNode(text: text)
        label.fontName = UIFont.systemFont(ofSize: 20, weight: .heavy).fontName
        label.fontSize = max(18, min(28, size.width * 0.05))
        label.fontColor = color
        label.position = CGPoint(x: min(size.width - 50, max(50, point.x)), y: point.y + 24)
        label.zPosition = 30
        label.verticalAlignmentMode = .center
        effectsLayer.addChild(label)
        let rise: SKAction = reduceMotion ? .wait(forDuration: 0.6) : .moveBy(x: 0, y: 60, duration: 0.7)
        label.run(.sequence([.group([rise, .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
    }

    private func flashScreen(reduceMotion: Bool) {
        let flash = SKSpriteNode(color: UIColor(red: 1, green: 0.15, blue: 0.2, alpha: 1), size: size)
        flash.anchorPoint = .zero
        flash.alpha = reduceMotion ? 0.12 : 0.22
        flash.zPosition = 40
        effectsLayer.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
    }

    private func shake() {
        playLayer.removeAction(forKey: "shake")
        playLayer.position = .zero
        let offsets: [CGFloat] = [8, -7, 5, -4, 2, 0]
        let moves = offsets.map { SKAction.move(to: CGPoint(x: $0, y: 0), duration: 0.035) }
        playLayer.run(.sequence(moves), withKey: "shake")
    }

    private func configureAmbientMotes() {
        let reduceMotion = controller?.reduceMotion ?? false
        if reduceMotion {
            ambientMotes?.removeFromParent()
            ambientMotes = nil
            return
        }
        let motes = ambientMotes ?? SKEmitterNode()
        if ambientMotes == nil {
            motes.particleTexture = textures.texture(.spark, height: 32)
            motes.particleBirthRate = 3
            motes.particleLifetime = 9
            motes.particleSpeed = 22
            motes.particleSpeedRange = 12
            motes.emissionAngle = .pi / 2
            motes.emissionAngleRange = 0.5
            motes.particleAlpha = 0.35
            motes.particleAlphaRange = 0.2
            motes.particleAlphaSpeed = -0.03
            motes.particleScale = 0.12
            motes.particleScaleRange = 0.08
            motes.particleColor = UIColor(artColor: ArtPalette.gold)
            motes.particleColorBlendFactor = 1
            motes.particleBlendMode = .add
            motes.zPosition = -5
            addChild(motes)
            ambientMotes = motes
            motes.advanceSimulationTime(9)
        }
        motes.position = CGPoint(x: size.width / 2, y: 0)
        motes.particlePositionRange = CGVector(dx: size.width, dy: 0)
    }
}

extension UIColor {
    convenience init(artColor: ArtColor, alpha: CGFloat = 1) {
        self.init(red: artColor.r, green: artColor.g, blue: artColor.b, alpha: alpha)
    }
}
