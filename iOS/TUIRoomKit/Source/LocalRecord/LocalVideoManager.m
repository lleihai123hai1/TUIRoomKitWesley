//
//  LocalVideoManager.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordHeader.h"
#import "LocalVideoManager.h"
#import "LocalProcessVideoFrame.h"

@interface LocalVideoManager()
@property (atomic,weak) LocalProcessVideoFrame* processVideoFrame;
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

- (void)addTRTCVideoFrame:(TRTCVideoFrame *)frame {
    
}

- (void)binding:(LocalProcessVideoFrame *)processVideoFrame {
    self.processVideoFrame = processVideoFrame;
}

- (void)unbind {
    self.processVideoFrame = nil;
}

@end
