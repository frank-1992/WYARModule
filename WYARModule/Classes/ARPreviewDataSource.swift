//
//  ARPreviewDataSource.swift
//  XYARMoudle
//
//  Created by 黄渊 on 2021/12/31.
//

import XYAPIRoute
import XYFileManager

class ARPreviewDataSource {

    enum ARDownloadError: Error {
        case urlNil
    }

    private lazy var targetFolder: String = {
        XYFileManager.cachesDir() + "/ar/"
    }()


    func downloadUsdzFile(with paramter: ARModuleServiceParameter, completion: @escaping (Result<(URL, AR3DModel), Error>) -> Void) {
        let api = ARModuleService.ar3d(with: paramter)
        api.data().responseDecodable(type: AR3DModel.self) { response in
            switch response.result {
            case .success(let model):
                self.excuteDownload(with: model) {
                    if let url = $0 {
                        completion(.success((url, model)))
                    } else {
                        completion(.failure(ARDownloadError.urlNil))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func excuteDownload(with model: AR3DModel, completion: @escaping (URL?) -> Void) {
        let localPath = localPath(with: model.modelUsdzUrl)

        if XYFileManager.isFile(atPath: localPath) {
            completion(URL(fileURLWithPath: localPath))
            return
        }

        let localUrl = URL(fileURLWithPath: localPath)

        let request = XYWorldSnakeSession.shared.download(model.modelUsdzUrl)
        request.downloadDestination { _, url in
            guard let url = url else {
                completion(nil)
                return
            }
            do {
                try XYFileManager.moveItem(atPath: url.path, toPath: localUrl.path, error: ())
                completion(localUrl)
            } catch let error as NSError {
                completion(nil)
                print(error)
            }
        }
    }

    private func localPath(with url: String) -> String {
        let fileName = url.md5 ?? url
        return targetFolder + fileName + ".usdz"
    }
}
