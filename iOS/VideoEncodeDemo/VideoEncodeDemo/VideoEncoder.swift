//
//  VideoEncoder.swift
//  MyclubDAO
//
//  Created by 王磊 on 2023/5/17.
//

import AVFoundation

class VideoEncoder : NSObject {
    
    static let VideoEncoderErrorDomain = "VideoEncoderErrorDomain"
    
    private let videoResolution: CGSize
    private let videoBitrate: Int
    private let audioSampleRate: Float
    var videoOutputURL: URL?
    
    private let encodingQueue: DispatchQueue
    private let videoOutput: AVCaptureVideoDataOutput
    private let audioOutput: AVCaptureAudioDataOutput
    private let recordingInterval: TimeInterval
    
    private var videoAssetWriter: AVAssetWriter?
    
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private var currentIndex = 0
    
    private(set) var canWriteVideo = false
    private(set) var isEncodingVideo = false
    private(set) var needToStopEncoding = false
    
    private var startTime: CMTime?
    private var startPTS: CMTime?
    
    private var initialSegmentData: Data?
    
    required init(videoResolution: CGSize, videoBitrate: Int, audioSampleRate: Float, encodingQueue: DispatchQueue, videoOutput: AVCaptureVideoDataOutput, audioOutput: AVCaptureAudioDataOutput, recordingInterval: TimeInterval) {
        self.videoResolution = videoResolution
        self.videoBitrate = videoBitrate
        self.audioSampleRate = audioSampleRate
        self.encodingQueue = encodingQueue
        self.videoOutput = videoOutput
        self.audioOutput = audioOutput
        self.recordingInterval = recordingInterval
        super.init()
        
        videoOutput.setSampleBufferDelegate(self, queue: encodingQueue)
        audioOutput.setSampleBufferDelegate(self, queue: encodingQueue)
    }
    
    func startEncoding() {
        print("[VideoEncoder] Will start video recoding")
        isEncodingVideo = true
        setupVideoAssetWriter()
        canWriteVideo = false
        startTime = nil
        print("[VideoEncoder] Did start video recoding")
    }
    
    private func setupVideoAssetWriter() {
        let videoAssetWriter = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue)!)
        videoAssetWriter.shouldOptimizeForNetworkUse = false
        videoAssetWriter.outputFileTypeProfile = .mpeg4AppleHLS
        videoAssetWriter.preferredOutputSegmentInterval = CMTime(seconds: recordingInterval, preferredTimescale: CMTimeScale(600))
        videoAssetWriter.delegate = self
        
        if self.videoInput == nil {
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoResolution.width,
                AVVideoHeightKey: videoResolution.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: videoBitrate,
                    AVVideoExpectedSourceFrameRateKey : 30,
                    AVVideoMaxKeyFrameIntervalKey : 15,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ] as [String : Any]
            ]
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            self.videoInput = videoInput
        }
        
        if self.audioInput == nil {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: audioSampleRate,
                AVEncoderBitRateKey: 192000,
                AVNumberOfChannelsKey: 1
            ]
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            self.audioInput = audioInput
        }
        
        if let videoInput {
            if videoAssetWriter.canAdd(videoInput) {
                videoAssetWriter.add(videoInput)
            }
        }
        if let audioInput {
            if videoAssetWriter.canAdd(audioInput) {
                videoAssetWriter.add(audioInput)
            }
        }
        
        self.videoAssetWriter = videoAssetWriter
    }
    
    func finishEncoding(completion: ((_ isSucceed: Bool) -> Void)?) throws {
        needToStopEncoding = true
        try finishSegmentEncoding(completion: completion)
    }
    
    func finishSegmentEncoding(completion: ((_ isSucceed: Bool) -> Void)?) throws {
        if !isEncodingVideo {
            completion?(true)
            return
        }
        
        isEncodingVideo = false
        
        if videoAssetWriter?.status == .writing {
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            videoAssetWriter?.finishWriting { [weak self] in
                self?.encodingQueue.sync {
                    self?.canWriteVideo = false
                    self?.videoAssetWriter = nil
                    self?.videoInput = nil
                    self?.audioInput = nil
                    print("[VideoEncoder] Video encoding finished")
                    completion?(true)
                }
            }
        } else {
            if let error = videoAssetWriter?.error {
                print("[VideoEncoder] \(error)")
                throw error
            }
            completion?(false)
        }
    }
}

// MARK: - AVAssetWriterDelegate

extension VideoEncoder : AVAssetWriterDelegate {
    
    func assetWriter(_ writer: AVAssetWriter, didOutputSegmentData segmentData: Data, segmentType: AVAssetSegmentType, segmentReport: AVAssetSegmentReport?) {
        encodingQueue.async {
            do {
                if segmentType == .initialization {
                    self.initialSegmentData = segmentData
                } else {
                    let fileName = "SegmentRecordVideo\(self.currentIndex).m4s"
                    let segmentFilePath = String.filePathForDocumentDirectory(fileName: fileName, relativePath: "/HighQualityRecordings")
                    let segmentFileURL = URL(fileURLWithPath: segmentFilePath)
                    self.videoOutputURL = segmentFileURL
                    
                    var data = Data()
                    if let initialSegmentData = self.initialSegmentData {
                        data.append(initialSegmentData)
                    }
                    data.append(segmentData)
                    if !FileManager.default.fileExists(atPath: segmentFileURL.path) {
                        FileManager.default.createFile(atPath: segmentFileURL.path, contents: nil, attributes: nil)
                    }
                    try data.write(to: segmentFileURL)
                    self.currentIndex += 1
                    print("[VideoEncoder] Writing \(fileName) to local.")
                }
            } catch {
                print("[VideoEncoder] Error writing segment data to file: \(error)")
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoEncoder : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        encodingQueue.async {
            if self.needToStopEncoding {
                return
            }
            
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            let startPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if self.startPTS == nil {
                // This is the first sample of a new segment
                self.startPTS = startPTS
            }
            
            // Replace the timestamp of the sample
            guard let newSampleBuffer = self.adjustTimestampOfSampleBuffer(sampleBuffer, by: self.startPTS!) else { return }
            
            if self.isEncodingVideo {
                if connection == self.videoOutput.connection(with: .video) {
                    do {
                        try self.appendSampleBuffer(newSampleBuffer, mediaType: .video)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
                
                if connection == self.audioOutput.connection(with: .audio) {
                    do {
                        try self.appendSampleBuffer(newSampleBuffer, mediaType: .audio)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func adjustTimestampOfSampleBuffer(_ sampleBuffer: CMSampleBuffer, by subtracting: CMTime) -> CMSampleBuffer? {
        // Create a copy of the original sample buffer
        var newSampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timingInfo)

        // Subtract the base timestamp
        timingInfo.presentationTimeStamp = CMTimeSubtract(timingInfo.presentationTimeStamp, subtracting)

        // Create a new sample buffer with the new timing info
        let err = CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleBufferOut: &newSampleBuffer)
        
        if err == noErr {
            return newSampleBuffer
        } else {
            // Handle error
            return nil
        }
    }

    private func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) throws {
        guard CMSampleBufferIsValid(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            let encodeError = NSError(domain: VideoEncoder.VideoEncoderErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "[VideoEncoder] Invalid sampleBuffer."])
            throw encodeError
        }
        
        // For video input, make sure the format description is of video media type
        if mediaType == .video {
            guard CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video else {
                let encodeError = NSError(domain: VideoEncoder.VideoEncoderErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "[VideoEncoder] Invalid format description for video input."])
                throw encodeError
            }
        }
        
        // For audio input, make sure the format description is of audio media type
        if mediaType == .audio {
            guard CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio else {
                let encodeError = NSError(domain: VideoEncoder.VideoEncoderErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "[VideoEncoder] Invalid format description for audio input."])
                throw encodeError
            }
        }
        
        if !canWriteVideo, videoAssetWriter?.status != .writing {
            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoAssetWriter?.initialSegmentStartTime = presentationTime
            videoAssetWriter?.startWriting()
            videoAssetWriter?.startSession(atSourceTime: presentationTime)
            canWriteVideo = true
        }
        
        if mediaType == .video {
            if videoInput?.isReadyForMoreMediaData ?? false, CMSampleBufferDataIsReady(sampleBuffer) {
                videoInput?.append(sampleBuffer)
            } else {
                let encodeError = NSError(domain: VideoEncoder.VideoEncoderErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "[VideoEncoder] Video input not ready."])
                throw encodeError
            }
        }
        
        if mediaType == .audio {
            if audioInput?.isReadyForMoreMediaData ?? false, CMSampleBufferDataIsReady(sampleBuffer) {
                audioInput?.append(sampleBuffer)
            } else {
                let encodeError = NSError(domain: VideoEncoder.VideoEncoderErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "[VideoEncoder] Audio input not ready."])
                throw encodeError
            }
        }
    }
}
