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

@interface LocalRecordingWrapper()<TRTCVideoRenderDelegate,TRTCAudioFrameDelegate>
{
    LocalMp4StreamWriter *_streamWriter;
    LocalProcessVideoFrame *_videoFrame;
    LocalProcessAudioFrame *_audioFrame;
    
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
        [_streamWriter startRecording];
        [self subscribeDelegateCallback];
    }
}

- (void)stopRecording {
    if (_isRecording) {
        _isRecording = NO;
        [self unsubscribeDelegateCallback];
        [_streamWriter stopRecording];
    }
    [self.fileHandle closeFile];
}

- (void)subscribeDelegateCallback {
    [[TRTCCloud sharedInstance] setLocalVideoRenderDelegate:self pixelFormat:TRTCVideoPixelFormat_NV12 bufferType:TRTCVideoBufferType_PixelBuffer];
    [[TRTCCloud sharedInstance] setAudioFrameDelegate:self];
    TRTCAudioFrameDelegateFormat *format = [[TRTCAudioFrameDelegateFormat alloc]init];
    format.channels = 1;
    format.sampleRate = 48000;
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
    if (frame.timestamp <= 0) {
        frame.timestamp = [TRTCCloud generateCustomPTS];
    }
    [[LocalAudioManager sharedInstance] addTRTCAudioFrame:frame];
    if (self.isRecording) {
        [self.fileHandle writeData:frame.data];
    }
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


