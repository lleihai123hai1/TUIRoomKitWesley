//
//  KFVideoPacketExtraData.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KFVideoPacketExtraData : NSObject
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;
@property (nonatomic, strong) NSData *vps;
@end

NS_ASSUME_NONNULL_END
