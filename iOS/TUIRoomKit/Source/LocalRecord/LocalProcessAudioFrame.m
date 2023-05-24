//
//  LocalProcessAudioFrame.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalProcessAudioFrame.h"


@interface LocalAudioFrame(){
    TRTCAudioFrame *_audioFrame;
}

@end

@implementation LocalAudioFrame

- (instancetype)init:(TRTCAudioFrame *)audioFrame {
    if (self = [super init]) {
        _audioFrame = audioFrame;
    }
    return self;
}
- (TRTCAudioFrame *)audioFrame {
    return _audioFrame;
}

@end


@interface LocalProcessAudioFrame() {
}

@end

@implementation LocalProcessAudioFrame

- (void)processAudioFrame:(LocalAudioFrame*)frame {
    if ([self.delegate respondsToSelector:@selector(onCallbackLocalAudioFrame:)]){
        [self.delegate onCallbackLocalAudioFrame:frame];
    }
}

@end
