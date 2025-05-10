import Cocoa
import AVFoundation

@MainActor
protocol GuiDelegate: AnyObject {
    func applicationDidFinishLaunching(_ notification: Notification)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    func videoSourceSelected(_ source: String)
    func orientationSelected(_ orientation: String)
    func recordingStateChanged(_ isRecording: Bool)
    func telegramApiKeyChanged(_ apiKey: String)
    func telegramChatIdChanged(_ chatId: String)
}
@MainActor
protocol GuiProtocol: AnyObject {
    func openWindow()
    func setImage(_ image: CGImage)
    func setImageAspectRatio(_ aspectRatio: CGFloat)
    func updateVideoSources(_ sources: [String])
    func updateOrientations(_ orientations: [String])
    func setVideoSource(_ source: String)
    func setOrientation(_ orientation: String)
    func setTelegramApiKey(_ apiKey: String)
    func setTelegramChatId(_ chatId: String)
}

@MainActor
class Gui: NSObject, NSApplicationDelegate, GuiProtocol {
    var window: NSWindow?
    let caLayer: CALayer
    let containerView: NSView
    let videoSourceLabel: NSTextField
    let videoSourcePopup: NSPopUpButton
    let orientationLabel: NSTextField
    let orientationPopup: NSPopUpButton
    let recordingLabel: NSTextField
    let recordingSwitch: NSSwitch
    let telegramApiKeyLabel: NSTextField
    let telegramApiKeyField: NSSecureTextField
    let telegramChatIdLabel: NSTextField
    let telegramChatIdField: NSTextField
    let delegate: GuiDelegate

    init(delegate: GuiDelegate) {
        caLayer = CALayer()
        containerView = NSView()
        containerView.wantsLayer = true
        
        videoSourceLabel = NSTextField(labelWithString: "Video Source:")
        videoSourcePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 25))
        orientationLabel = NSTextField(labelWithString: "Orientation:")
        orientationPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 25))
        recordingLabel = NSTextField(labelWithString: "Start Recording:")
        recordingSwitch = NSSwitch()
        telegramApiKeyLabel = NSTextField(labelWithString: "Telegram API Key:")
        telegramApiKeyField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 25))
        telegramChatIdLabel = NSTextField(labelWithString: "Chat ID:")
        telegramChatIdField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 25))
        self.delegate = delegate
        super.init()
        
        // Configure label
        videoSourceLabel.font = .systemFont(ofSize: 13)
        videoSourceLabel.textColor = .labelColor
        
        // Configure popup menu
        videoSourcePopup.target = self
        videoSourcePopup.action = #selector(sourcePopupChanged)
        updateVideoSources(["Loading video sources..."])

        orientationLabel.font = .systemFont(ofSize: 13)
        orientationLabel.textColor = .labelColor

        orientationPopup.target = self
        orientationPopup.action = #selector(orientationPopupChanged)
        updateOrientations(["Loading orientations..."])

        // Configure recording controls
        recordingLabel.font = .systemFont(ofSize: 13)
        recordingLabel.textColor = .labelColor
        
        recordingSwitch.target = self
        recordingSwitch.action = #selector(recordingSwitchChanged)

        // Configure Telegram API key field
        telegramApiKeyLabel.font = .systemFont(ofSize: 13)
        telegramApiKeyLabel.textColor = .labelColor
        
        telegramApiKeyField.target = self
        telegramApiKeyField.action = #selector(telegramApiKeyChanged)

        // Configure Telegram Chat ID field
        telegramChatIdLabel.font = .systemFont(ofSize: 13)
        telegramChatIdLabel.textColor = .labelColor
        
        telegramChatIdField.target = self
        telegramChatIdField.action = #selector(telegramChatIdChanged)
    }
    
    
    func updateVideoSources(_ sources: [String]) {
        videoSourcePopup.removeAllItems()

        videoSourcePopup.addItem(withTitle: "Select a video source")
        
        for source in sources {
            videoSourcePopup.addItem(withTitle: source)
        }
    }

    func updateOrientations(_ orientations: [String]) {
        orientationPopup.removeAllItems()

        orientationPopup.addItem(withTitle: "Select an orientation")

        for orientation in orientations {
            orientationPopup.addItem(withTitle: orientation)
        }
    }
    
    @objc func sourcePopupChanged() {
        guard let selectedVideoSource = videoSourcePopup.titleOfSelectedItem else {
            return
        }

        delegate.videoSourceSelected(selectedVideoSource)
    }

    @objc func orientationPopupChanged() {
        guard let selectedOrientation = orientationPopup.titleOfSelectedItem else {
            return
        }

        delegate.orientationSelected(selectedOrientation)
    }

    @objc func recordingSwitchChanged() {
        delegate.recordingStateChanged(recordingSwitch.state == .on)
    }

    @objc func telegramApiKeyChanged() {
        delegate.telegramApiKeyChanged(telegramApiKeyField.stringValue)
    }

    @objc func telegramChatIdChanged() {
        delegate.telegramChatIdChanged(telegramChatIdField.stringValue)
    }

    func setVideoSource(_ source: String) {
        videoSourcePopup.selectItem(withTitle: source)
    }

    func setOrientation(_ orientation: String) {
        orientationPopup.selectItem(withTitle: orientation)
    }

    func setTelegramApiKey(_ apiKey: String) {
        telegramApiKeyField.stringValue = apiKey
    }

    func setTelegramChatId(_ chatId: String) {
        telegramChatIdField.stringValue = chatId
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()

        // MARK: App Menu (e.g., "Quit")
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let quitTitle = "Quit \(ProcessInfo.processInfo.processName)"
        appMenu.addItem(withTitle: quitTitle,
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // MARK: Edit Menu (for Copy, Paste, etc.)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
        delegate.applicationDidFinishLaunching(notification)
    }

    func openWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let screenSize = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowSize = NSRect(x: 0, y: 0, width: 640, height: 480)
        
        window = NSWindow(
            contentRect: NSMakeRect(
                (screenSize.width - windowSize.width) / 2,
                (screenSize.height - windowSize.height) / 2,
                windowSize.width,
                windowSize.height),
            styleMask: [.titled, .resizable, .closable],
            backing: .buffered,
            defer: false)
        guard let window = window else {
            return
        }

        // avoid bad access after window is closed
        window.isReleasedWhenClosed = false
        window.title = "Marty Detector"
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Setup container view
        containerView.frame = windowSize
        containerView.autoresizingMask = [.width, .height]
        window.contentView = containerView

        // Setup image view
        caLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        caLayer.frame = containerView.bounds
        
        guard let layer = containerView.layer else {
            print("Falied to add calayer to container view")
            return
        }
        layer.addSublayer(caLayer)

        // Position label and popup in the top-left corner
        let labelWidth: CGFloat = 120
        let rowHeight: CGFloat = 25
        let spacing: CGFloat = 10
        let topMargin: CGFloat = 40
        let leftMargin: CGFloat = 20
        
        videoSourceLabel.frame = NSRect(x: leftMargin,
                                      y: windowSize.height - topMargin,
                                      width: labelWidth,
                                      height: rowHeight)
        videoSourceLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(videoSourceLabel)
        
        videoSourcePopup.frame = NSRect(x: leftMargin + labelWidth + spacing,
                                      y: windowSize.height - topMargin,
                                      width: 200,
                                      height: rowHeight)
        videoSourcePopup.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(videoSourcePopup)

        orientationLabel.frame = NSRect(x: leftMargin,
                                      y: windowSize.height - topMargin - rowHeight,
                                      width: labelWidth,
                                      height: rowHeight)
        orientationLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(orientationLabel)

        orientationPopup.frame = NSRect(x: leftMargin + labelWidth + spacing,
                                      y: windowSize.height - topMargin - rowHeight,
                                      width: 200,
                                      height: rowHeight)
        orientationPopup.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(orientationPopup)

        // Position Telegram API key field below recording controls
        telegramApiKeyLabel.frame = NSRect(x: leftMargin,
                                         y: windowSize.height - topMargin - (rowHeight * 2),
                                         width: labelWidth,
                                         height: rowHeight)
        telegramApiKeyLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(telegramApiKeyLabel)

        telegramApiKeyField.frame = NSRect(x: leftMargin + labelWidth + spacing,
                                         y: windowSize.height - topMargin - (rowHeight * 2),
                                         width: 200,
                                         height: rowHeight)
        telegramApiKeyField.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(telegramApiKeyField)

        // Position Telegram Chat ID field next to API key
        telegramChatIdLabel.frame = NSRect(x: leftMargin,
                                         y: windowSize.height - topMargin - (rowHeight * 3),
                                         width: labelWidth,
                                         height: rowHeight)
        telegramChatIdLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(telegramChatIdLabel)

        telegramChatIdField.frame = NSRect(x: leftMargin + labelWidth + spacing,
                                         y: windowSize.height - topMargin - (rowHeight * 3),
                                         width: 200,
                                         height: rowHeight)
        telegramChatIdField.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(telegramChatIdField)
        
        // Position recording controls below the popups
        recordingLabel.frame = NSRect(x: leftMargin,
                                    y: windowSize.height - topMargin - (rowHeight * 4),
                                    width: labelWidth,
                                    height: rowHeight)
        recordingLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(recordingLabel)

        recordingSwitch.frame = NSRect(x: leftMargin + labelWidth + spacing,
                                     y: windowSize.height - topMargin - (rowHeight * 4),
                                     width: 51,  // Standard NSSwitch width
                                     height: rowHeight)
        recordingSwitch.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(recordingSwitch)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return delegate.applicationShouldTerminateAfterLastWindowClosed(sender)
    }

    func setImageAspectRatio(_ aspectRatio: CGFloat) {
        guard let window = window,
              let contentView = window.contentView else {
            return
        }

        let windowSize = window.frame.size
        let titleBarHeight = window.frame.height - contentView.frame.height
        let contentSize = NSSize(width: windowSize.width, height: windowSize.height - titleBarHeight)
        let contentAspectRatio = contentSize.width / contentSize.height
        let threshold = 0.05

        if abs(contentAspectRatio - aspectRatio) > threshold {
            let newContentHeight = contentSize.width / aspectRatio
            let newWindowSize = CGSize(width: windowSize.width, height: newContentHeight + titleBarHeight)
            window.aspectRatio = NSSize(width: windowSize.width, height: newContentHeight + titleBarHeight)
            var frame = window.frame
            frame.size = newWindowSize
            window.setFrame(frame, display: true)
        }
    }

    func setImage(_ image: CGImage) {
        caLayer.contents = image
    }
}
