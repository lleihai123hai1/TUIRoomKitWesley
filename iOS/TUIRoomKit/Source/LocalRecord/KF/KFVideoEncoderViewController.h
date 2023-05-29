//
//  KFVideoEncoderViewController.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/29.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KFVideoPacketExtraData : NSObject
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;
@property (nonatomic, strong) NSData *vps;
@end

@interface KFVideoEncoderViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
