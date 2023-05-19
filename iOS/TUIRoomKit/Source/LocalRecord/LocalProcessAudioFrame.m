//
//  LocalProcessAudioFrame.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalProcessAudioFrame.h"

@implementation LocalProcessAudioFrame
- (void)processAudioFrame:(TRTCAudioFrame*)frame {
    if ([self.delegate respondsToSelector:@selector(onCallback)]){
        [self.delegate onCallback];
    }
}
@end
