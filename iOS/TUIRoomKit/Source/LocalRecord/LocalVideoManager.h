//
//  LocalVideoManager.h
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TRTCVideoFrame;
@interface LocalVideoManager : NSObject
+ (instancetype)sharedInstance;
- (void)addTRTCVideoFrame:(TRTCVideoFrame *)frame;
@end

NS_ASSUME_NONNULL_END
