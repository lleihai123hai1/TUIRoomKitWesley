//
//  LocalMp4StreamWriter.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalMp4StreamWriter.h"
#include <AVFoundation/AVFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <Foundation/Foundation.h>
#import "LocalRecordHeader.h"

static int kVideoTimeScale = 1000;

@interface LocalMp4StreamWriter(){
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInput *_audioWriterInput;
    
    BOOL _haveWrittenFirstAudioFrame;
    size_t _totalWrittenBytes;
    CMTime _lastFramePTS;
    
    BOOL _isAudioFinished;
    BOOL _isVideoFinished;
    int64_t _lastVideoDurationMs;
    
    NSOperationQueue *_operationQueue;
    
    BOOL _isRecording;
    BOOL _startedSession;
    
    LocalVideoFrame* _videoFrame;
    LocalAudioFrame* _audioFrame;
}
@property (nonatomic, strong) NSString *outputFilePath;
@end

@implementation LocalMp4StreamWriter
- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetData];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"LocalMp4StreamWriter dealloc");
}

- (void)resetData{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.outputFilePath error:nil];
    }
    _haveWrittenFirstAudioFrame = NO;
    _totalWrittenBytes = 0;
    _lastFramePTS = CMTimeMake(0, kVideoTimeScale);
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = 1;
    _isAudioFinished = NO;
    _isVideoFinished = NO;
    _lastVideoDurationMs = 0;
    _startedSession = NO;
}

- (void)startRecording {
    if (_isRecording) {
        return;
    }
    [self resetData];
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
    [_audioWriterInput markAsFinished];
    [_videoWriterInput markAsFinished];
    [_writer finishWritingWithCompletionHandler:^{
        NSLog(@"finishWritingWithCompletionHandler");
    }];
    [self clearData];
}

- (void)clearData {
    _writer = nil;
    _audioWriterInput = nil;
    _videoWriterInput = nil;
    _videoFrame = nil;
    _audioFrame  = nil;
}

- (void)startWriting {
    if ((!_audioFrame || !_videoFrame) || _writer) {
        return;
    }
    [self setUpWriter];
    [self setAudioWriterInput];
    [self setVideoWriterInput];
    [_writer startWriting];
}

- (void)setUpWriter {
    if (_writer) {
        return;
    }
    NSError *error = nil;
    NSURL *fileUrl = [NSURL fileURLWithPath:self.outputFilePath];
    // 根据文件名扩展类型，确定具体容器格式
    AVFileType mediaFileType = AVFileTypeMPEG4;
    _writer = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:mediaFileType error:&error];
    _writer.shouldOptimizeForNetworkUse = YES;
}

- (void)setAudioWriterInput {
    if (_audioWriterInput || !_audioFrame || !_writer) {
        return;
    }
    NSDictionary *audioSetting = @{AVFormatIDKey : @(kAudioFormatLinearPCM),
                                   AVLinearPCMBitDepthKey : @(16),
                                        AVLinearPCMIsFloatKey : @(NO),
                                        AVLinearPCMIsBigEndianKey : @(NO),
                                        AVLinearPCMIsNonInterleaved : @(NO),
                                        AVNumberOfChannelsKey : @(_audioFrame.audioFrame.channels),
                                        AVSampleRateKey : @(_audioFrame.audioFrame.sampleRate) };
    _audioWriterInput =  [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSetting];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    if ([_writer canAddInput:_audioWriterInput]) {
        [_writer addInput:_audioWriterInput];
    }
    
}

- (void)setVideoWriterInput {
    if (_videoWriterInput || !_videoFrame || !_writer) {
        return;
    }
    
    CGSize size =  CGSizeMake(_videoFrame.videoFrame.width, _videoFrame.videoFrame.height);
    NSInteger numPixels = size.width * size.height;
//    //每像素比特
    CGFloat bitsPerPixel = 12.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(15),
                                             AVVideoMaxKeyFrameIntervalKey : @(10),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    //视频属性
    
    NSDictionary *videoSetting = @{ AVVideoCodecKey : AVVideoCodecTypeH264,
                                    AVVideoWidthKey : @(size.height),
                                    AVVideoHeightKey : @(size.width),
                                    AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                    AVVideoCompressionPropertiesKey : compressionProperties };
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSetting];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    _videoWriterInput.transform = CGAffineTransformMakeRotation(_videoFrame.videoFrame.rotation*M_PI/2.0);
    _videoWriterInput.mediaTimeScale = kVideoTimeScale;
    if ([_writer canAddInput:_videoWriterInput]) {
        [_writer addInput:_videoWriterInput];
    }
}

#pragma mark get/set
- (NSString *)outputFilePath {
    if (!_outputFilePath) {
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSFileManager *manager = [NSFileManager defaultManager];
        path = [path stringByAppendingPathComponent:@"LocalRecord"];
        BOOL isDirectory = YES;
        if (![manager fileExistsAtPath:path isDirectory:&isDirectory]) {
            NSError *error = nil;
            [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                NSLog(@"outputFilePath create error: %@", error.localizedDescription);
            }
        }
        _outputFilePath = [path stringByAppendingString:@"/tmp.mp4"];
    }
    return _outputFilePath;
}

#pragma mark LocalProcessAudioFrameDelegate & LocalProcessVideoFrameDelegate
- (void)onCallbackLocalAudioFrame:(LocalAudioFrame*)audioFrame {
    _audioFrame = audioFrame;
    [self writeLocalAudioFrame:audioFrame];
}

- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame {
    _videoFrame = localVideoFrame;
//    [self writeLocalVideoFrame:localVideoFrame];
}

#pragma mark video write
- (void)writeLocalVideoFrame:(LocalVideoFrame *)frame {
    [self startWriting];
    CMSampleBufferRef videoSample = [self sampleBufferFromVideoData:frame.videoFrame.pixelBuffer time:kCMTimeInvalid];
    [self writeVideoSampleBuffer:videoSample];
    CFRelease(videoSample);
}

- (BOOL)writeVideoSampleBuffer:(CMSampleBufferRef)videoSample {
    BOOL appended = NO;
    if (_videoWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting && CMSampleBufferDataIsReady(videoSample)) {
        if (videoSample != nil) {
            if (!_startedSession) {
                [_writer startSessionAtSourceTime:kCMTimeZero];
                _startedSession = YES;
            }
            appended = [_videoWriterInput appendSampleBuffer:videoSample];
            NSLog(@"Write video: %@",(appended ? @"yes" : @"no"));
        }
    } else {
        NSLog(@"MP4Writer:appendVideo not appended, status= %ld",(long)_writer.status);
    }
    return appended;
}

- (CMSampleBufferRef)sampleBufferFromVideoData:(CVPixelBufferRef)pixelBuffer time:(CMTime)time {
    if (!pixelBuffer) {
        return NULL;
    }
    CMSampleBufferRef sampleBuffer = NULL;
    CMFormatDescriptionRef formatDescription = NULL;
    CMSampleTimingInfo timing = { kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid };

    // Get the format description from the pixel buffer
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDescription);

    // Create the sample buffer using the pixel buffer and format description
    CMSampleBufferCreateReadyWithImageBuffer(NULL, pixelBuffer, formatDescription, &timing, &sampleBuffer);

    // Release the format description
    CFRelease(formatDescription);
    return sampleBuffer;
}

#pragma mark audio write
- (void)writeLocalAudioFrame:(LocalAudioFrame *)frame {
    [self startWriting];
    CMSampleBufferRef audioSample = [self sampleBufferFromAudioData:frame];
    [self writeAudioSampleBuffer:audioSample];
    CFRelease(audioSample);
}

- (BOOL)writeAudioSampleBuffer:(CMSampleBufferRef)audioSample {
    BOOL appended = NO;
    if (_audioWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting && CMSampleBufferDataIsReady(audioSample)) {
        if (audioSample != nil) {
            if (!_startedSession) {
                [_writer startSessionAtSourceTime:kCMTimeZero];
                _startedSession = YES;
            }
            appended = [_audioWriterInput appendSampleBuffer:audioSample];
            NSLog(@"Write audio: %@",(appended ? @"yes" : @"no"));
        }
    } else {
      NSLog(@"MP4Writer:appendAudio not appended, status= %ld",(long)_writer.status);
    }
    return appended;
}


// NSData转换为CMSampleBufferRef
- (CMSampleBufferRef)sampleBufferFromAudioData:(LocalAudioFrame *)frame {

    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = frame.audioFrame.sampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBitsPerChannel = 16;
    audioFormat.mReserved = 0;

    CMFormatDescriptionRef formatDesc = NULL;
    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
                                                      &audioFormat,
                                                      0,
                                                      NULL,
                                                      0,
                                                      NULL,
                                                      NULL,
                                                      &formatDesc);
    if (status != noErr) {
        NSLog(@"Failed to create audio format description");
        return nil;
    }

    CMSampleBufferRef sampleBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    AudioBufferList audioBufferList;

    audioBufferList.mNumberBuffers = 1;
    audioBufferList.mBuffers[0].mNumberChannels = audioFormat.mChannelsPerFrame;
    audioBufferList.mBuffers[0].mDataByteSize = (UInt32)[frame.audioFrame.data length];
    audioBufferList.mBuffers[0].mData = (void *)[frame.audioFrame.data bytes];

    status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                (void *)audioBufferList.mBuffers[0].mData,
                                                audioBufferList.mBuffers[0].mDataByteSize,
                                                kCFAllocatorNull,
                                                NULL,
                                                0,
                                                audioBufferList.mBuffers[0].mDataByteSize,
                                                0,
                                                &blockBuffer);
    if (status != noErr) {
        NSLog(@"Failed to create block buffer");
        return nil;
    }

    size_t sampleSize[1] = {(size_t)frame.audioFrame.data.length};
    CMSampleTimingInfo timingInfo;
    timingInfo.presentationTimeStamp = CMTimeMake(frame.audioFrame.timestamp, kVideoTimeScale);
    // DTS MUST NOT always be 0, otherwise error -16364 will be encountered
    timingInfo.decodeTimeStamp = CMTimeMake(frame.audioFrame.timestamp, kVideoTimeScale);
    timingInfo.duration = CMTimeMake(50, kVideoTimeScale);

    status = CMSampleBufferCreate(kCFAllocatorDefault,
                                  blockBuffer,
                                  true,
                                  NULL,
                                  NULL,
                                  formatDesc,
                                  1,
                                  1,
                                  &timingInfo,
                                  1,
                                  sampleSize,
                                  &sampleBuffer);
    
    
    if (status != noErr) {
        NSLog(@"Failed to create sample buffer");
        return nil;
    }

    CFRelease(blockBuffer);
    CFRelease(formatDesc);
    return sampleBuffer;
}

@end
