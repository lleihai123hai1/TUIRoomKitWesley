//
//  LocalRecordingWrapper.h
//  Alamofire
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LocalRecordingWrapper : NSObject
@property (nonatomic,assign,readonly) BOOL isRecording;
+ (instancetype)sharedInstance;
- (void)startRecording;
- (void)stopRecording;
@end

NS_ASSUME_NONNULL_END
