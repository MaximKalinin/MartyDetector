import Cocoa
import AVFoundation
import opencv2

enum MainError: Error {
    case failedToCreateCGImage
}

let kMaxFrameDistance = 10 // Max frames distance between start and end frame
let kMinContourArea = 400.0 // Minimum contour area to be considered as a movement

@main
@MainActor
class Main: NSObject, GuiDelegate, VideoCaptureDelegate {
    private var gui: GuiProtocol?
    private var videoCapture: VideoCaptureProtocol?
    private var orientation: CGImagePropertyOrientation = .up
    private let device: MTLDevice
    private let ciContext: CIContext

    private var startFrame: Mat?
    private var endFrame: Mat?
    private var frameDistance: Int = 0
    
    override init() {
        device = MTLCreateSystemDefaultDevice()!
        // Using metal to speed up image creation
        ciContext = CIContext(mtlDevice: device)

        super.init()
    }
    
    func setGui(_ gui: GuiProtocol) {
        self.gui = gui
    }

    func setVideoCapture(_ videoCapture: VideoCaptureProtocol) {
        self.videoCapture = videoCapture
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Application did finish launching")
        // Now we can call GUI methods
        gui?.openWindow()

        let devices = getVideoDevices().map { $0.localizedName }

        gui?.updateVideoSources(devices)
        gui?.updateOrientations([.up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored].map(orientationToString))
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        videoCapture?.cleanupCamera()
        return true
    }

    func captureOutput(didOutput pixelBuffer: CVPixelBuffer) {
        do {
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
            
            for movement in movements {
                let rectangle = Imgproc.boundingRect(array: movement)
                Imgproc.rectangle(img: image, rec: rectangle, color: Scalar(0, 255, 0), thickness: 2)
            }

            Imgproc.cvtColor(src: image, dst: image, code: .COLOR_BGRA2RGB)
            Core.rotate(src: image, dst: image, rotateCode: .ROTATE_180)
            
            self.gui?.setImage(image.toNSImage())
            self.gui?.setImageAspectRatio(imageSize.width / imageSize.height)
        } catch {
            print("Failed to create NSImage: \(error)")
        }
    }
    
    func videoSourceSelected(_ source: String) {
        print("Selected video source: \(source)")

        guard let device = getVideoDevices().first(where: { $0.localizedName == source }) else {
            print("Failed to find device: \(source)")
            return
        }

        videoCapture?.cleanupCamera()
        videoCapture?.setupCamera(deviceUniqueID: device.uniqueID)
    }

    func orientationSelected(_ orientation: String) {
        self.orientation = stringToOrientation(orientation)
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

    private func createNSImage(from pixelBuffer: CVPixelBuffer) throws -> NSImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let transformedCiImage = ciImage.oriented(orientation)
        guard let cgImage = ciContext.createCGImage(transformedCiImage, from: transformedCiImage.extent) else {
            throw MainError.failedToCreateCGImage
        }

        return NSImage(cgImage: cgImage, size: getSize(from: pixelBuffer))
    }

    private func getSize(from pixelBuffer: CVPixelBuffer) -> CGSize {
        return CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
    }

    private func getVideoDevices() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    private func orientationToString(_ orientation: CGImagePropertyOrientation) -> String {
        switch orientation {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .upMirrored: return "Up Mirrored"
        case .downMirrored: return "Down Mirrored"
        case .leftMirrored: return "Left Mirrored"
        case .rightMirrored: return "Right Mirrored"
        @unknown default: return "Unknown"
        }
    }

    private func stringToOrientation(_ string: String) -> CGImagePropertyOrientation {
        switch string {
        case "Up": return .up
        case "Down": return .down
        case "Left": return .left
        case "Right": return .right
        case "Up Mirrored": return .upMirrored
        case "Down Mirrored": return .downMirrored
        case "Left Mirrored": return .leftMirrored
        case "Right Mirrored": return .rightMirrored
        default: return .up
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
}
