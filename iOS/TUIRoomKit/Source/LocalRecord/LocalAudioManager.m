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
@property (nonatomic,strong) SafeNSMutableArray* audioFrameCache;
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
    [self.audioFrameCache addObject:frame];
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
            TRTCAudioFrame *frame = [self.audioFrameCache objectAtIndex:0];
            if (frame) {
                [self.audioFrameCache removeObjectAtIndex:0];
                [self.processAudioFrame processAudioFrame:frame];
            }
        }
    });
}

- (void)stopProcessingFrame {
    self.isProcessingFrame = NO;
    [self.audioFrameCache removeAllObjects];
    NSLog(@"------------ stopProcessingFrame audio");
}

#pragma mark set/get

- (SafeNSMutableArray *)audioFrameCache {
    if (!_audioFrameCache) {
        _audioFrameCache = [SafeNSMutableArray new];
    }
    return _audioFrameCache;
}

@end
