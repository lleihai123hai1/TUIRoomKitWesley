//
//  LocalProcessAudioFrame.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TRTCAudioFrame;

@interface LocalAudioFrame : NSObject
@property (nonatomic, strong) TRTCAudioFrame *audioFrame;
@end

@protocol LocalProcessAudioFrameDelegate <NSObject>
- (void)onCallback:(LocalAudioFrame*)audioFrame;
@end

@interface LocalProcessAudioFrame : NSObject
@property (nonatomic,weak) id<LocalProcessAudioFrameDelegate> delegate;
- (void)processAudioFrame:(TRTCAudioFrame*)frame;
@end

NS_ASSUME_NONNULL_END
