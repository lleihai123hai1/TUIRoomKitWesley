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
    
    CMVideoFormatDescriptionRef _videoFormatDescription;
    CMAudioFormatDescriptionRef _audioFormatDescription;
    
    BOOL _haveWrittenFirstAudioFrame;
    size_t _totalWrittenBytes;
    CMTime _lastFramePTS;
    
    BOOL _isAudioFinished;
    BOOL _isVideoFinished;
    int64_t _lastVideoDurationMs;
    
    NSOperationQueue *_operationQueue;
    
    BOOL _isRecording;
    BOOL _startedSession;
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
    if (_audioFormatDescription) {
        CFRelease(_audioFormatDescription);
    }
    if (_videoFormatDescription) {
        CFRelease(_videoFormatDescription);
    }
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
    [self resetData];
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
}

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
    
}

- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame {
    
}

#pragma mark write
- (NSInteger)writeVideoFrame:(LocalVideoFrame *)frame duration:(int64_t)duration {
    CMBlockBufferRef dataBlock = NULL;
    size_t frame_size = frame.videoFrame.data.length;
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                       nil,
                                                       frame_size,
                                                       kCFAllocatorDefault,
                                                       NULL,
                                                       0,
                                                       frame_size,
                                                       kCMBlockBufferAssureMemoryNowFlag,
                                                       &dataBlock);
    if (status != kCMBlockBufferNoErr) {
      NSLog(@"Create CMBlockBufferRef failed, code: %d",status);
      return 0;
    }
    CMBlockBufferReplaceDataBytes((__bridge const void * _Nonnull)(frame.videoFrame.data), dataBlock, 0, frame_size);
    CMSampleTimingInfo timingInfo;
    timingInfo.presentationTimeStamp = CMTimeMake(frame.videoFrame.timestamp, kVideoTimeScale);
    timingInfo.duration = CMTimeMake(duration, kVideoTimeScale);

    size_t sampleSize[1] = {frame_size};

    CMSampleBufferRef sampleBuffer;
    status = CMSampleBufferCreate(kCFAllocatorDefault,
                                dataBlock,
                                true,  // dataReady
                                NULL,  // makeDataReadyCallback
                                NULL,  // makeDataReadyRefcon
                                _videoFormatDescription,
                                1,               // numSamples
                                1,               // numSampleTimingEntries
                                &timingInfo,     // CMSampleTimingInfo *sampleTimingArray
                                1,               // numSampleSizeEntries
                                sampleSize,      // sampleSizeArray
                                &sampleBuffer);  // sampleBufferOut
    CFRelease(dataBlock);
    if (status != noErr) {
        NSLog(@"Create CMSampleBuffer failed, code: %d",status);
        return 0;
    }

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    BOOL result = [self writeVideoSampleBuffer:sampleBuffer];
    if (result) {
        _totalWrittenBytes += frame_size;
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (CMTIME_IS_VALID(pts)) {
            _lastFramePTS = CMTimeMaximum(_lastFramePTS, pts);
        }
    }
    CFRelease(sampleBuffer);
    return result ? frame_size : NO;
}

- (BOOL)writeVideoSampleBuffer:(CMSampleBufferRef)videoSample {
    BOOL appended = NO;
    if (_videoWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting) {
        if (videoSample != nil) {
            if (!_startedSession) {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(videoSample);
                [_writer startSessionAtSourceTime:pts];
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
@end
