import Cocoa
import AVFoundation

@MainActor
protocol VideoCaptureDelegate: AnyObject {
    func captureOutput(didOutput imageBuffer: CVPixelBuffer)
}

protocol VideoCaptureProtocol: AnyObject {
    func setupCamera(deviceUniqueID: String)
    func cleanupCamera()
}

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, VideoCaptureProtocol {
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureVideoDataOutput?
    var delegate: VideoCaptureDelegate

    init(delegate: VideoCaptureDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func setupCamera(deviceUniqueID: String) {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else {
            print("Failed to create capture session")
            return
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        guard let videoOutput = videoOutput else {
            print("Failed to create video output")
            return
        }
        print("available pixel format types: \(videoOutput.availableVideoPixelFormatTypes)")

        if !videoOutput.availableVideoPixelFormatTypes.contains(kCVPixelFormatType_32BGRA) {
            print("kCVPixelFormatType_32BGRA not supported")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Use default camera
        guard let camera = AVCaptureDevice.init(uniqueID: deviceUniqueID),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to get camera input")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Set up video output
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func cleanupCamera() {
        guard let captureSession = captureSession else { return }
        
        captureSession.stopRunning()
        
        // Remove all inputs and outputs
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        guard let videoOutput = videoOutput else { return }
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        
        // Clear references
        self.videoOutput = nil
        self.captureSession = nil
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        DispatchQueue.main.async {
            self.delegate.captureOutput(didOutput: pixelBuffer)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped frame")
                        
        var mode: CMAttachmentMode = 0
        let reason = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo, attachmentModeOut: &mode)

        print("reason \(String(describing: reason))") // Optional(OutOfBuffers)
    }
}
