//
//  LocalProcessVideoFrame.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalProcessVideoFrame.h"


@interface LocalVideoFrame(){
}

@end

@implementation LocalVideoFrame
@end


@interface LocalProcessVideoFrame(){
}

@end

@implementation LocalProcessVideoFrame

- (void)processVideoFrame:(TRTCVideoFrame*)frame {
    if ([self.delegate respondsToSelector:@selector(onCallback:)]){
        [self.delegate onCallback:[self convertToLocalVideoFrame:frame]];
    }
}

- (LocalVideoFrame *)convertToLocalVideoFrame:(TRTCVideoFrame*)frame {
    LocalVideoFrame *videoFrame = [LocalVideoFrame new];
    videoFrame.videoFrame = frame;
    return videoFrame;
}

@end
