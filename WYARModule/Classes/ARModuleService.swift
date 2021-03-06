//
//  ARModuleService.swift
//  XYARMoudle
//
//  Created by 黄渊 on 2021/12/30.
//

import XYAPIRoute

public typealias ARModuleServiceParameter = (bizType: String, bizId: String)

public struct ARModuleService {

    public static func ar3d(with parameter: ARModuleServiceParameter) -> WSRURL {
        
        let path = "/api/sns/ar3d/biz-type/:biz_type/biz-id/:biz_id"

        let api = XYAPIRouter.shared.buildURL()
        api.path = path
        api.method = .WSHTTPMGET
        api.setPattern(path, keys: [parameter.bizType, parameter.bizId])

        return api
    }
}
