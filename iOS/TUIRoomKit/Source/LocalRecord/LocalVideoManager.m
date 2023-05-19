//
//  LocalVideoManager.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordHeader.h"
#import "LocalVideoManager.h"
#import "LocalProcessVideoFrame.h"
#import "SafeNSMutableArray.h"

@interface LocalVideoManager(){
}
@property (atomic,weak) LocalProcessVideoFrame* processVideoFrame;
@property (nonatomic,strong) SafeNSMutableArray* videoFrameCache;
@property (atomic, assign) BOOL isProcessingFrame;
@end

@implementation LocalVideoManager

+ (instancetype)sharedInstance {
    static LocalVideoManager *gSharedHandler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gSharedHandler = [[LocalVideoManager alloc] init];
    });
    return gSharedHandler;
}

- (instancetype)init {
    self = [super init];
    if (self) {
    }
    return self;
}


- (void)addTRTCVideoFrame:(TRTCVideoFrame *)frame {
    [self.videoFrameCache addObject:frame];
}

- (void)binding:(LocalProcessVideoFrame *)processVideoFrame {
    self.processVideoFrame = processVideoFrame;
    [self startProcessingFrame];
}

- (void)unbind {
    self.processVideoFrame = nil;
    [self stopProcessingFrame];
}

- (void)startProcessingFrame {
    NSLog(@"------------ startProcessingFrame video");
    self.isProcessingFrame = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (self.isProcessingFrame) {
            TRTCVideoFrame *frame = [self.videoFrameCache objectAtIndex:0];
            [self.videoFrameCache removeObjectAtIndex:0];
        }
    });
}

- (void)stopProcessingFrame {
    self.isProcessingFrame = NO;
    NSLog(@"------------ stopProcessingFrame video");
}

#pragma mark set/get

- (SafeNSMutableArray *)videoFrameCache {
    if (!_videoFrameCache) {
        _videoFrameCache = [SafeNSMutableArray new];
    }
    return _videoFrameCache;
    
}

@end
