//
//  ViewController.swift
//  PhotoPickerSample
//
//  Created by 竹ノ内愛斗 on 2023/02/24.
//

import UIKit
import PhotosUI

final class ViewController: UIViewController {

    @IBOutlet private weak var photoPickerButton: UIButton!

    private let manager = PHImageManager.default()

    override func viewDidLoad() {
        super.viewDidLoad()

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            print("status", status)
        }
    }

    @IBAction func didTapPhotoPickerButton(_ sender: Any) {

        let photoLibrary = PHPhotoLibrary.shared()
        var configuration = PHPickerConfiguration(photoLibrary: photoLibrary)
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        present(picker, animated: true)
    }
}

extension ViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        let assetIds = results.compactMap(\.assetIdentifier)
        let result = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: .none)
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true

        guard let firstObject = result.firstObject else { return }

        firstObject.requestContentEditingInput(with: options) { input, _ in
            guard let inputUrl = input?.fullSizeImageURL, // 選択されたImageのURL
                  let cgImageSource = CGImageSourceCreateWithURL(inputUrl as CFURL, nil), // CGImageSourceを作成
                  let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil), // 書き込み用のCGImageを作成
                  var metadata = CGImageSourceCopyPropertiesAtIndex(cgImageSource, 0, nil) as? [String: Any], // metadataを取得
                  var locationDic = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] else { return } // Locationのmetadataを取り出す

            // 適当なロケーションに上書き
            locationDic[kCGImagePropertyGPSLatitude as String] = "35.70220"
            locationDic[kCGImagePropertyGPSLongitude as String] = "139.81530"

            // 再度metadataに上書きする
            metadata[kCGImagePropertyGPSDictionary as String] = locationDic

            // 適当なURLを指定
            let tmpName = UUID().uuidString
            let tmpUrl = NSURL.fileURL(withPath: NSTemporaryDirectory() + tmpName + ".jpeg")
            if let destination = CGImageDestinationCreateWithURL(tmpUrl as CFURL, UTType.jpeg.identifier as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
                CGImageDestinationFinalize(destination)

                PHPhotoLibrary.shared().performChanges({
                    // アルバムに書き込み
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tmpUrl)
                }, completionHandler: { success, error in
                    print("performChanges success: \(success), error: \(error?.localizedDescription)")
                })
            }
        }
    }
}
