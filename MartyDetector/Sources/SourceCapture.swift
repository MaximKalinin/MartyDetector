import Cocoa
import AVFoundation

@MainActor
protocol SourceCaptureDelegate: AnyObject {
    func captureOutput(didOutput imageBuffer: CVPixelBuffer, presentationTime: CMTime)
    func captureOutput(didOutput audioSampleBuffer: CMSampleBuffer)
}

protocol SourceCaptureProtocol: AnyObject {
    func setup(cameraUniqueID: String)
    func cleanup()
}

class SourceCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, SourceCaptureProtocol {
    var captureSession: AVCaptureSession?
    var videoOutput: AVCaptureVideoDataOutput?
    var audioOutput: AVCaptureAudioDataOutput?
    var delegate: SourceCaptureDelegate

    init(delegate: SourceCaptureDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func setup(cameraUniqueID: String) {
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
        
        audioOutput = AVCaptureAudioDataOutput()
        guard let audioOutput = audioOutput else {
            print("Failed to create audio output")
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Use default camera
        guard let camera = AVCaptureDevice.init(uniqueID: cameraUniqueID),
              let cameraInput = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to get camera input")
            return
        }
        
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }

        // Set up video output
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        guard let microphone = AVCaptureDevice.default(for: .audio),
        let microphoneInput = try? AVCaptureDeviceInput(device: microphone) else {
            print("No audio device found")
            return
        }
        
        if captureSession.canAddInput(microphoneInput) {
            captureSession.addInput(microphoneInput)
        }

        audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "audioQueue"))
        
        if captureSession.canAddOutput(audioOutput) {
            captureSession.addOutput(audioOutput)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func cleanup() {
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
        
        guard let audioOutput = audioOutput else { return }
        audioOutput.setSampleBufferDelegate(nil, queue: nil)
        
        // Clear references
        self.videoOutput = nil
        self.audioOutput = nil
        self.captureSession = nil
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if isVideoSampleBuffer(sampleBuffer) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            DispatchQueue.main.async {
                self.delegate.captureOutput(didOutput: pixelBuffer, presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }
        } else if isAudioSampleBuffer(sampleBuffer) {
            DispatchQueue.main.async {
                self.delegate.captureOutput(didOutput: sampleBuffer)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("Dropped frame")
                        
        var mode: CMAttachmentMode = 0
        let reason = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_DroppedFrameReasonInfo, attachmentModeOut: &mode)

        print("reason \(String(describing: reason))") // Optional(OutOfBuffers)
    }
    
    func isAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return false
        }
        return CMFormatDescriptionGetMediaType(formatDesc) == kCMMediaType_Audio
    }

    func isVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return false
        }
        return CMFormatDescriptionGetMediaType(formatDesc) == kCMMediaType_Video
    }
}
