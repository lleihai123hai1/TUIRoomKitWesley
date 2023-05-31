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



//参考链接：https://zhuanlan.zhihu.com/p/515281023
//用工具播放 H.264/H.265 文件
//ffplay -i video_tmp.h264
//ffplay -i video_tmp.h265

//参考链接：https://zhuanlan.zhihu.com/p/514346313
//用工具播放 PCM 文件
//ffplay -ar 48000 -channels 1 -f s16le -i audio_tmp.pcm

//ffmpeg -i video_tmp.h265 -i audio_tmp.acc -vcodec copy -f mp4 test.mp4



@interface LocalMp4StreamWriter(){
    BOOL _isRecording;
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
    [[NSFileManager defaultManager] createFileAtPath:self.audioFilePath contents:nil attributes:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.audioPcmFilePath contents:nil attributes:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.videoFilePath contents:nil attributes:nil];
}

- (void)startRecording {
    if (_isRecording) {
        return;
    }
    [self clearTmpFile];
    [self clearData];
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
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
}

#pragma mark get/set

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
           if (data) {
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
        _audioEncoder = [[KFAudioEncoder alloc] initWithAudioBitrate:48000];
        _audioEncoder.errorCallBack = ^(NSError* error) {
            NSLog(@"KFAudioEncoder error:%zi %@", error.code, error.localizedDescription);
        };
        // 音频编码数据回调。在这里将 AAC 数据写入文件。
        _audioEncoder.sampleBufferOutputCallBack = ^(CMSampleBufferRef sampleBuffer) {
            if (sampleBuffer) {
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
        CMSampleBufferRef audioSample = [LocalRecordTools sampleBufferFromAudioData:localAudioFrame];
        [self.audioEncoder encodeSampleBuffer:audioSample];
        CFRelease(audioSample);
        [self.audioPcmFileHandle writeData:localAudioFrame.audioFrame.data];
    }
}

- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame {
    if (_isRecording) {
        [self.videoEncoder encodePixelBuffer:localVideoFrame.videoFrame.pixelBuffer ptsTime:kCMTimePositiveInfinity];
    }
}

@end
