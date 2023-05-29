//
//  KFAudioTools.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KFAudioTools : NSObject
+ (NSData *)adtsDataWithChannels:(NSInteger)channels sampleRate:(NSInteger)sampleRate rawDataLength:(NSInteger)rawDataLength;
@end

NS_ASSUME_NONNULL_END
