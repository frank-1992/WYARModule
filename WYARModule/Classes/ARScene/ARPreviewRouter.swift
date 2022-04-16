//
//  ARRouter.swift
//  I18N
//
//  Created by 黄渊 on 2022/1/5.
//

import XYRouter
import UIKit

public class ARPreviewRouteContext: RouteContext {
    let bizType: String

    let bizId: String

    init(_ dict: [String: Any]?) {
        bizType = dict?["biz_type"] as? String ?? ""

        bizId = dict?["biz_id"] as? String ?? ""
    }
}

public class ARPreviewRouter: XYRouter<UIViewController, RouteContext> {

    public override class func register() {
        register(URLPattern: "xhsdiscover://ar_quick_look")
    }

    public override func perform(to destination: UIViewController?, context: RouteContext) -> Bool {
        if #available(iOS 13, *) {
            showARVC(with: ARPreviewRouteContext(context.urlParams))
        } else {
            showLowVersionAlert()
        }
        return true
    }

    func showARVC(with context: ARPreviewRouteContext) {
        guard let vc = UIViewController.xy_topViewController else {
            return
        }
        let arSceneVC = ARSceneController()
        arSceneVC.parameter = (context.bizType, context.bizId)
        arSceneVC.present(with: vc)
    }

    func showLowVersionAlert() {
        let alert = UIAlertController(title: "提示", message: "您的手机系统版本过低，请升级到iOS 13.0或以上版本后体验该功能", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .cancel))
        UIViewController.xy_topViewController?.present(alert, animated: true, completion: nil)
    }
}
