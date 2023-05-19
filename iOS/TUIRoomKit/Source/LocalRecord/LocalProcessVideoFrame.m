//
//  LocalProcessVideoFrame.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalProcessVideoFrame.h"

@implementation LocalProcessVideoFrame
- (void)processVideoFrame:(TRTCVideoFrame*)frame {
    if ([self.delegate respondsToSelector:@selector(onCallback)]){
        [self.delegate onCallback];
    }
}
@end
