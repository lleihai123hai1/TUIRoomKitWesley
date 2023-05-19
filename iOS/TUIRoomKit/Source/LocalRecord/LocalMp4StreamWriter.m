//
//  LocalMp4StreamWriter.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalMp4StreamWriter.h"
#include <AVFoundation/AVFoundation.h>
#import "LocalRecordHeader.h"

static int kVideoTimeScale = 1000;

@interface LocalMp4StreamWriter()
{
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInput *_audioWriterInput;
    
    CMVideoFormatDescriptionRef _videoFormatDescription;
    CMAudioFormatDescriptionRef _audioFormatDescription;
    
    BOOL _haveWrittenFirstAudioFrame;
    size_t _totalWrittenBytes;
    CMTime _lastFramePTS;
    
    BOOL _isAudioFinished;
    BOOL _isVideoFinished;
    int64_t _lastVideoDurationMs;
    
    NSOperationQueue *_operationQueue;
    
    BOOL _isRecording;
}
@property (nonatomic, strong) NSString *outputFilePath;
@end

@implementation LocalMp4StreamWriter
- (instancetype)init {
    self = [super init];
    if (self) {
        [self resetData];
    }
    return self;
}

- (void)dealloc {
    if (_audioFormatDescription) {
        CFRelease(_audioFormatDescription);
    }
    if (_videoFormatDescription) {
        CFRelease(_videoFormatDescription);
    }
    NSLog(@"LocalMp4StreamWriter dealloc");
}

- (void)resetData{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputFilePath]) {
      [[NSFileManager defaultManager] removeItemAtPath:self.outputFilePath error:nil];
    }
    _haveWrittenFirstAudioFrame = NO;
    _totalWrittenBytes = 0;
    _lastFramePTS = CMTimeMake(0, kVideoTimeScale);
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = 1;
    _isAudioFinished = NO;
    _isVideoFinished = NO;
    _lastVideoDurationMs = 0;
}

- (void)startRecording {
    [self resetData];
    _isRecording = YES;
}

- (void)stopRecording {
    _isRecording = NO;
}

- (NSString *)outputFilePath {
    if (!_outputFilePath) {
        NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSFileManager *manager = [NSFileManager defaultManager];
        path = [path stringByAppendingPathComponent:@"LocalRecord"];
        BOOL isDirectory = YES;
        if (![manager fileExistsAtPath:path isDirectory:&isDirectory]) {
            NSError *error = nil;
            [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                NSLog(@"outputFilePath create error: %@", error.localizedDescription);
            }
        }
        _outputFilePath = [path stringByAppendingString:@"/tmp.mp4"];
    }
    return _outputFilePath;
}
@end
