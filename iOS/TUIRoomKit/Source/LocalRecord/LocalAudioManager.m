//
//  LocalAudioManager.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalAudioManager.h"
#import "LocalRecordHeader.h"

@interface LocalAudioManager()

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
@end
