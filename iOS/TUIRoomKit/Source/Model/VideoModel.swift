//
//  VideoModel.swift
//  TUIRoomKit
//
//  Created by 唐佳宁 on 2023/3/8.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import TUIRoomEngine
#if TXLiteAVSDK_TRTC
import TXLiteAVSDK_TRTC
#elseif TXLiteAVSDK_Professional
import TXLiteAVSDK_Professional
#endif

class VideoModel {
    var videoFps: Int = 30
    var videoResolution: TRTCVideoResolution = ._1920_1080
    var videoBitrate: Int = 3000
    var isMirror: Bool = false
    var isFrontCamera: Bool = true
    var videoQuality: TUIVideoQuality = .quality1080P
    var bitrate: BitrateTableData = BitrateTableData(resolutionName: "1080 * 1920",
                                                     resolution: TRTCVideoResolution._1920_1080,
                                                     defaultBitrate: 3_000,
                                                     minBitrate: 2_000,
                                                     maxBitrate: 4_000,
                                                     stepBitrate: 50)
}
