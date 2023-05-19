//
//  LocalProcessAudioFrame.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LocalProcessAudioFrameDelegate <NSObject>

@end

@interface LocalProcessAudioFrame : NSObject
@property (nonatomic,weak) id<LocalProcessAudioFrameDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
