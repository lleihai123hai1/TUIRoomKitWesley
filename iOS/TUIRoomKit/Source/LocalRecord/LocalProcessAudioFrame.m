//
//  LocalProcessAudioFrame.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalProcessAudioFrame.h"


@interface LocalAudioFrame(){
}

@end

@implementation LocalAudioFrame
@end


@interface LocalProcessAudioFrame() {
}

@end

@implementation LocalProcessAudioFrame

- (void)processAudioFrame:(TRTCAudioFrame*)frame {
    if ([self.delegate respondsToSelector:@selector(onCallbackLocalAudioFrame:)]){
        [self.delegate onCallbackLocalAudioFrame:[self convertToLocalAudioFrame:frame]];
    }
}

- (LocalAudioFrame *)convertToLocalAudioFrame:(TRTCAudioFrame*)frame {
    LocalAudioFrame *audioFrame = [LocalAudioFrame new];
    audioFrame.audioFrame = frame;
    return audioFrame;
}
@end
