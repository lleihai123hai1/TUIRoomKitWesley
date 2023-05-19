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
@property (atomic, assign) BOOL isProcessingFrame;
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
    [self startProcessingFrame];
}

- (void)unbind {
    self.processAudioFrame = nil;
    [self stopProcessingFrame];
}

- (void)startProcessingFrame {
    NSLog(@"------------ startProcessingFrame audio");
    self.isProcessingFrame = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.isProcessingFrame) {
            TRTCAudioFrame *frame = [self.videoFrameCache objectAtIndex:0];
            [self.videoFrameCache removeObjectAtIndex:0];
            [self.processAudioFrame processAudioFrame:frame];
        }
    });
}

- (void)stopProcessingFrame {
    self.isProcessingFrame = NO;
    NSLog(@"------------ stopProcessingFrame audio");
}

#pragma mark set/get

- (SafeNSMutableArray *)videoFrameCache {
    if (!_videoFrameCache) {
        _videoFrameCache = [SafeNSMutableArray new];
    }
    return _videoFrameCache;
    
}

@end
