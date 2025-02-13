//
//  PopUpViewModel.swift
//  TUIRoomKit
//
//  Created by 唐佳宁 on 2023/1/12.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import TUICore

enum PopUpViewType {
    case roomInfoViewType //房间详情页面
    case moreViewType //更多功能页面
    case setUpViewType //设置页面
    case userListViewType //用户列表页面
    case raiseHandApplicationListViewType //举手发言列表页面
    case transferMasterViewType //转换房主页面
    case QRCodeViewType // 二维码页面
    case chatViewType //聊天页面
    case navigationControllerType
}

protocol PopUpViewResponder: AnyObject {
    func searchControllerChangeActive(isActive: Bool)
    func updateViewOrientation(isLandscape: Bool)
}

class PopUpViewModel {
    let viewType: PopUpViewType
    let height: CGFloat?
    var backgroundColor: UIColor?
    weak var viewResponder: PopUpViewResponder?
    var engineManager: EngineManager {
        EngineManager.shared
    }
    
    init(viewType: PopUpViewType, height: CGFloat?) {
        self.viewType = viewType
        self.height = height
    }
    
    func panelControlAction() {
        viewResponder?.searchControllerChangeActive(isActive: false)
        RoomRouter.shared.dismissPopupViewController(viewType: viewType)
    }
    
    func updateOrientation(isLandscape: Bool) {
        viewResponder?.updateViewOrientation(isLandscape: isLandscape)
    }
    
    deinit {
        debugPrint("deinit \(self)")
    }
}
