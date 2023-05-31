//
//  LocalRecordTools.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/31.
//

#import <Foundation/Foundation.h>
#include <AVFoundation/AVFoundation.h>
#include <CoreMedia/CoreMedia.h>
#import "KFVideoPacketExtraData.h"

NS_ASSUME_NONNULL_BEGIN

@class LocalAudioFrame;
@interface LocalRecordTools : NSObject

+ (CMSampleBufferRef)sampleBufferFromAudioData:(LocalAudioFrame *)frame;
    
+ (NSMutableData *)changeSampleBufferToData:(CMSampleBufferRef)sampleBuffer;
@end

NS_ASSUME_NONNULL_END
