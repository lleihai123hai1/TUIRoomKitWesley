//
//  LocalMp4StreamWriter.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>
#import "LocalProcessAudioFrame.h"
#import "LocalProcessVideoFrame.h"

NS_ASSUME_NONNULL_BEGIN
@interface LocalMp4StreamWriter : NSObject <LocalProcessAudioFrameDelegate,LocalProcessVideoFrameDelegate>
- (void)startRecording;
- (void)stopRecording;
@end

NS_ASSUME_NONNULL_END
