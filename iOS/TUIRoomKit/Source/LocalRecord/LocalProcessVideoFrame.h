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
- (instancetype)init:(TRTCVideoFrame *)videoFrame;
@property(nonatomic, assign) CVPixelBufferRef pixelBuffer;
@property (nonatomic, readonly) TRTCVideoFrame *videoFrame;
@end

@protocol LocalProcessVideoFrameDelegate <NSObject>
- (void)onCallbackLocalVideoFrame:(LocalVideoFrame *)localVideoFrame;
@end

@interface LocalProcessVideoFrame : NSObject
@property (nonatomic,weak) id<LocalProcessVideoFrameDelegate> delegate;
- (void)processVideoFrame:(TRTCVideoFrame*)frame;
@end

NS_ASSUME_NONNULL_END
