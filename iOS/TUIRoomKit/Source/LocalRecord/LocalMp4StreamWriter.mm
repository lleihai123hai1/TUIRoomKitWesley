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
#import "KFVideoEncoderViewController.h"
#import "KFAudioEncoder.h"
#import "KFAudioTools.h"

static int kVideoTimeScale = 1000;
static size_t kAACSamplesPerChannelPerFrame = 1024;

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
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputFilePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.outputFilePath error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:self.audioFilePath contents:nil attributes:nil];
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
           [weakSelf saveVideoSampleBuffer:sampleBuffer];
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

#pragma mark LocalProcessAudioFrameDelegate & LocalProcessVideoFrameDelegate
- (void)onCallbackLocalAudioFrame:(LocalAudioFrame*)localAudioFrame {
    if (_isRecording) {
        CMSampleBufferRef audioSample = [self sampleBufferFromAudioData:localAudioFrame];
        [self.audioEncoder encodeSampleBuffer:audioSample];
        CFRelease(audioSample);
//        [self.audioFileHandle writeData:localAudioFrame.audioFrame.data];
    }
}

- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame {
    if (_isRecording) {
        [self.videoEncoder encodePixelBuffer:localVideoFrame.videoFrame.pixelBuffer ptsTime:kCMTimePositiveInfinity];
    }
}


#pragma mark audio

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
    timingInfo.decodeTimeStamp = timingInfo.decodeTimeStamp;
    timingInfo.duration = CMTimeMake(kAACSamplesPerChannelPerFrame, (int32_t)frame.audioFrame.sampleRate);

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
//
//
//// NSData转换为CMSampleBufferRef
//- (CMSampleBufferRef)sampleBufferFromAudioData:(NSData *)audioData sampleRate:(Float64)sampleRate {
//
//    AudioStreamBasicDescription audioFormat;
//    audioFormat.mSampleRate = sampleRate;
//    audioFormat.mFormatID = kAudioFormatLinearPCM;
//    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//    audioFormat.mFramesPerPacket = 1;
//    audioFormat.mChannelsPerFrame = 1;
//    audioFormat.mBytesPerFrame = 2;
//    audioFormat.mBytesPerPacket = 2;
//    audioFormat.mBitsPerChannel = 16;
//    audioFormat.mReserved = 0;
//
//    CMFormatDescriptionRef formatDesc = NULL;
//    OSStatus status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault,
//                                                      &audioFormat,
//                                                      0,
//                                                      NULL,
//                                                      0,
//                                                      NULL,
//                                                      NULL,
//                                                      &formatDesc);
//    if (status != noErr) {
//        NSLog(@"Failed to create audio format description");
//        return nil;
//    }
//
//    CMSampleBufferRef sampleBuffer = NULL;
//    CMBlockBufferRef blockBuffer = NULL;
//    AudioBufferList audioBufferList;
//
//    audioBufferList.mNumberBuffers = 1;
//    audioBufferList.mBuffers[0].mNumberChannels = 1;
//    audioBufferList.mBuffers[0].mDataByteSize = (UInt32)[audioData length];
//    audioBufferList.mBuffers[0].mData = (void *)[audioData bytes];
//
//    status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
//                                                (void *)audioBufferList.mBuffers[0].mData,
//                                                audioBufferList.mBuffers[0].mDataByteSize,
//                                                kCFAllocatorNull,
//                                                NULL,
//                                                0,
//                                                audioBufferList.mBuffers[0].mDataByteSize,
//                                                0,
//                                                &blockBuffer);
//    if (status != noErr) {
//        NSLog(@"Failed to create block buffer");
//        return nil;
//    }
//
//    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
//    status = CMSampleBufferCreate(kCFAllocatorDefault,
//                                  blockBuffer,
//                                  true,
//                                  NULL,
//                                  NULL,
//                                  formatDesc,
//                                  (CMItemCount)1,
//                                  (CMItemCount)0,
//                                  &timing,
//                                  1,
//                                  &audioBufferList,
//                                  &sampleBuffer);
//    if (status != noErr) {
//        NSLog(@"Failed to create sample buffer");
//        return nil;
//    }
//
//    CFRelease(blockBuffer);
//    CFRelease(formatDesc);
//    return sampleBuffer;
//}

#pragma mark video

- (void)saveVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // 将编码数据存储为文件。
    // iOS 的 VideoToolbox 编码和解码只支持 AVCC/HVCC 的码流格式。但是 Android 的 MediaCodec 只支持 AnnexB 的码流格式。这里我们做一下两种格式的转换示范，将 AVCC/HVCC 格式的码流转换为 AnnexB 再存储。
    // 1、AVCC/HVCC 码流格式：[extradata]|[length][NALU]|[length][NALU]|...
    // VPS、SPS、PPS 不用 NALU 来存储，而是存储在 extradata 中；每个 NALU 前有个 length 字段表示这个 NALU 的长度（不包含 length 字段），length 字段通常是 4 字节。
    // 2、AnnexB 码流格式：[startcode][NALU]|[startcode][NALU]|...
    // 每个 NAL 前要添加起始码：0x00000001；VPS、SPS、PPS 也都用这样的 NALU 来存储，一般在码流最前面。
    if (sampleBuffer) {
        NSMutableData *resultData = [NSMutableData new];
        uint8_t nalPartition[] = {0x00, 0x00, 0x00, 0x01};
        
        // 关键帧前添加 vps（H.265)、sps、pps。这里要注意顺序别乱了。
        if ([self isKeyFrame:sampleBuffer]) {
            KFVideoPacketExtraData *extraData = [self getPacketExtraData:sampleBuffer];
            if (extraData.vps) {
                [resultData appendBytes:nalPartition length:4];
                [resultData appendData:extraData.vps];
            }
            [resultData appendBytes:nalPartition length:4];
            [resultData appendData:extraData.sps];
            [resultData appendBytes:nalPartition length:4];
            [resultData appendData:extraData.pps];
        }
        
        // 获取编码数据。这里的数据是 AVCC/HVCC 格式的。
        CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        size_t length, totalLength;
        char *dataPointer;
        OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
        if (statusCodeRet == noErr) {
            size_t bufferOffset = 0;
            static const int NALULengthHeaderLength = 4;
            // 拷贝编码数据。
            while (bufferOffset < totalLength - NALULengthHeaderLength) {
                // 通过 length 字段获取当前这个 NALU 的长度。
                uint32_t NALUnitLength = 0;
                memcpy(&NALUnitLength, dataPointer + bufferOffset, NALULengthHeaderLength);
                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
                
                // 拷贝 AnnexB 起始码字节。
                [resultData appendData:[NSData dataWithBytes:nalPartition length:4]];
                // 拷贝这个 NALU 的字节。
                [resultData appendData:[NSData dataWithBytes:(dataPointer + bufferOffset + NALULengthHeaderLength) length:NALUnitLength]];
                
                // 步进。
                bufferOffset += NALULengthHeaderLength + NALUnitLength;
            }
        }
        [self.videoFileHandle writeData:resultData];
    }
}

- (KFVideoPacketExtraData *)getPacketExtraData:(CMSampleBufferRef)sampleBuffer {
    // 从 CMSampleBuffer 中获取 extra data。
    if (!sampleBuffer) {
        return nil;
    }
    
    // 获取编码类型。
    CMVideoCodecType codecType = CMVideoFormatDescriptionGetCodecType(CMSampleBufferGetFormatDescription(sampleBuffer));
    
    KFVideoPacketExtraData *extraData = nil;
    if (codecType == kCMVideoCodecType_H264) {
        // 获取 H.264 的 extra data：sps、pps。
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                extraData = [[KFVideoPacketExtraData alloc] init];
                extraData.sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                extraData.pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
            }
        }
    } else if (codecType == kCMVideoCodecType_HEVC) {
        // 获取 H.265 的 extra data：vps、sps、pps。
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t vparameterSetSize, vparameterSetCount;
        const uint8_t *vparameterSet;
        if (@available(iOS 11.0, *)) {
            OSStatus statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 0, &vparameterSet, &vparameterSetSize, &vparameterSetCount, 0);
            if (statusCode == noErr) {
                size_t sparameterSetSize, sparameterSetCount;
                const uint8_t *sparameterSet;
                OSStatus statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 1, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
                if (statusCode == noErr) {
                    size_t pparameterSetSize, pparameterSetCount;
                    const uint8_t *pparameterSet;
                    OSStatus statusCode = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 2, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
                    if (statusCode == noErr) {
                        extraData = [[KFVideoPacketExtraData alloc] init];
                        extraData.vps = [NSData dataWithBytes:vparameterSet length:vparameterSetSize];
                        extraData.sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                        extraData.pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                    }
                }
            }
        } else {
            // 其他编码格式。
        }
    }
    
    return extraData;
}

- (BOOL)isKeyFrame:(CMSampleBufferRef)sampleBuffer {
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) {
        return NO;
    }
    
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) {
        return NO;
    }
    
    // 检测 sampleBuffer 是否是关键帧。
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    
    return keyframe;
}


@end
