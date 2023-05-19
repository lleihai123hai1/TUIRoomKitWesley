//
//  LocalProcessAudioFrame.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LocalProcessAudioFrameDelegate <NSObject>
- (void)onCallback;
@end

@class TRTCAudioFrame;
@interface LocalProcessAudioFrame : NSObject
@property (nonatomic,weak) id<LocalProcessAudioFrameDelegate> delegate;
- (void)processAudioFrame:(TRTCAudioFrame*)frame;
@end

NS_ASSUME_NONNULL_END
