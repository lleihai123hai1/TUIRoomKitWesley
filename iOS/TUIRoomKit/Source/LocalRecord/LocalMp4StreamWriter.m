//
//  LocalMp4StreamWriter.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalMp4StreamWriter.h"
#include <AVFoundation/AVFoundation.h>
#import "LocalRecordHeader.h"

static int kVideoTimeScale = 1000;

@interface LocalMp4StreamWriter()
{
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
    NSDictionary *audioSetting = @{ AVEncoderBitRatePerChannelKey : @(_audioFrame.audioFrame.sampleRate),
                                    AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                    AVNumberOfChannelsKey : @(_audioFrame.audioFrame.channels),
                                    AVSampleRateKey : @(44100) };
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
    //每像素比特
    CGFloat bitsPerPixel = 12.0;
    NSInteger bitsPerSecond = numPixels * bitsPerPixel;
    
    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(15),
                                             AVVideoMaxKeyFrameIntervalKey : @(10),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    //视频属性
    NSDictionary *videoSetting = @{ AVVideoCodecKey : AVVideoCodecTypeH264,
                                    AVVideoWidthKey : @(size.height * 2),
                                    AVVideoHeightKey : @(size.width * 2),
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
    [self writeLocalVideoFrame:localVideoFrame];
}

#pragma mark video write
- (BOOL)writeLocalVideoFrame:(LocalVideoFrame *)frame {
    [self startWriting];
    CMSampleBufferRef videoSample = [self sampleBufferFromVideoData:frame.pixelBuffer time:kCMTimeInvalid];
    return [self writeVideoSampleBuffer:videoSample];
}

- (BOOL)writeVideoSampleBuffer:(CMSampleBufferRef)videoSample {
    BOOL appended = NO;
    if (_videoWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting) {
        if (videoSample != nil) {
            if (!_startedSession) {
//                CMTime pts = CMSampleBufferGetPresentationTimeStamp(videoSample);
                CMTime pts = CMTimeMakeWithSeconds(2.5, 30);
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

    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (!videoInfo) {
        return NULL;
    }

    CMSampleTimingInfo timing = {CMTimeMake(1, time.timescale), time, kCMTimeInvalid};
    CMSampleBufferRef sampleBuffer = NULL;
    CMSampleBufferCreateForImageBuffer(
    kCFAllocatorDefault, pixelBuffer, YES, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CFRelease(videoInfo);
    return sampleBuffer;
}

#pragma mark audio write
- (BOOL)writeLocalAudioFrame:(LocalAudioFrame *)frame {
    [self startWriting];
    CMSampleBufferRef audioSample = [self sampleBufferFromAudioData:frame.audioFrame.data sampleRate:frame.audioFrame.sampleRate];
    return [self writeAudioSampleBuffer:audioSample];
}

- (BOOL)writeAudioSampleBuffer:(CMSampleBufferRef)audioSample {
    BOOL appended = NO;
    if (_audioWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting) {
        if (audioSample != nil) {
            if (!_startedSession) {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(audioSample);
                pts = CMTimeMakeWithSeconds(2.5, 30);
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
- (CMSampleBufferRef)sampleBufferFromAudioData:(NSData *)audioData sampleRate:(Float64)sampleRate {

    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = sampleRate;
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
    audioBufferList.mBuffers[0].mNumberChannels = 1;
    audioBufferList.mBuffers[0].mDataByteSize = (UInt32)[audioData length];
    audioBufferList.mBuffers[0].mData = (void *)[audioData bytes];

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

    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    status = CMSampleBufferCreate(kCFAllocatorDefault,
                                  blockBuffer,
                                  true,
                                  NULL,
                                  NULL,
                                  formatDesc,
                                  (CMItemCount)1,
                                  (CMItemCount)0,
                                  &timing,
                                  1,
                                  &audioBufferList,
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
