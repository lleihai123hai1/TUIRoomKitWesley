//
//  LocalAudioManager.h
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TRTCAudioFrame;
@interface LocalAudioManager : NSObject
+ (instancetype)sharedInstance;
- (void)addTRTCAudioFrame:(TRTCAudioFrame *)frame;
@end

NS_ASSUME_NONNULL_END
