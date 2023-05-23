//
//  LocalProcessVideoFrame.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class TRTCVideoFrame;
@interface LocalVideoFrame : NSObject
@property (nonatomic, strong) TRTCVideoFrame *videoFrame;
// 视频帧的显示时间戳 presentation timestamp，单位：ms
@property (nonatomic, assign) uint64_t ptsMs;
@property (nonatomic, assign) uint64_t dtsMs;
@end

@protocol LocalProcessVideoFrameDelegate <NSObject>
- (void)onCallback:(LocalVideoFrame *)localVideoFrame;
@end

@interface LocalProcessVideoFrame : NSObject
@property (nonatomic,weak) id<LocalProcessVideoFrameDelegate> delegate;
- (void)processVideoFrame:(TRTCVideoFrame*)frame;
@end

NS_ASSUME_NONNULL_END
