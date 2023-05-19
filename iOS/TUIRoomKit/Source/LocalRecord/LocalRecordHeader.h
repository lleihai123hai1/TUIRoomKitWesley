//
//  LocalRecordHeader.h
//  Pods
//
//  Created by WesleyLei on 2023/5/19.
//

#ifndef LocalRecordHeader_h
#define LocalRecordHeader_h

#if TXLiteAVSDK_TRTC
    #import <TXLiteAVSDK_TRTC/TRTCCloud.h>
#else
    #import <TXLiteAVSDK_Professional/TRTCCloud.h>
#endif

#define YGLOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define YGUNLOCK(lock) dispatch_semaphore_signal(lock);

#endif /* LocalRecordHeader_h */
