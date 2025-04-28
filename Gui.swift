import Cocoa
import AVFoundation

@MainActor
protocol GuiDelegate: AnyObject {
    func applicationDidFinishLaunching(_ notification: Notification)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
    func videoSourceSelected(_ source: String)
    func orientationSelected(_ orientation: String)
}
@MainActor
protocol GuiProtocol: AnyObject {
    func openWindow()
    func setImage(_ image: NSImage)
    func setImageAspectRatio(_ aspectRatio: CGFloat)
    func updateVideoSources(_ sources: [String])
    func updateOrientations(_ orientations: [String])
}

@MainActor
class Gui: NSObject, NSApplicationDelegate, GuiProtocol {
    var window: NSWindow?
    let imageView: NSImageView
    let containerView: NSView
    let videoSourceLabel: NSTextField
    let videoSourcePopup: NSPopUpButton
    let orientationLabel: NSTextField
    let orientationPopup: NSPopUpButton
    let delegate: GuiDelegate

    init(delegate: GuiDelegate) {
        imageView = NSImageView()
        containerView = NSView()
        videoSourceLabel = NSTextField(labelWithString: "Video Source:")
        videoSourcePopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 25))
        orientationLabel = NSTextField(labelWithString: "Orientation:")
        orientationPopup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 25))
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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        imageView.frame = containerView.bounds
        imageView.autoresizingMask = [.width, .height]
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleAxesIndependently
        containerView.addSubview(imageView)

        // Position label and popup in the top-left corner
        let labelWidth: CGFloat = 100
        let rowHeight: CGFloat = 25
        let spacing: CGFloat = 10
        
        videoSourceLabel.frame = NSRect(x: 20,
                                      y: windowSize.height - 40,
                                      width: labelWidth,
                                      height: rowHeight)
        videoSourceLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(videoSourceLabel)
        
        videoSourcePopup.frame = NSRect(x: 20 + labelWidth + spacing,
                                      y: windowSize.height - 40,
                                      width: 200,
                                      height: rowHeight)
        videoSourcePopup.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(videoSourcePopup)

        orientationLabel.frame = NSRect(x: 20,
                                      y: windowSize.height - 40 - rowHeight,
                                      width: labelWidth,
                                      height: rowHeight)
        orientationLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(orientationLabel)

        orientationPopup.frame = NSRect(x: 20 + labelWidth + spacing,
                                      y: windowSize.height - 40 - rowHeight,
                                      width: 200,
                                      height: rowHeight)
        orientationPopup.autoresizingMask = [.maxXMargin, .minYMargin]
        containerView.addSubview(orientationPopup)
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

    func setImage(_ image: NSImage) {
        imageView.image = image
    }
}
