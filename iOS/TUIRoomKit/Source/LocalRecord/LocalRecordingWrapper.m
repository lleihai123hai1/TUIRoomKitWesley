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

@interface LocalRecordingWrapper()<TRTCLogDelegate>

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
    [TRTCCloud sharedInstance].delegate = self;
}

- (void)unsubscribeDelegateCallback {
    [TRTCCloud sharedInstance].delegate = nil;
}

#pragma mark TRTCLogDelegate

- (void)onRenderVideoFrame:(TRTCVideoFrame *_Nonnull)frame userId:(NSString *__nullable)userId streamType:(TRTCVideoStreamType)streamType {
    [[LocalVideoManager sharedInstance] addTRTCVideoFrame:frame];
}

- (void)onCapturedRawAudioFrame:(TRTCAudioFrame *)frame {
    [[LocalAudioManager sharedInstance] addTRTCAudioFrame:frame];
}

@end


