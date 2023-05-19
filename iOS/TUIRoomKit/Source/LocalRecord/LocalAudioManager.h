//
//  LocalAudioManager.h
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TRTCAudioFrame,LocalProcessAudioFrame;
@interface LocalAudioManager : NSObject
+ (instancetype)sharedInstance;
- (void)addTRTCAudioFrame:(TRTCAudioFrame *)frame;
- (void)binding:(LocalProcessAudioFrame *)processAudioFrame;
- (void)unbind;
@end

NS_ASSUME_NONNULL_END
