//
//  LocalProcessVideoFrame.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalProcessVideoFrame.h"
#import "LocalRecordHeader.h"

@interface LocalVideoFrame(){
    TRTCVideoFrame *_videoFrame;
}
@property(nonatomic, assign) CVPixelBufferRef pixelBuffer;
@end

@implementation LocalVideoFrame

- (instancetype)init:(TRTCVideoFrame *)videoFrame {
    if (self = [super init]) {
        _videoFrame = videoFrame;
        self.pixelBuffer = videoFrame.pixelBuffer;
    }
    return self;
}

- (TRTCVideoFrame *)videoFrame {
    return _videoFrame;
}

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (_pixelBuffer && pixelBuffer && CFEqual(pixelBuffer, _pixelBuffer)) {
        return;
    }
    if (pixelBuffer) {
        CVPixelBufferRetain(pixelBuffer);
    }
    if (_pixelBuffer) {
        CVPixelBufferRelease(_pixelBuffer);
    }
    _pixelBuffer = pixelBuffer;
}

- (void)dealloc {
    if (self.pixelBuffer) {
        CVPixelBufferRelease(self.pixelBuffer);
    }
}
@end


@interface LocalProcessVideoFrame(){
}

@end

@implementation LocalProcessVideoFrame

- (void)processVideoFrame:(LocalVideoFrame*)frame {
    if ([self.delegate respondsToSelector:@selector(onCallbackLocalVideoFrame:)]){
        [self.delegate onCallbackLocalVideoFrame:frame];
    }
}

@end
