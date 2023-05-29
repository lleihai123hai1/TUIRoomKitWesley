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
@property (nonatomic, strong) KFVideoEncoderConfig *videoEncoderConfig;
@property (nonatomic, strong) KFVideoEncoder *videoEncoder;
@property (nonatomic, strong) NSFileHandle *fileHandle;
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

- (KFVideoEncoderConfig *)videoEncoderConfig {
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
            [weakSelf saveSampleBuffer:sampleBuffer];
        };
    }
    return _videoEncoder;
}

- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        NSString *fileName = @"test.h264";
        if (self.videoEncoderConfig.codecType == kCMVideoCodecType_HEVC) {
            fileName = @"test.h265";
        }
        NSString *videoPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
        [[NSFileManager defaultManager] createFileAtPath:videoPath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:videoPath];
    }

    return _fileHandle;
}

- (void)saveSampleBuffer:(CMSampleBufferRef)sampleBuffer {
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
        
        [self.fileHandle writeData:resultData];
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
    
    
    
    CGSize size =  self.videoEncoderConfig.size;
    NSInteger bitsPerSecond = self.videoEncoderConfig.bitrate;

    // 码率和帧率设置
    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                             AVVideoExpectedSourceFrameRateKey : @(self.videoEncoderConfig.fps),
                                             AVVideoMaxKeyFrameIntervalKey : @(10),
                                             AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
    //视频属性
    
    NSDictionary *videoSetting = @{ AVVideoCodecKey : AVVideoCodecTypeH264,
                                    AVVideoWidthKey : @(size.height),
                                    AVVideoHeightKey : @(size.width),
                                    AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                    AVVideoCompressionPropertiesKey : compressionProperties };
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:nil];
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
- (void)writeLocalVideoFrame:(LocalVideoFrame *)frame {
    [self startWriting];
    
    [self.videoEncoder encodePixelBuffer:frame.videoFrame.pixelBuffer ptsTime:kCMTimePositiveInfinity];
//    CMSampleBufferRef videoSample = [self sampleBufferFromVideoData:frame.videoFrame.pixelBuffer time:kCMTimeInvalid];
//    [self writeVideoSampleBuffer:videoSample];
//    CFRelease(videoSample);
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
