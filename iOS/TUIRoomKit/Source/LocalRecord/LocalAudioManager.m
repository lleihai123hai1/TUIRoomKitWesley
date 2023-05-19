//
//  LocalAudioManager.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordHeader.h"
#import "LocalAudioManager.h"
#import "LocalProcessAudioFrame.h"
#import "SafeNSMutableArray.h"

@interface LocalAudioManager()
@property (atomic,weak) LocalProcessAudioFrame* processAudioFrame;
@property (nonatomic,strong) SafeNSMutableArray* videoFrameCache;
@end

@implementation LocalAudioManager
+ (instancetype)sharedInstance {
    static LocalAudioManager *gSharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedHandler = [[LocalAudioManager alloc] init];
    });
    return gSharedHandler;
}

- (void)addTRTCAudioFrame:(TRTCAudioFrame *)frame {
    [self.videoFrameCache addObject:frame];
}

- (void)binding:(LocalProcessAudioFrame *)processAudioFrame {
    self.processAudioFrame = processAudioFrame;
}

- (void)unbind {
    self.processAudioFrame = nil;
}

#pragma mark set/get

- (SafeNSMutableArray *)videoFrameCache {
    if (!_videoFrameCache) {
        _videoFrameCache = [SafeNSMutableArray new];
    }
    return _videoFrameCache;
    
}

@end
