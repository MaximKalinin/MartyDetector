import Cocoa
import AVFoundation
import opencv2
import IOKit.pwr_mgt

enum MainError: Error {
    case failedToCreateCGImage
    case failedToLoadTelegramConfig
}

let kMaxFrameDistance = 10 // Max frames distance between start and end frame
let kMinContourArea = 400.0 // Minimum contour area to be considered as a movement
let kRecordingTimeout = 100 // no. of frame count down before saving the video

@main
@MainActor
class Main: NSObject, GuiDelegate, VideoCaptureDelegate {
    private var gui: GuiProtocol?
    private var videoCapture: VideoCaptureProtocol?
    private var orientation: RotateFlags? = nil
    private var isRecordingActivated: Bool = false
    private var telegramAPI: TelegramAPI?
    private var sleepAssertionID: IOPMAssertionID = 0

    private let tmpDirectory: String = {
        let bundleId = Bundle.main.bundleIdentifier ?? "MartyDetector"
        return "\(NSTemporaryDirectory())\(bundleId)/"
    }()
    private let isoFormatter = ISO8601DateFormatter()

    private var startFrame: Mat?
    private var endFrame: Mat?
    private var frameDistance: Int = 0
    private var recordingFramesLeft: Int = 0
    private var recordingFilePath: String?
    private var recordingWriter: VideoWriter?
    
    func setGui(_ gui: GuiProtocol) {
        self.gui = gui
    }

    func setVideoCapture(_ videoCapture: VideoCaptureProtocol) {
        self.videoCapture = videoCapture
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent sleep while the app is running
        preventSleep()
        
        // Clean temporary directory
        do {
            let tmpDirectoryUrl = URL(fileURLWithPath: tmpDirectory)
            if FileManager.default.fileExists(atPath: tmpDirectory) {
                try FileManager.default.removeItem(at: tmpDirectoryUrl)
            }
            try FileManager.default.createDirectory(at: tmpDirectoryUrl, withIntermediateDirectories: true)
        } catch {
            print("Failed to clean temporary directory: \(error)")
        }
        
        // Initialize Telegram API
        do {
            let config = try Config.shared.loadFromEnv()
            telegramAPI = TelegramAPI(token: config.token, chatId: config.chatId)
        } catch {
            print("Failed to load Telegram configuration: \(error)")
        }
        
        // Now we can call GUI methods
        gui?.openWindow()

        let devices = getVideoDevices().map { $0.localizedName }

        gui?.updateVideoSources(devices)
        gui?.updateOrientations([nil, RotateFlags.ROTATE_90_CLOCKWISE, RotateFlags.ROTATE_180, RotateFlags.ROTATE_90_COUNTERCLOCKWISE].map(orientationToString))
        
        let savedVideoSource = UserDefaults.standard.string(forKey: "videoSource")
        if let savedVideoSource = savedVideoSource {
            videoSourceSelected(savedVideoSource)
        }
        
        let savedOrientation = UserDefaults.standard.string(forKey: "orientation")
        if let savedOrientation = savedOrientation {
            orientationSelected(savedOrientation)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Allow sleep when the app is closing
        allowSleep()
        
        videoCapture?.cleanupCamera()
        if let recordingWriter = recordingWriter, let recordingFilePath = recordingFilePath {
            stopRecording(recordingFilePath: recordingFilePath, recordingWriter: recordingWriter)
            self.recordingWriter = nil
            self.recordingFilePath = nil
        }
        return true
    }

    func captureOutput(didOutput pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        let formatOpencv = CvType.CV_8UC4
        let rows = Int32(CVPixelBufferGetHeight(pixelBuffer))
        let cols = Int32(CVPixelBufferGetWidth(pixelBuffer))
        let step =  CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bufferAddress = CVPixelBufferGetBaseAddress(pixelBuffer)

        guard let bufferAddress = bufferAddress else {
            print("Failed to get buffer address")
            return
        }
        
        let data = Data(bytes: bufferAddress, count: Int(rows) * step)

        let image = Mat(rows: rows, cols: cols, type: formatOpencv, data: data, step: step)
        if let orientation = orientation {
            Core.rotate(src: image, dst: image, rotateCode: orientation)
        }

        let imageSize = getSize(from: pixelBuffer)

        endFrame = getPreparedImage(image: image)
        if startFrame == nil {
            startFrame = endFrame
        }
        frameDistance += 1

        if frameDistance > kMaxFrameDistance {
            startFrame = endFrame
            frameDistance = 0
        }
        
        guard let startFrame = startFrame, let endFrame = endFrame else {
            print("startFrame or endFrame are nil")
            return
        }
        
        let movements = getMovement(startFrame: startFrame, endFrame: endFrame)
        
        if movements.count > 0 && isRecordingActivated {
            recordingFramesLeft = kRecordingTimeout
        } else {
            recordingFramesLeft = max(0, recordingFramesLeft - 1)
        }

        let isRecording = recordingFramesLeft > 0
        if isRecording {
            if recordingFilePath == nil && recordingWriter == nil {
                do {
                    (recordingFilePath, recordingWriter) = try startRecording(frameSize: startFrame.size())
                } catch {
                    print("Failed to start recording: \(error)")
                    return
                }
            }
        } else {
            if let recordingWriter = recordingWriter, let recordingFilePath = recordingFilePath {
                stopRecording(recordingFilePath: recordingFilePath, recordingWriter: recordingWriter)
                self.recordingWriter = nil
                self.recordingFilePath = nil
                self.endFrame = nil
                self.startFrame = nil
                frameDistance = 0
            }
        }

        render(image: image, recordingFramesLeft: recordingFramesLeft, movements: movements, recordingWriter: recordingWriter)
        self.gui?.setImageAspectRatio(imageSize.width / imageSize.height)
    }
    
    func videoSourceSelected(_ source: String) {
        print("Selected video source: \(source)")

        guard let device = getVideoDevices().first(where: { $0.localizedName == source }) else {
            print("Failed to find device: \(source)")
            return
        }
        
        UserDefaults.standard.set(source, forKey: "videoSource")

        videoCapture?.cleanupCamera()
        videoCapture?.setupCamera(deviceUniqueID: device.uniqueID)
        endFrame = nil
        startFrame = nil
        frameDistance = 0

        if let recordingWriter = recordingWriter, let recordingFilePath = recordingFilePath {
            stopRecording(recordingFilePath: recordingFilePath, recordingWriter: recordingWriter)
            self.recordingWriter = nil
            self.recordingFilePath = nil
        }

    }

    func orientationSelected(_ orientation: String) {
        self.orientation = stringToOrientation(orientation)
        
        UserDefaults.standard.set(orientation, forKey: "orientation")
        endFrame = nil
        startFrame = nil
        frameDistance = 0

        if let recordingWriter = recordingWriter, let recordingFilePath = recordingFilePath {
            stopRecording(recordingFilePath: recordingFilePath, recordingWriter: recordingWriter)
            self.recordingWriter = nil
            self.recordingFilePath = nil
        }
    }

    func recordingStateChanged(_ isRecording: Bool) {
        isRecordingActivated = isRecording
    }

    static func main() {
        let app = NSApplication.shared
        let main = Main()
        let gui = Gui(delegate: main)
        let videoCapture = VideoCapture(delegate: main)
        main.setGui(gui)
        main.setVideoCapture(videoCapture)
        app.delegate = gui
        app.run()
    }

    private func getSize(from pixelBuffer: CVPixelBuffer) -> CGSize {
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        if orientation == .ROTATE_90_CLOCKWISE || orientation == .ROTATE_90_COUNTERCLOCKWISE {
            // if the image is rotated only 90 degrees, height becomes width and vice versa
            return CGSize(width: bufferHeight, height: bufferWidth)
        }
        
        return CGSize(width: bufferWidth, height: bufferHeight)
    }

    private func getVideoDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    private func orientationToString(_ orientation: RotateFlags?) -> String {
        switch orientation {
        case .ROTATE_90_CLOCKWISE: return "Right"
        case .ROTATE_180: return "Down"
        case .ROTATE_90_COUNTERCLOCKWISE: return "Left"
        default: return "Up"
        }
    }

    private func stringToOrientation(_ string: String) -> RotateFlags? {
        switch string {
        case "Up": return nil
        case "Down": return .ROTATE_180
        case "Left": return .ROTATE_90_COUNTERCLOCKWISE
        case "Right": return .ROTATE_90_CLOCKWISE
        default: return nil
        }
    }
    private func getPreparedImage(image: Mat) -> Mat {
        let gray: Mat = Mat(size: image.size(), type: image.type())
        Imgproc.cvtColor(src: image, dst: gray, code: .COLOR_BGRA2GRAY)
        Imgproc.GaussianBlur(src: gray, dst: gray, ksize: Size2i(width: 21, height: 21), sigmaX: 0)
        return gray
    }

    private func getMovement(startFrame: Mat, endFrame: Mat) -> [Mat] {
        let frameDelta = Mat(size: startFrame.size(), type: startFrame.type())
        Core.absdiff(src1: startFrame, src2: endFrame, dst: frameDelta)
        let threshold: Mat = Mat(size: startFrame.size(), type: startFrame.type())
        Imgproc.threshold(src: frameDelta, dst: threshold, thresh: 25, maxval: 255, type: .THRESH_BINARY)
        Imgproc.dilate(src: threshold, dst: threshold, kernel: Mat(), anchor: Point2i(x: -1, y: -1), iterations: 2)
        var contours = [[Point]]()
        Imgproc.findContours(image: threshold, contours: &contours, hierarchy: Mat(), mode: .RETR_EXTERNAL, method: .CHAIN_APPROX_SIMPLE)

        var filteredContours = [Mat]()
        for contour in contours {
            let contourMat = MatOfPoint(array: contour)
            let area = Imgproc.contourArea(contour: contourMat)
            if area > kMinContourArea {
                filteredContours.append(contourMat)
            }
        }
        return filteredContours
    }
    
    private func render(image: Mat, recordingFramesLeft: Int, movements: [Mat], recordingWriter: VideoWriter?) {
        if let recordingWriter = recordingWriter {
            recordingWriter.write(image: image)
        }
        
        Imgproc.cvtColor(src: image, dst: image, code: .COLOR_BGRA2RGB)

        if recordingFramesLeft > 0 {
            Imgproc.putText(img: image, text: "Recording: \(recordingFramesLeft)", org: Point2i(x: 10, y: 35), fontFace: .FONT_HERSHEY_SIMPLEX, fontScale: 0.75, color: Scalar(255, 255, 255))
        }
        
        for movement in movements {
            let rectangle = Imgproc.boundingRect(array: movement)
            Imgproc.rectangle(img: image, rec: rectangle, color: Scalar(0, 255, 0), thickness: 2)
        }
        
        let cgImage = image.toCGImage()
        self.gui?.setImage(cgImage)
    }
    
    private func startRecording(frameSize: Size2i) throws -> (recordingFilePath: String, recordingWriter: VideoWriter) {
        print("Starting recording")
        let filename = "\(isoFormatter.string(from: Date())).mp4"
        let recordingFilePath = "\(tmpDirectory)\(filename)"
            
        let fourccCString = "avc1".utf8CString
        let recordingWriter = VideoWriter(filename: recordingFilePath, fourcc: Int32(VideoWriter.fourcc(c1: fourccCString[0], c2: fourccCString[1], c3: fourccCString[2], c4: fourccCString[3])), fps: 25.0, frameSize: frameSize)
        
        return (recordingFilePath, recordingWriter)
    }
    
    private func stopRecording(recordingFilePath: String, recordingWriter: VideoWriter) {
        print("Recording finished at \(recordingFilePath)")
        
        // Upload the video file asynchronously
        if let telegramAPI = telegramAPI {
            Task {
                do {
                    let timestamp = isoFormatter.string(from: Date())
                    let _ = try await telegramAPI.sendVideo(videoPath: recordingFilePath, caption: "Motion detected at \(timestamp)")
                    
                    // Clean up the temporary file after successful upload
                    try? FileManager.default.removeItem(atPath: recordingFilePath)
                } catch {
                    print("Failed to upload video to Telegram: \(error)")
                }
            }
        }
    }
    
    private func preventSleep() {
        var assertionID = sleepAssertionID
        let reason = "Marty Detector is running" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if success == kIOReturnSuccess {
            sleepAssertionID = assertionID
        }
    }
    
    private func allowSleep() {
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }
}
