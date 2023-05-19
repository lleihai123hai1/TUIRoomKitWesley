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

@interface LocalRecordingWrapper()<TRTCVideoRenderDelegate,TRTCAudioFrameDelegate>

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

- (void)startRecording {
    if (!_isRecording) {
        _isRecording = YES;
        [self subscribeDelegateCallback];
    }
}

- (void)stopRecording {
    if (_isRecording) {
        _isRecording = NO;
        [self unsubscribeDelegateCallback];
    }
}

- (void)subscribeDelegateCallback {
    [[TRTCCloud sharedInstance] setLocalVideoRenderDelegate:self pixelFormat:TRTCVideoPixelFormat_Texture_2D bufferType:TRTCVideoBufferType_Texture];
    [[TRTCCloud sharedInstance] setAudioFrameDelegate:self];
}

- (void)unsubscribeDelegateCallback {
    [TRTCCloud sharedInstance].delegate = nil;
}

#pragma mark TRTCVideoRenderDelegate

- (void)onRenderVideoFrame:(TRTCVideoFrame *_Nonnull)frame userId:(NSString *__nullable)userId streamType:(TRTCVideoStreamType)streamType {
    [[LocalVideoManager sharedInstance] addTRTCVideoFrame:frame];
}

#pragma mark TRTCAudioFrameDelegate
- (void)onCapturedRawAudioFrame:(TRTCAudioFrame *)frame {
    [[LocalAudioManager sharedInstance] addTRTCAudioFrame:frame];
}

@end


