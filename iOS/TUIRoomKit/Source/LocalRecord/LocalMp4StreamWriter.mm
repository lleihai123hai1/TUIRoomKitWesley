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
#import "KFVideoEncoder.h"
#import "KFAudioEncoder.h"
#import "KFAudioTools.h"
#import "KFVideoPacketExtraData.h"
#import "LocalRecordTools.h"
#import "KFAudioConfig.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

//使用 AVAssetWriter 创作片段 MPEG-4 内容 参考：https://toutiao.io/posts/7r58mpe/preview

static int kVideoTimeScale = 1000;
//参考链接：https://zhuanlan.zhihu.com/p/515281023
//用工具播放 H.264/H.265 文件
//ffplay -i video_tmp.h264
//ffplay -i video_tmp.h265

//参考链接：https://zhuanlan.zhihu.com/p/514346313
//用工具播放 PCM 文件
//ffplay -ar 48000 -channels 1 -f s16le -i audio_tmp.pcm

//ffmpeg -i video_tmp.h265 -i audio_tmp.acc -vcodec copy -f mp4 test.mp4

// 从mp4文件中导出音频
//ffmpeg -i tmp.mp4 -vn -c:a copy out.m4a

// ffmpeg批量处理m4s合并成mp4
//ffmpeg -i "concat:SegmentRecordVideo_1.m4s|SegmentRecordVideo_2.m4s|SegmentRecordVideo_3.m4s" -c copy output.mp4

//ffmpeg切片segment
//ffmpeg -i output.mp4 -hls_segment_filename 'file%03d.m4s' out.m3u8
//ffplay -i out.m3u8

//仅生成音频mp3
//ffmpeg -i audio.m4s -f mp3 audio.mp3

@interface LocalMp4StreamWriter()<AVAssetWriterDelegate>{
    uint64_t _startedSession;
}
@property (nonatomic, strong) NSString *outputFilePath;

@property (nonatomic, strong) KFVideoEncoderConfig *videoEncoderConfig;
@property (nonatomic, strong) KFVideoEncoder *videoEncoder;
@property (nonatomic, strong) NSFileHandle *videoFileHandle;
@property (nonatomic, strong) NSString *videoFilePath;


@property (nonatomic, strong) KFAudioEncoder *audioEncoder;
@property (nonatomic, strong) NSString *audioFilePath;
@property (nonatomic, strong) NSFileHandle *audioFileHandle;

@property (nonatomic, strong) NSString *audioPcmFilePath;
@property (nonatomic, strong) NSFileHandle *audioPcmFileHandle;

@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoWriterInput;
@property (nonatomic, strong) AVAssetWriterInput *audioWriterInput;
@property (nonatomic, assign) BOOL isRecording;

@property (nonatomic, strong) NSData *initialSegmentData;
@property (nonatomic, assign) NSInteger currentIndex;
@end

@implementation LocalMp4StreamWriter
- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    NSLog(@"LocalMp4StreamWriter dealloc");
}

- (void)clearTmpFile{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.videoFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.videoFilePath error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.audioFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.audioFilePath error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.audioPcmFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.audioPcmFilePath error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.outputFilePath error:nil];
    }
    
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:@"LocalRecordSegment"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    
    [[NSFileManager defaultManager] createFileAtPath:self.audioFilePath contents:nil attributes:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.audioPcmFilePath contents:nil attributes:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.videoFilePath contents:nil attributes:nil];
    _currentIndex = 0;
}

- (void)startRecording {
    if (_isRecording) {
        return;
    }
    [self clearTmpFile];
    [self clearData];
    [self startWriting];
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
    [self stopWriting];
    [self clearData];
}

- (void)clearData {
    if (_videoFileHandle) {
        [_videoFileHandle closeFile];
        _videoFileHandle = nil;
    }
    if (_audioFileHandle) {
        [_audioFileHandle closeFile];
        _audioFileHandle = nil;
    }
    
    if (_audioPcmFileHandle) {
        [_audioPcmFileHandle closeFile];
        _audioPcmFileHandle = nil;
    }
    _videoWriterInput = nil;
    _audioWriterInput = nil;
    _writer = nil;
    _startedSession = NO;
    _initialSegmentData = nil;
}


- (void)startWriting {
    if ([self.writer canAddInput:self.videoWriterInput]) {
        [self.writer addInput:self.videoWriterInput];
    }
    if ([self.writer canAddInput:self.audioWriterInput]) {
        [self.writer addInput:self.audioWriterInput];
    }
    [self.writer startWriting];
}

- (void)stopWriting {
    [self.audioWriterInput markAsFinished];
    [self.videoWriterInput markAsFinished];
    [self.writer finishWritingWithCompletionHandler:^{
        NSLog(@"finishWritingWithCompletionHandler");
    }];
}
#pragma mark get/set

- (AVAssetWriter *)writer {
    if (!_writer) {
        if (@available(iOS 14.0, *)) {
            //使用 AVAssetWriter 创作片段 MPEG-4 内容
            _writer = [[AVAssetWriter alloc] initWithContentType:UTTypeMPEG4Movie];
            _writer.outputFileTypeProfile = AVFileTypeProfileMPEG4AppleHLS;
            _writer.preferredOutputSegmentInterval = CMTimeMake(6.0, 1);//每秒的帧数 value/timescale=6 也就是6秒一帧
            _writer.initialSegmentStartTime = CMTimeMake([TRTCCloud generateCustomPTS],kVideoTimeScale);
        } else {
            // Fallback on earlier versions
        }
        _writer.shouldOptimizeForNetworkUse = YES;
        if (@available(iOS 14.0, *)) {
            _writer.delegate = self;
        } else {
            // Fallback on earlier versions
        }
    }
    return _writer;
}

- (AVAssetWriterInput *)videoWriterInput {
    if (!_videoWriterInput) {
        CGSize size =  CGSizeMake(1080,1920);
        NSInteger bitsPerSecond = 6000*1000;//10*size.width * size.height;
        NSDictionary * writerOutputSettings =@{
            AVVideoCodecKey : AVVideoCodecTypeH264,
            AVVideoWidthKey : @(size.width),
            AVVideoHeightKey :@(size.height),
            AVVideoCompressionPropertiesKey : @{
                AVVideoExpectedSourceFrameRateKey:@30,
                AVVideoMaxKeyFrameIntervalKey : @3,
                AVVideoAverageBitRateKey : @(bitsPerSecond),
                AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel,
            }
        };
        _videoWriterInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                   outputSettings: writerOutputSettings];
        _videoWriterInput.expectsMediaDataInRealTime = YES;
        _videoWriterInput.mediaTimeScale = kVideoTimeScale;
    }
    return _videoWriterInput;
}

- (AVAssetWriterInput *)audioWriterInput {
    if (!_audioWriterInput) {
        NSDictionary *audioSetting = @{AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                       AVNumberOfChannelsKey : @([KFAudioConfig defaultConfig].channels),
                                       AVSampleRateKey : @([KFAudioConfig defaultConfig].sampleRate),
                                       AVEncoderBitRateKey:@(192000),
        };
        _audioWriterInput =  [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSetting];
    }
    return _audioWriterInput;
}

-(KFVideoEncoderConfig *)videoEncoderConfig {
   if (!_videoEncoderConfig) {
       _videoEncoderConfig = [[KFVideoEncoderConfig alloc] init];
   }
   
   return _videoEncoderConfig;
}

- (KFVideoEncoder *)videoEncoder {
   if (!_videoEncoder) {
       _videoEncoder = [[KFVideoEncoder alloc] initWithConfig:self.videoEncoderConfig];
       __weak typeof(self) weakSelf = self;
       _videoEncoder.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
           // 保存编码后的数据。
           NSMutableData *data = [LocalRecordTools changeSampleBufferToData:sampleBuffer];
           if (data && weakSelf.isRecording) {
               [weakSelf.videoFileHandle writeData:data];
           } else {
               NSLog(@"data change error");
           }
       };
   }
   return _videoEncoder;
}

- (KFAudioEncoder *)audioEncoder {
    if (!_audioEncoder) {
        __weak typeof(self) weakSelf = self;
        _audioEncoder = [[KFAudioEncoder alloc] initWithAudioBitrate:96000];
        _audioEncoder.errorCallBack = ^(NSError* error) {
            NSLog(@"KFAudioEncoder error:%zi %@", error.code, error.localizedDescription);
        };
        // 音频编码数据回调。在这里将 AAC 数据写入文件。
        _audioEncoder.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            if (sampleBuffer && weakSelf.isRecording) {
                // 1、获取音频编码参数信息。
                AudioStreamBasicDescription audioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
                
                // 2、获取音频编码数据。AAC 裸数据。
                CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                size_t totolLength;
                char *dataPointer = NULL;
                CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totolLength, &dataPointer);
                if (totolLength == 0 || !dataPointer) {
                    return;
                }
                
                // 3、在每个 AAC packet 前先写入 ADTS 头数据。
                // 由于 AAC 数据存储文件时需要在每个包（packet）前添加 ADTS 头来用于解码器解码音频流，所以这里添加一下 ADTS 头。
                [weakSelf.audioFileHandle writeData:[KFAudioTools adtsDataWithChannels:audioFormat.mChannelsPerFrame sampleRate:audioFormat.mSampleRate rawDataLength:totolLength]];
                
                // 4、写入 AAC packet 数据。
                [weakSelf.audioFileHandle writeData:[NSData dataWithBytes:dataPointer length:totolLength]];
            }
        };
    }
    
    return _audioEncoder;
}

- (NSFileHandle *)videoFileHandle {
   if (!_videoFileHandle) {
       _videoFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.videoFilePath];
   }
   return _videoFileHandle;
}

- (NSFileHandle *)audioFileHandle {
   if (!_audioFileHandle) {
       _audioFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.audioFilePath];
   }
   return _audioFileHandle;
}

- (NSFileHandle *)audioPcmFileHandle {
   if (!_audioPcmFileHandle) {
       _audioPcmFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.audioPcmFilePath];
   }
   return _audioPcmFileHandle;
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

- (NSString *)videoFilePath {
    if (!_videoFilePath) {
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
        NSString *fileName = @"/video_tmp.h264";
        if (self.videoEncoderConfig.codecType == kCMVideoCodecType_HEVC) {
            fileName = @"/video_tmp.h265";
        }
        _videoFilePath = [path stringByAppendingString:fileName];
    }
    return _videoFilePath;
}


- (NSString *)audioFilePath {
    if (!_audioFilePath) {
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
        NSString *fileName = @"/audio_tmp.acc";
        _audioFilePath = [path stringByAppendingString:fileName];
    }
    return _audioFilePath;
}

- (NSString *)audioPcmFilePath {
    if (!_audioPcmFilePath) {
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
        NSString *fileName = @"/audio_tmp.pcm";
        _audioPcmFilePath = [path stringByAppendingString:fileName];
    }
    return _audioPcmFilePath;
}


#pragma mark LocalProcessAudioFrameDelegate & LocalProcessVideoFrameDelegate
- (void)onCallbackLocalAudioFrame:(LocalAudioFrame*)localAudioFrame {
    if (_isRecording) {
        if (!_startedSession) {
            _startedSession = YES;;
            [self.writer startSessionAtSourceTime:CMTimeMake(localAudioFrame.audioFrame.timestamp, kVideoTimeScale)];
        }
        CMSampleBufferRef audioSample = [LocalRecordTools sampleBufferFromAudioData:localAudioFrame];
        [self.audioEncoder encodeSampleBuffer:audioSample];
        [self appendAudioSampleBuffer:audioSample];
        CFRelease(audioSample);
        [self.audioPcmFileHandle writeData:localAudioFrame.audioFrame.data];
    }
}

- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame {
    if (_isRecording) {
        [self.videoEncoder encodePixelBuffer:localVideoFrame.videoFrame.pixelBuffer ptsTime:kCMTimePositiveInfinity];
        if (!_startedSession) {
            _startedSession = YES;;
            [self.writer startSessionAtSourceTime:CMTimeMake(localVideoFrame.videoFrame.timestamp, kVideoTimeScale)];
        }
        CMSampleBufferRef videoSample = [LocalRecordTools createSampleBufferFromPixelBuffer:localVideoFrame.videoFrame.pixelBuffer time:CMTimeMake(localVideoFrame.videoFrame.timestamp, kVideoTimeScale)];
        [self appendVideoSampleBuffer:videoSample];
        CFRelease(videoSample);
    }
}


#pragma mark AVAssetWriterDelegate
- (void)assetWriter:(AVAssetWriter *)writer didOutputSegmentData:(NSData *)segmentData segmentType:(AVAssetSegmentType)segmentType segmentReport:(nullable AVAssetSegmentReport *)segmentReport  API_AVAILABLE(ios(14.0)){
    if (segmentType == AVAssetSegmentTypeInitialization) {
        self.initialSegmentData = segmentData;
    } else {
        self.currentIndex += 1;
        NSMutableData *muData = [[NSMutableData alloc] init];
        if (self.initialSegmentData) {
            [muData  appendData:self.initialSegmentData];
        }
        [muData appendData:segmentData];
        
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSFileManager *manager = [NSFileManager defaultManager];
        path = [path stringByAppendingPathComponent:@"LocalRecordSegment"];
        BOOL isDirectory = YES;
        if (![manager fileExistsAtPath:path isDirectory:&isDirectory]) {
            NSError *error = nil;
            [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                NSLog(@"outputFilePath create error: %@", error.localizedDescription);
            }
        }
        NSString *fileName = [NSString stringWithFormat:@"/SegmentRecordVideo_%ld.m4s",(long)self.currentIndex];
        NSString *filePath = [path stringByAppendingString:fileName];
        if ([manager fileExistsAtPath:filePath]) {
            [manager removeItemAtPath:filePath error:nil];
        }
        if ([muData writeToFile:filePath atomically:YES]) {
            NSLog(@"writeToFile %@ success",fileName);
        }
    }
}


#pragma mark _videoWriterInput

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSample {
    if (!_isRecording) {
        return;
    }
    
    if (_audioWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting && CMSampleBufferDataIsReady(audioSample)) {
        if (audioSample != nil) {
            BOOL appended = [_audioWriterInput appendSampleBuffer:audioSample];
            NSLog(@"Write audio: %@",(appended ? @"yes" : @"no"));
        }
    } else {
      NSLog(@"MP4Writer:appendAudio not appended, status= %ld",(long)_writer.status);
    }
}

#pragma mark _videoWriterInput
- (void)appendVideoSampleBuffer:(CMSampleBufferRef)videoSample {
    if (!_isRecording) {
        return;
    }
    if (_videoWriterInput.readyForMoreMediaData && _writer.status == AVAssetWriterStatusWriting && CMSampleBufferDataIsReady(videoSample)) {
        if (videoSample != nil) {
            BOOL appended = [_videoWriterInput appendSampleBuffer:videoSample];
            NSLog(@"Write video: %@",(appended ? @"yes" : @"no"));
        }
    } else {
        NSLog(@"MP4Writer:appendVideo not appended, status= %ld",(long)_writer.status);
    }
}
@end
