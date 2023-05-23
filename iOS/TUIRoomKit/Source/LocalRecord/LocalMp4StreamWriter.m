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
    if ([self setUpWriter]) {
        [_writer startWriting];
    }
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
    [self clearData];
}

- (void)clearData {
    _writer = nil;
    _audioWriterInput = nil;
    _videoWriterInput = nil;
}

- (BOOL)setUpWriter {
    NSError *error = nil;
    NSURL *fileUrl = [NSURL fileURLWithPath:self.outputFilePath];
    // 根据文件名扩展类型，确定具体容器格式
    AVFileType mediaFileType = AVFileTypeMPEG4;
    _writer = [[AVAssetWriter alloc] initWithURL:fileUrl fileType:mediaFileType error:&error];
    _writer.shouldOptimizeForNetworkUse = YES;  // 把 moov 放在文件的前面
    if (_writer == nil) {
      NSLog(@"Create AVAssetWriter failed, error: %@",error.localizedDescription);
      return NO;
    }
    
    CGSize size =  [UIScreen mainScreen].bounds.size;
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

    NSDictionary *audioSetting = @{ AVEncoderBitRatePerChannelKey : @(28000),
                                    AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                    AVNumberOfChannelsKey : @(1),
                                    AVSampleRateKey : @(22050) };
    _audioWriterInput =  [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSetting];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    if ([_writer canAddInput:_audioWriterInput]) {
      [_writer addInput:_audioWriterInput];
    } else {
        NSLog(@"Add audio input failed");
        return NO;
    }
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSetting];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    _videoWriterInput.transform = CGAffineTransformMakeRotation(M_PI/2.0);
    _videoWriterInput.mediaTimeScale = kVideoTimeScale;
    if ([_writer canAddInput:_videoWriterInput]) {
        [_writer addInput:_videoWriterInput];
    } else {
        NSLog(@"Add video input failed");
        return NO;
    }
    return YES;
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
    [self writeLocalAudioFrame:audioFrame];
}

- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame {
    [self writeVideoFrame:localVideoFrame];
}

#pragma mark video write
- (BOOL)writeVideoFrame:(LocalVideoFrame *)frame {
    CMSampleBufferRef videoSample = NULL;
    return [self writeVideoSampleBuffer:videoSample];
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

#pragma mark audio write
- (BOOL)writeLocalAudioFrame:(LocalAudioFrame *)frame {
    CMSampleBufferRef audioSample = NULL;
    return [self writeAudioSampleBuffer:audioSample];
}

- (BOOL)writeAudioSampleBuffer:(CMSampleBufferRef)audioSample {
    BOOL appended = NO;
    if (_audioWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting) {
        if (audioSample != nil) {
            if (!_startedSession) {
                CMTime pts = CMSampleBufferGetPresentationTimeStamp(audioSample);
                [_writer startSessionAtSourceTime:pts];
                _startedSession = YES;
            }
            appended = [_audioWriterInput appendSampleBuffer:audioSample];
            NSLog(@"Write video: %@",(appended ? @"yes" : @"no"));
        }
    } else {
      NSLog(@"MP4Writer:appendVideo not appended, status= %ld",(long)_writer.status);
    }
    return appended;
}

@end
