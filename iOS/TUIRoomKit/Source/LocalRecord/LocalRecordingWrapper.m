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
}

- (void)subscribeDelegateCallback {
    [[TRTCCloud sharedInstance] setLocalVideoRenderDelegate:self pixelFormat:TRTCVideoPixelFormat_I420 bufferType:TRTCVideoBufferType_PixelBuffer];
    [[TRTCCloud sharedInstance] setAudioFrameDelegate:self];
    _videoFrame.delegate = _streamWriter;
    _audioFrame.delegate = _streamWriter;
    [[LocalVideoManager sharedInstance] binding:_videoFrame];
    [[LocalAudioManager sharedInstance] binding:_audioFrame];
}

- (void)unsubscribeDelegateCallback {
    [TRTCCloud sharedInstance].delegate = nil;
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
    [[LocalAudioManager sharedInstance] addTRTCAudioFrame:frame];
}

@end


