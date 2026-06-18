import AppKit
import SwiftUI
import UserNotifications

@main
final class EyeRestApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var menuBuilder: MenuBuilder!
    private var timerController: TimerController!
    private var restWindowController: RestWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "EyeRest")
        statusItem.button?.imagePosition = .imageLeading

        let settingsStore = SettingsStore()
        timerController = TimerController(settingsStore: settingsStore)
        timerController.onTick = { [weak self] state in
            self?.updateStatus(with: state)
        }
        timerController.onRestStarted = { [weak self] session in
            self?.presentRest(session)
        }
        timerController.onRestEnded = { [weak self] in
            self?.restWindowController?.close()
            self?.restWindowController = nil
        }

        menuBuilder = MenuBuilder(settingsStore: settingsStore, timerController: timerController)
        statusItem.menu = menuBuilder.makeMenu()

        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        timerController.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func updateStatus(with state: TimerState) {
        DispatchQueue.main.async {
            guard let button = self.statusItem.button else { return }
            button.title = " \(state.shortDisplay)"
            self.menuBuilder.refresh()
            self.restWindowController?.update(state: state)
        }
    }

    private func presentRest(_ session: RestSession) {
        DispatchQueue.main.async {
            self.sendRestNotification(session)
            self.restWindowController?.close()
            self.restWindowController = RestWindowController(
                session: session,
                timerController: self.timerController
            )
            self.restWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func sendRestNotification(_ session: RestSession) {
        let content = UNMutableNotificationContent()
        content.title = session.settings.mode.notificationTitle
        content.body = session.settings.mode.notificationBody(duration: session.settings.restMinutes)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "eyerest-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

enum TimerMode: String, CaseIterable, Codable {
    case rule202020
    case pomodoro
    case custom

    var title: String {
        switch self {
        case .rule202020: "20-20-20"
        case .pomodoro: "番茄钟"
        case .custom: "自定义"
        }
    }

    var notificationTitle: String {
        switch self {
        case .rule202020: "该抬头看看远处了"
        case .pomodoro: "番茄休息时间"
        case .custom: "休息时间到了"
        }
    }

    func notificationBody(duration: Int) -> String {
        switch self {
        case .rule202020:
            "眺望 6 米外至少 \(duration * 60) 秒，让眼睛放松一下。"
        case .pomodoro:
            "离开屏幕 \(duration) 分钟，回来再继续。"
        case .custom:
            "按你的节奏休息 \(duration) 分钟。"
        }
    }
}

struct EyeRestSettings: Codable, Equatable {
    var mode: TimerMode = .rule202020
    var workMinutes: Int = 20
    var restMinutes: Int = 1
    var showRestWindow: Bool = true
    var notificationsEnabled: Bool = true

    static let defaults = EyeRestSettings()

    static func preset(for mode: TimerMode) -> EyeRestSettings {
        switch mode {
        case .rule202020:
            EyeRestSettings(mode: .rule202020, workMinutes: 20, restMinutes: 1)
        case .pomodoro:
            EyeRestSettings(mode: .pomodoro, workMinutes: 25, restMinutes: 5)
        case .custom:
            EyeRestSettings(mode: .custom, workMinutes: 20, restMinutes: 1)
        }
    }
}

final class SettingsStore {
    private let key = "EyeRestSettings"

    var settings: EyeRestSettings {
        didSet {
            save()
            onChange?(settings)
        }
    }

    var onChange: ((EyeRestSettings) -> Void)?

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode(EyeRestSettings.self, from: data)
        else {
            settings = .defaults
            return
        }
        settings = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct RestSession {
    let settings: EyeRestSettings
    let startedAt: Date
    let endsAt: Date
}

struct TimerState {
    let settings: EyeRestSettings
    let phase: TimerPhase
    let remaining: TimeInterval
    let paused: Bool

    var shortDisplay: String {
        if paused { return "暂停" }
        return "\(phase.shortLabel) \(Self.format(remaining))"
    }

    var longDisplay: String {
        if paused { return "已暂停" }
        return "\(phase.title) · \(Self.format(remaining))"
    }

    static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let minutesPart = seconds / 60
        let secondsPart = seconds % 60
        return String(format: "%02d:%02d", minutesPart, secondsPart)
    }
}

enum TimerPhase {
    case working
    case resting(RestSession)

    var title: String {
        switch self {
        case .working: "专注中"
        case .resting: "休息中"
        }
    }

    var shortLabel: String {
        switch self {
        case .working: "工作"
        case .resting: "休息"
        }
    }
}

final class TimerController {
    private let settingsStore: SettingsStore
    private var timer: Timer?
    private var phase: TimerPhase = .working
    private var phaseEndsAt = Date()
    private var paused = false
    private var pauseRemaining: TimeInterval = 0

    var onTick: ((TimerState) -> Void)?
    var onRestStarted: ((RestSession) -> Void)?
    var onRestEnded: (() -> Void)?

    var settings: EyeRestSettings { settingsStore.settings }
    var isPaused: Bool { paused }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.settingsStore.onChange = { [weak self] _ in
            self?.resetWork()
        }
    }

    func start() {
        resetWork()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func togglePause() {
        if paused {
            phaseEndsAt = Date().addingTimeInterval(pauseRemaining)
            paused = false
        } else {
            pauseRemaining = remaining
            paused = true
        }
        publishTick()
    }

    func resetWork() {
        paused = false
        phase = .working
        phaseEndsAt = Date().addingTimeInterval(TimeInterval(settings.workMinutes * 60))
        onRestEnded?()
        publishTick()
    }

    func skipToRest() {
        beginRest()
    }

    func finishRest() {
        resetWork()
    }

    private var remaining: TimeInterval {
        if paused { return pauseRemaining }
        return max(0, phaseEndsAt.timeIntervalSinceNow)
    }

    private func tick() {
        guard !paused else {
            publishTick()
            return
        }

        if remaining <= 0 {
            switch phase {
            case .working:
                beginRest()
            case .resting:
                resetWork()
            }
            return
        }
        publishTick()
    }

    private func beginRest() {
        paused = false
        let restSeconds = TimeInterval(settings.restMinutes * 60)
        let session = RestSession(
            settings: settings,
            startedAt: Date(),
            endsAt: Date().addingTimeInterval(restSeconds)
        )
        phase = .resting(session)
        phaseEndsAt = session.endsAt
        publishTick()

        if settings.showRestWindow {
            onRestStarted?(session)
        }
    }

    private func publishTick() {
        onTick?(
            TimerState(
                settings: settings,
                phase: phase,
                remaining: remaining,
                paused: paused
            )
        )
    }
}

final class MenuBuilder: NSObject {
    private let settingsStore: SettingsStore
    private let timerController: TimerController
    private let menu = NSMenu()
    private var statusItem = NSMenuItem()
    private var pauseItem = NSMenuItem()
    private var notifyItem = NSMenuItem()
    private var windowItem = NSMenuItem()

    init(settingsStore: SettingsStore, timerController: TimerController) {
        self.settingsStore = settingsStore
        self.timerController = timerController
    }

    func makeMenu() -> NSMenu {
        menu.removeAllItems()

        statusItem = NSMenuItem(title: "启动中", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        for mode in TimerMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(makeStepperItem(title: "工作", value: settingsStore.settings.workMinutes, selector: #selector(changeWorkMinutes(_:))))
        menu.addItem(makeStepperItem(title: "休息", value: settingsStore.settings.restMinutes, selector: #selector(changeRestMinutes(_:))))

        menu.addItem(.separator())
        pauseItem = NSMenuItem(title: "暂停", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)

        let restNow = NSMenuItem(title: "现在休息", action: #selector(restNow), keyEquivalent: "r")
        restNow.target = self
        menu.addItem(restNow)

        let reset = NSMenuItem(title: "重新开始计时", action: #selector(reset), keyEquivalent: "n")
        reset.target = self
        menu.addItem(reset)

        menu.addItem(.separator())
        notifyItem = NSMenuItem(title: "系统通知", action: #selector(toggleNotifications), keyEquivalent: "")
        notifyItem.target = self
        menu.addItem(notifyItem)

        windowItem = NSMenuItem(title: "休息窗口", action: #selector(toggleRestWindow), keyEquivalent: "")
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 EyeRest", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        refresh()
        return menu
    }

    func refresh() {
        statusItem.title = timerController.isPaused ? "已暂停" : "当前节奏：\(settingsStore.settings.mode.title)"
        pauseItem.title = timerController.isPaused ? "继续" : "暂停"
        notifyItem.state = settingsStore.settings.notificationsEnabled ? .on : .off
        windowItem.state = settingsStore.settings.showRestWindow ? .on : .off

        for item in menu.items where item.representedObject is String {
            item.state = (item.representedObject as? String) == settingsStore.settings.mode.rawValue ? .on : .off
        }
    }

    private func makeStepperItem(title: String, value: Int, selector: Selector) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 230, height: 34))

        let label = NSTextField(labelWithString: "\(title)：\(value) 分钟")
        label.frame = NSRect(x: 14, y: 8, width: 120, height: 18)
        label.alignment = .left

        let minus = NSButton(title: "-", target: self, action: selector)
        minus.frame = NSRect(x: 142, y: 5, width: 34, height: 24)
        minus.bezelStyle = .rounded
        minus.tag = -1

        let plus = NSButton(title: "+", target: self, action: selector)
        plus.frame = NSRect(x: 182, y: 5, width: 34, height: 24)
        plus.bezelStyle = .rounded
        plus.tag = 1

        view.addSubview(label)
        view.addSubview(minus)
        view.addSubview(plus)
        item.view = view
        return item
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let mode = TimerMode(rawValue: rawValue)
        else { return }

        var preset = EyeRestSettings.preset(for: mode)
        preset.notificationsEnabled = settingsStore.settings.notificationsEnabled
        preset.showRestWindow = settingsStore.settings.showRestWindow
        settingsStore.settings = preset
        rebuildMenuPreservingOpenState()
    }

    @objc private func changeWorkMinutes(_ sender: NSButton) {
        var settings = settingsStore.settings
        settings.mode = .custom
        settings.workMinutes = min(180, max(1, settings.workMinutes + sender.tag))
        settingsStore.settings = settings
        rebuildMenuPreservingOpenState()
    }

    @objc private func changeRestMinutes(_ sender: NSButton) {
        var settings = settingsStore.settings
        settings.mode = .custom
        settings.restMinutes = min(60, max(1, settings.restMinutes + sender.tag))
        settingsStore.settings = settings
        rebuildMenuPreservingOpenState()
    }

    @objc private func togglePause() {
        timerController.togglePause()
        refresh()
    }

    @objc private func restNow() {
        timerController.skipToRest()
    }

    @objc private func reset() {
        timerController.resetWork()
    }

    @objc private func toggleNotifications() {
        settingsStore.settings.notificationsEnabled.toggle()
        refresh()
    }

    @objc private func toggleRestWindow() {
        settingsStore.settings.showRestWindow.toggle()
        refresh()
    }

    private func rebuildMenuPreservingOpenState() {
        makeMenu()
    }
}

final class RestWindowController: NSWindowController {
    private let content: RestView

    init(session: RestSession, timerController: TimerController) {
        content = RestView(session: session, timerController: timerController)
        let hostingView = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "EyeRest"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.contentView = hostingView
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(state: TimerState) {
        content.model.remainingText = TimerState.format(state.remaining)
    }
}

@MainActor
final class RestViewModel: ObservableObject {
    @Published var remainingText: String
}

struct RestView: View {
    let session: RestSession
    let timerController: TimerController
    @StateObject var model: RestViewModel

    init(session: RestSession, timerController: TimerController) {
        self.session = session
        self.timerController = timerController
        _model = StateObject(wrappedValue: RestViewModel(remainingText: TimerState.format(session.endsAt.timeIntervalSinceNow)))
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconName)
                .font(.system(size: 52, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.teal)

            Text(title)
                .font(.system(size: 30, weight: .semibold))

            Text(message)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 410)

            Text(model.remainingText)
                .font(.system(size: 46, weight: .medium, design: .rounded))
                .monospacedDigit()
                .padding(.top, 4)

            HStack(spacing: 12) {
                Button("结束休息") {
                    timerController.finishRest()
                }
                .keyboardShortcut(.defaultAction)

                Button("再休息 1 分钟") {
                    var next = session.settings
                    next.restMinutes += 1
                    timerController.finishRest()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        timerController.skipToRest()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(width: 520, height: 320)
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.teal.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var iconName: String {
        switch session.settings.mode {
        case .rule202020: "eye"
        case .pomodoro: "timer"
        case .custom: "sparkles"
        }
    }

    private var title: String {
        switch session.settings.mode {
        case .rule202020: "看向 6 米外"
        case .pomodoro: "番茄休息"
        case .custom: "休息一下"
        }
    }

    private var message: String {
        switch session.settings.mode {
        case .rule202020:
            "抬头眺望远方，让眼睛从屏幕焦距里出来。至少 20 秒，慢慢眨眼。"
        case .pomodoro:
            "站起来、喝水、走几步。下一轮专注会更轻松。"
        case .custom:
            "按照你设定的节奏休息，给注意力一点恢复时间。"
        }
    }
}
