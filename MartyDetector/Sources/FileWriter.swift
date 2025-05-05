import AVFoundation
import CoreVideo
import opencv2

class FileWriter: NSObject {
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private let frameSize: Size2i
    private let fps: Int32
    private var frames: Int64 = 0
    private var startTime: CMTime?
    
    init(url: URL, fps: Int32, frameSize: Size2i) throws {
        assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: frameSize.width,
            AVVideoHeightKey: frameSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: (300 * 8 * 1000)
            ]
        ]
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true

        assetWriter.add(videoInput)

        assetWriter.add(audioInput)
        self.frameSize = frameSize
        self.fps = fps

        super.init()
    }

    func stopRecording() async {
        videoInput.markAsFinished()
        audioInput.markAsFinished()
        await assetWriter.finishWriting()
    }

    func writeImage(image: CGImage, presentationTime: CMTime) {
        if startTime == nil {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: presentationTime)
            startTime = presentationTime
        }

        // writer status check
        if assetWriter.status != .writing {
            print("assetWriter.status: \(assetWriter.status). Error: \(assetWriter.error?.localizedDescription ?? "Unknown error")")
            return
        }

        // Make writeFrame() a blocking call.
        while !videoInput.isReadyForMoreMediaData {
            print("AVF: waiting to write video data.")
            // Sleep 1 msec.
            usleep(1000)
        }

        if image.height != frameSize.height || image.width != frameSize.width {
            print("Frame size does not match video size.")
            return
        }

        //CGImage -> CVPixelBuffer conversion
        guard let dataProvider = image.dataProvider else {
            print("Couldn't get data provider.")
            return
        }
        guard let cfData = dataProvider.data else {
            print("Couldn't get cfData.")
            return
        }

        // Step 2: Retain CFData manually
        let retainedCFData = Unmanaged.passRetained(cfData)
        let retainedCFDataOpaque = retainedCFData.toOpaque()

        // Step 3: Define release callback
        let releaseCallback: CVPixelBufferReleaseBytesCallback = { releaseRefCon, baseAddress in
            // Step 4: Release the retained CFData
            let unmanaged = Unmanaged<CFData>.fromOpaque(releaseRefCon!)
            unmanaged.release()
        }
        
        let dataPointer = CFDataGetBytePtr(cfData)
        guard let unsafePointer = UnsafeMutableRawPointer(mutating: dataPointer) else {
            print("Couldn't get unsafePointer.")
            return
        }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            Int(frameSize.width),
            Int(frameSize.height),
            kCVPixelFormatType_24RGB,
            unsafePointer,
            image.bytesPerRow,
            releaseCallback,
            retainedCFDataOpaque,
            nil,
            &pixelBuffer
        )
        guard let pixelBuffer = pixelBuffer else {
            print("Failed to create pixelbuffer.")
            return
        }
 
        var videoInfo: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &videoInfo
        )
        guard let videoInfo = videoInfo else {
            print("Failed to create format description")
            return
        }
        // Create CMSampleTimingInfo
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: videoInfo,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        guard let sampleBuffer = sampleBuffer else {
            print("Failed to create cmsamplebuffer.")
            return
        }
        if videoInput.append(sampleBuffer) {
            frames += 1
        }                
    }

    func writeAudioBuffer(buffer: CMSampleBuffer) {
        if startTime == nil {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(buffer)

            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: presentationTime)
            startTime = presentationTime
        }

        audioInput.append(buffer)
    }
}
