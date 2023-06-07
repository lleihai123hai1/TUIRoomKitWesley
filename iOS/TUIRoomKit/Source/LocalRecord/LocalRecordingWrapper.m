//
//  LocalRecordingWrapper.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordingWrapper.h"
#import "LocalRecordHeader.h"
#import "LocalVideoManager.h"
#import "LocalAudioManager.h"
#import "LocalMp4StreamWriter.h"
#import "LocalProcessVideoFrame.h"
#import "LocalProcessAudioFrame.h"
#import "KFAudioConfig.h"

@interface LocalRecordingWrapper()<TRTCVideoRenderDelegate,TRTCAudioFrameDelegate>
{
    LocalMp4StreamWriter *_streamWriter;
    LocalProcessVideoFrame *_videoFrame;
    LocalProcessAudioFrame *_audioFrame;
    NSMutableData *_mData;
    
}
@property (nonatomic,strong)NSFileHandle *fileHandle;
@end

@implementation LocalRecordingWrapper
@synthesize isRecording = _isRecording;

+ (instancetype)sharedInstance {
    static LocalRecordingWrapper *gSharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedHandler = [[LocalRecordingWrapper alloc] init];
    });
    return gSharedHandler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _streamWriter = [LocalMp4StreamWriter new];
        _videoFrame = [LocalProcessVideoFrame new];
        _audioFrame = [LocalProcessAudioFrame new];
    }
    return self;
}

- (void)startRecording {
    if (!_isRecording) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.pcm"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
        _fileHandle = nil;
        _isRecording = YES;
        _mData = [NSMutableData dataWithLength:1920*2];
        [_streamWriter startRecording];
        [self subscribeDelegateCallback];
    }
}

- (void)stopRecording {
    if (_isRecording) {
        _isRecording = NO;
        _mData = nil;
        [self unsubscribeDelegateCallback];
        [_streamWriter stopRecording];
    }
    [self.fileHandle closeFile];
}

- (void)subscribeDelegateCallback {
    [[TRTCCloud sharedInstance] setLocalVideoRenderDelegate:self pixelFormat:TRTCVideoPixelFormat_NV12 bufferType:TRTCVideoBufferType_PixelBuffer];
    [[TRTCCloud sharedInstance] setAudioFrameDelegate:self];
    TRTCAudioFrameDelegateFormat *format = [[TRTCAudioFrameDelegateFormat alloc]init];
    format.channels = (int)[KFAudioConfig defaultConfig].channels;
    format.sampleRate = [KFAudioConfig defaultConfig].sampleRate;
    format.samplesPerCall = (int)(format.sampleRate/100);
    format.mode = TRTCAudioFrameOperationModeReadOnly;
    [[TRTCCloud sharedInstance] setLocalProcessedAudioFrameDelegateFormat:format];
    _videoFrame.delegate = _streamWriter;
    _audioFrame.delegate = _streamWriter;
    [[LocalVideoManager sharedInstance] binding:_videoFrame];
    [[LocalAudioManager sharedInstance] binding:_audioFrame];
}

- (void)unsubscribeDelegateCallback {
    [[TRTCCloud sharedInstance] setLocalVideoRenderDelegate:nil pixelFormat:TRTCVideoPixelFormat_I420 bufferType:TRTCVideoBufferType_PixelBuffer];
    [[TRTCCloud sharedInstance] setAudioFrameDelegate:nil];
    _videoFrame.delegate = nil;
    _audioFrame.delegate = nil;
    [[LocalVideoManager sharedInstance] unbind];
    [[LocalAudioManager sharedInstance] unbind];
}

#pragma mark TRTCVideoRenderDelegate

- (void)onRenderVideoFrame:(TRTCVideoFrame *_Nonnull)frame userId:(NSString *__nullable)userId streamType:(TRTCVideoStreamType)streamType {
    if (frame.timestamp <= 0) {
        frame.timestamp = [TRTCCloud generateCustomPTS];
    }
    [[LocalVideoManager sharedInstance] addTRTCVideoFrame:frame];
}

#pragma mark TRTCAudioFrameDelegate
- (void)onCapturedRawAudioFrame:(TRTCAudioFrame *)frame {
    if (self.isRecording) {
        [self.fileHandle writeData:frame.data];
    }
    
    if (!_mData) {
        return;
    } else {
        [_mData appendData:frame.data];
    }
   
    if (_mData.length > 2048) {
        if (frame.timestamp <= 0) {
            frame.timestamp = [TRTCCloud generateCustomPTS];
        }
        NSData *blockData = [_mData subdataWithRange:NSMakeRange(0, 2048)];
        frame.data = blockData;
        [[LocalAudioManager sharedInstance] addTRTCAudioFrame:frame];
        [_mData replaceBytesInRange:NSMakeRange(0, 2048) withBytes:NULL length:0];
    }
    
//实际
//48000 * 20/1000 = 960
//32/16 = 2
//2*960 = 1920
//ios 写入需要
//1920 bt
//1024*2 = 2048
}

- (NSFileHandle *)fileHandle {
    if (!_fileHandle) {
        NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"test.pcm"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
        [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
        _fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];

    }
    return _fileHandle;
}

@end


