import Cocoa
import ServiceManagement

// MARK: - Settings

enum TrailEffect: String {
    case line
    case comet
    case sparkles
}

enum ColorMode: String {
    case rainbow
    case solid
}

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var effect: TrailEffect {
        get { TrailEffect(rawValue: defaults.string(forKey: "effect") ?? "") ?? .line }
        set { defaults.set(newValue.rawValue, forKey: "effect") }
    }

    var colorMode: ColorMode {
        get {
            // Fall back to the pre-1.1 "style" key so existing prefs carry over.
            let raw = defaults.string(forKey: "colorMode") ?? defaults.string(forKey: "style") ?? ""
            return ColorMode(rawValue: raw) ?? .rainbow
        }
        set { defaults.set(newValue.rawValue, forKey: "colorMode") }
    }

    var solidColorName: String {
        get { defaults.string(forKey: "solidColorName") ?? "White" }
        set { defaults.set(newValue, forKey: "solidColorName") }
    }

    var customColor: NSColor {
        get {
            if let data = defaults.data(forKey: "customColor"),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return NSColor(calibratedRed: 0.0, green: 0.9, blue: 0.9, alpha: 1)
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                defaults.set(data, forKey: "customColor")
            }
        }
    }

    var thickness: CGFloat {
        get {
            let v = defaults.double(forKey: "thickness")
            return v > 0 ? CGFloat(v) : 6
        }
        set { defaults.set(Double(newValue), forKey: "thickness") }
    }

    /// Seconds a trail segment takes to fade out completely.
    var duration: Double {
        get {
            let v = defaults.double(forKey: "duration")
            return v > 0 ? v : 0.6
        }
        set { defaults.set(newValue, forKey: "duration") }
    }

    var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    static let solidColors: [(name: String, color: NSColor)] = [
        ("White",  .white),
        ("Black",  .black),
        ("Red",    NSColor(calibratedRed: 1.00, green: 0.27, blue: 0.23, alpha: 1)),
        ("Orange", NSColor(calibratedRed: 1.00, green: 0.58, blue: 0.00, alpha: 1)),
        ("Yellow", NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.04, alpha: 1)),
        ("Green",  NSColor(calibratedRed: 0.20, green: 0.84, blue: 0.29, alpha: 1)),
        ("Blue",   NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.00, alpha: 1)),
        ("Purple", NSColor(calibratedRed: 0.75, green: 0.35, blue: 0.95, alpha: 1)),
        ("Pink",   NSColor(calibratedRed: 1.00, green: 0.37, blue: 0.65, alpha: 1)),
    ]

    var solidColor: NSColor {
        if solidColorName == "Custom" { return customColor }
        return Settings.solidColors.first(where: { $0.name == solidColorName })?.color ?? .white
    }

    /// Trail color for something born at `time`, before fade is applied.
    func color(at time: CFTimeInterval, hueJitter: CGFloat = 0) -> NSColor {
        switch colorMode {
        case .rainbow:
            var hue = CGFloat(fmod(time * 0.4, 1.0)) + hueJitter
            hue = hue.truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
            return NSColor(hue: hue, saturation: 0.9, brightness: 1.0, alpha: 1)
        case .solid:
            return solidColor
        }
    }
}

// MARK: - Trail model

struct TrailPoint {
    var position: CGPoint   // global screen coordinates (bottom-left origin)
    var time: CFTimeInterval
}

struct Sparkle {
    var position: CGPoint
    var velocity: CGVector
    var birth: CFTimeInterval
    var lifetime: CFTimeInterval
    var size: CGFloat
    var hueJitter: CGFloat
    var twinklePhase: CGFloat
}

final class TrailModel {
    static let shared = TrailModel()
    private(set) var points: [TrailPoint] = []
    private(set) var sparkles: [Sparkle] = []
    private var lastPosition: CGPoint?
    private var lastTick: CFTimeInterval?

    var isEmpty: Bool { points.isEmpty && sparkles.isEmpty }

    func tick() {
        let now = CACurrentMediaTime()
        let dt = min(0.05, now - (lastTick ?? now))
        lastTick = now

        let settings = Settings.shared
        let location = NSEvent.mouseLocation

        // Only record movement when the cursor actually moved a little, so an
        // idle cursor doesn't accumulate points.
        let moved = hypot(location.x - (lastPosition?.x ?? location.x - 1),
                          location.y - (lastPosition?.y ?? location.y - 1))
        if lastPosition == nil || moved > 0.5 {
            if settings.effect == .sparkles, let last = lastPosition {
                spawnSparkles(from: last, to: location, distance: moved, now: now)
            }
            points.append(TrailPoint(position: location, time: now))
            lastPosition = location
        }

        let lifetime = settings.duration
        points.removeAll { now - $0.time > lifetime }

        // Advance sparkle physics: drift, slight gravity, damping.
        for i in sparkles.indices {
            sparkles[i].position.x += sparkles[i].velocity.dx * dt
            sparkles[i].position.y += sparkles[i].velocity.dy * dt
            sparkles[i].velocity.dy -= 55 * dt
            sparkles[i].velocity.dx *= (1 - 1.2 * dt)
            sparkles[i].velocity.dy *= (1 - 0.4 * dt)
        }
        sparkles.removeAll { now - $0.birth > $0.lifetime }
    }

    private func spawnSparkles(from: CGPoint, to: CGPoint, distance: CGFloat, now: CFTimeInterval) {
        let settings = Settings.shared
        let count = min(8, max(1, Int(distance / 5)))
        for _ in 0..<count {
            let t = CGFloat.random(in: 0...1)
            let base = CGPoint(x: from.x + (to.x - from.x) * t,
                               y: from.y + (to.y - from.y) * t)
            let jitter: CGFloat = 4
            let sparkle = Sparkle(
                position: CGPoint(x: base.x + .random(in: -jitter...jitter),
                                  y: base.y + .random(in: -jitter...jitter)),
                velocity: CGVector(dx: .random(in: -35...35), dy: .random(in: -15...45)),
                birth: now,
                lifetime: settings.duration * .random(in: 0.9...1.8),
                size: settings.thickness * .random(in: 0.35...0.8),
                hueJitter: .random(in: -0.08...0.08),
                twinklePhase: .random(in: 0...(2 * .pi))
            )
            sparkles.append(sparkle)
        }
    }

    func clear() {
        points.removeAll()
        sparkles.removeAll()
        lastPosition = nil
    }
}

// MARK: - Overlay view

final class TrailView: NSView {
    /// The screen-space origin of the window this view lives in, used to
    /// convert global mouse coordinates into view coordinates.
    var screenOrigin: CGPoint = .zero

    private func local(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - screenOrigin.x, y: p.y - screenOrigin.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let now = CACurrentMediaTime()

        switch Settings.shared.effect {
        case .line:
            drawLine(ctx, now: now)
        case .comet:
            drawComet(ctx, now: now)
        case .sparkles:
            drawSparkles(ctx, now: now)
        }
    }

    // MARK: Line

    private func drawLine(_ ctx: CGContext, now: CFTimeInterval) {
        let points = TrailModel.shared.points
        guard points.count > 1 else { return }
        let settings = Settings.shared

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let t = CGFloat(max(0, 1 - (now - p1.time) / settings.duration))
            if t <= 0.01 { continue }

            ctx.setStrokeColor(settings.color(at: p1.time).withAlphaComponent(t).cgColor)
            ctx.setLineWidth(max(1, settings.thickness * t))
            ctx.move(to: local(p0.position))
            ctx.addLine(to: local(p1.position))
            ctx.strokePath()
        }
    }

    // MARK: Comet

    private func drawComet(_ ctx: CGContext, now: CFTimeInterval) {
        let points = TrailModel.shared.points
        guard let head = points.last else { return }
        let settings = Settings.shared
        let w = settings.thickness

        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        // Three passes over the same path: wide soft halo, mid glow, bright core.
        let passes: [(widthScale: CGFloat, alphaScale: CGFloat, whiten: CGFloat)] = [
            (2.4, 0.16, 0.0),
            (1.3, 0.40, 0.15),
            (0.55, 0.95, 0.55),
        ]

        if points.count > 1 {
            for pass in passes {
                for i in 1..<points.count {
                    let p0 = points[i - 1]
                    let p1 = points[i]
                    let t = CGFloat(max(0, 1 - (now - p1.time) / settings.duration))
                    if t <= 0.01 { continue }

                    var color = settings.color(at: p1.time)
                    if pass.whiten > 0 {
                        color = color.blended(withFraction: pass.whiten, of: .white) ?? color
                    }
                    ctx.setStrokeColor(color.withAlphaComponent(t * pass.alphaScale).cgColor)
                    // Taper hard toward the tail so it reads as a comet.
                    ctx.setLineWidth(max(0.5, w * pass.widthScale * t * t))
                    ctx.move(to: local(p0.position))
                    ctx.addLine(to: local(p1.position))
                    ctx.strokePath()
                }
            }
        }

        // Glowing head at the cursor.
        let headColor = settings.color(at: head.time)
        let center = local(head.position)
        for (radius, alpha, whiten) in [(w * 2.0, 0.20, 0.0), (w * 1.1, 0.5, 0.2), (w * 0.55, 0.95, 0.7)] as [(CGFloat, CGFloat, CGFloat)] {
            var color = headColor
            if whiten > 0 { color = color.blended(withFraction: whiten, of: .white) ?? color }
            ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                       width: radius * 2, height: radius * 2))
        }
    }

    // MARK: Sparkles

    private func drawSparkles(_ ctx: CGContext, now: CFTimeInterval) {
        let settings = Settings.shared

        for sparkle in TrailModel.shared.sparkles {
            let age = now - sparkle.birth
            let fade = CGFloat(max(0, 1 - age / sparkle.lifetime))
            if fade <= 0.01 { continue }

            // Twinkle: each sparkle pulses on its own phase.
            let twinkle = 0.65 + 0.35 * sin(CGFloat(now) * 9 + sparkle.twinklePhase)
            let alpha = fade * twinkle
            let color = settings.color(at: sparkle.birth, hueJitter: sparkle.hueJitter)
            let center = local(sparkle.position)
            let r = sparkle.size * (0.6 + 0.4 * fade)

            ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
            ctx.addPath(Self.starPath(center: center, radius: r))
            ctx.fillPath()

            // Tiny bright core so sparkles pop on any background.
            let coreColor = color.blended(withFraction: 0.7, of: .white) ?? color
            ctx.setFillColor(coreColor.withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - r * 0.25, y: center.y - r * 0.25,
                                       width: r * 0.5, height: r * 0.5))
        }
    }

    /// Four-pointed star.
    private static func starPath(center: CGPoint, radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let inner = radius * 0.38
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let r = i.isMultiple(of: 2) ? radius : inner
            let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var overlayWindows: [NSWindow] = []
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setUpStatusItem()
        rebuildOverlayWindows()
        startTimer()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        showWelcomeIfNeeded()
    }

    private func showWelcomeIfNeeded() {
        let key = "hasShownWelcome"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Welcome to Mouse Trail"
        alert.informativeText = """
        Move your mouse to see the trail!

        Mouse Trail lives in your menu bar — look for the \
        cursor icon at the top-right of your screen to change \
        the style, color, thickness, and trail length, or to \
        pause and quit.
        """
        alert.addButton(withTitle: "Let's Go")
        alert.runModal()
    }

    // MARK: Overlay windows

    @objc private func screensChanged() {
        rebuildOverlayWindows()
    }

    private func rebuildOverlayWindows() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.level = .screenSaver
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false

            let view = TrailView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.screenOrigin = screen.frame.origin
            window.contentView = view
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
    }

    // MARK: Render loop

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 90.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard Settings.shared.enabled else { return }
            TrailModel.shared.tick()
            if !TrailModel.shared.isEmpty || self.needsFinalClear {
                self.needsFinalClear = !TrailModel.shared.isEmpty
                for window in self.overlayWindows {
                    window.contentView?.needsDisplay = true
                }
            }
        }
        // .common so the trail keeps updating while menus are open.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// After the last point expires we need one more redraw to erase the trail.
    private var needsFinalClear = false

    // MARK: Status item + menu

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "Mouse Trail")
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let settings = Settings.shared

        let toggle = NSMenuItem(
            title: settings.enabled ? "Pause Trail" : "Resume Trail",
            action: #selector(toggleEnabled), keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        // Style (effect)
        let styleMenu = NSMenu()
        for (name, effect) in [("Line", TrailEffect.line), ("Comet Glow", .comet), ("Sparkles", .sparkles)] {
            let item = NSMenuItem(title: name, action: #selector(chooseEffect(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = effect.rawValue
            item.state = settings.effect == effect ? .on : .off
            styleMenu.addItem(item)
        }
        let styleItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)

        // Color
        let colorMenu = NSMenu()
        let rainbow = NSMenuItem(title: "Rainbow", action: #selector(chooseRainbow), keyEquivalent: "")
        rainbow.target = self
        rainbow.state = settings.colorMode == .rainbow ? .on : .off
        colorMenu.addItem(rainbow)
        colorMenu.addItem(.separator())
        for (name, color) in Settings.solidColors {
            let item = NSMenuItem(title: name, action: #selector(chooseSolidColor(_:)), keyEquivalent: "")
            item.target = self
            item.state = (settings.colorMode == .solid && settings.solidColorName == name) ? .on : .off
            item.image = swatch(for: color)
            colorMenu.addItem(item)
        }
        colorMenu.addItem(.separator())
        let custom = NSMenuItem(title: "Custom…", action: #selector(chooseCustomColor), keyEquivalent: "")
        custom.target = self
        custom.state = (settings.colorMode == .solid && settings.solidColorName == "Custom") ? .on : .off
        custom.image = swatch(for: settings.customColor)
        colorMenu.addItem(custom)

        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)
        menu.addItem(.separator())

        // Thickness
        let thicknessMenu = NSMenu()
        for (name, value) in [("Thin", CGFloat(3)), ("Medium", 6), ("Thick", 10), ("Extra Thick", 16)] {
            let item = NSMenuItem(title: name, action: #selector(chooseThickness(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(settings.thickness - value) < 0.1 ? .on : .off
            thicknessMenu.addItem(item)
        }
        let thicknessItem = NSMenuItem(title: "Thickness", action: nil, keyEquivalent: "")
        thicknessItem.submenu = thicknessMenu
        menu.addItem(thicknessItem)

        // Trail length
        let lengthMenu = NSMenu()
        for (name, value) in [("Short", 0.3), ("Medium", 0.6), ("Long", 1.2), ("Extra Long", 2.5)] {
            let item = NSMenuItem(title: name, action: #selector(chooseDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            item.state = abs(settings.duration - value) < 0.01 ? .on : .off
            lengthMenu.addItem(item)
        }
        let lengthItem = NSMenuItem(title: "Trail Length", action: nil, keyEquivalent: "")
        lengthItem.submenu = lengthMenu
        menu.addItem(lengthItem)

        menu.addItem(.separator())

        // Launch at login
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Mouse Trail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func swatch(for color: NSColor) -> NSImage {
        let size = NSSize(width: 14, height: 14)
        return NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            color.setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
    }

    // MARK: Menu actions

    @objc private func toggleEnabled() {
        Settings.shared.enabled.toggle()
        if !Settings.shared.enabled {
            TrailModel.shared.clear()
            for window in overlayWindows { window.contentView?.needsDisplay = true }
        }
    }

    @objc private func chooseEffect(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let effect = TrailEffect(rawValue: raw) {
            Settings.shared.effect = effect
        }
    }

    @objc private func chooseRainbow() {
        Settings.shared.colorMode = .rainbow
    }

    @objc private func chooseSolidColor(_ sender: NSMenuItem) {
        Settings.shared.colorMode = .solid
        Settings.shared.solidColorName = sender.title
    }

    @objc private func chooseCustomColor() {
        Settings.shared.colorMode = .solid
        Settings.shared.solidColorName = "Custom"

        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = Settings.shared.customColor
        panel.setTarget(self)
        panel.setAction(#selector(customColorChanged(_:)))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func customColorChanged(_ sender: NSColorPanel) {
        Settings.shared.customColor = sender.color
    }

    @objc private func chooseThickness(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? CGFloat {
            Settings.shared.thickness = value
        }
    }

    @objc private func chooseDuration(_ sender: NSMenuItem) {
        if let value = sender.representedObject as? Double {
            Settings.shared.duration = value
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
