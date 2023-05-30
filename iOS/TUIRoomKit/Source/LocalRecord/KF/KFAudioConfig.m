//
//  KFAudioConfig.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/29.
//

#import "KFAudioConfig.h"

@implementation KFAudioConfig
+ (instancetype)defaultConfig {
    KFAudioConfig *config = [[self alloc] init];
    config.channels = 1;
    config.sampleRate = 48000;
    config.bitDepth = 16;
    return config;
}

@end
