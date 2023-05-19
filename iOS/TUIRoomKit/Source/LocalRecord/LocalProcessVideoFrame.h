//
//  LocalProcessVideoFrame.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol LocalProcessVideoFrameDelegate <NSObject>

@end

@interface LocalProcessVideoFrame : NSObject
@property (nonatomic,weak) id<LocalProcessVideoFrameDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
