//
//  LocalRecordingWrapper.m
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordingWrapper.h"

@interface LocalRecordingWrapper()

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
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
}

@end


