//
//  LocalProcessVideoFrame.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol LocalProcessVideoFrameDelegate <NSObject>
- (void)onCallback;
@end

@class TRTCVideoFrame;
@interface LocalProcessVideoFrame : NSObject
@property (nonatomic,weak) id<LocalProcessVideoFrameDelegate> delegate;
- (void)processVideoFrame:(TRTCVideoFrame*)frame;
@end

NS_ASSUME_NONNULL_END
