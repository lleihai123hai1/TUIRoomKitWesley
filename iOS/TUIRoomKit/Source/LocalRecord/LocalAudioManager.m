//
//  LocalAudioManager.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordHeader.h"
#import "LocalAudioManager.h"
#import "LocalProcessAudioFrame.h"

@interface LocalAudioManager()
@property (atomic,weak) LocalProcessAudioFrame* processAudioFrame;
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
    
}

- (void)binding:(LocalProcessAudioFrame *)processAudioFrame {
    self.processAudioFrame = processAudioFrame;
}

- (void)unbind {
    self.processAudioFrame = nil;
}


@end
