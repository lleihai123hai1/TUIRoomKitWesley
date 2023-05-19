//
//  LocalVideoManager.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalVideoManager.h"
#import "LocalRecordHeader.h"

@interface LocalVideoManager()

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

@end
