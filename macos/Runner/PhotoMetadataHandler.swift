import FlutterMacOS
import ImageIO
import Photos

class PhotoMetadataHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.submersion.app/photo_metadata",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
        NSLog("[PhotoMetadataHandler] Handler initialized and registered")
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAssetMetadata":
            guard let args = call.arguments as? [String: Any],
                  let assetId = args["assetId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing assetId", details: nil))
                return
            }
            getAssetMetadata(assetId: assetId, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getAssetMetadata(assetId: String, result: @escaping FlutterResult) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "Photo library access not authorized",
                details: nil
            ))
            return
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else {
            result(nil)
            return
        }

        guard asset.mediaType == .image else {
            result([
                "durationSeconds": Int(asset.duration.rounded()),
                "mimeType": "video/quicktime"
            ])
            return
        }

        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true

        asset.requestContentEditingInput(with: options) { input, info in
            if let error = info[PHContentEditingInputErrorKey] as? Error {
                NSLog("[PhotoMetadataHandler] content input error for %@: %@", assetId, error.localizedDescription)
            }

            guard let inputURL = input?.fullSizeImageURL,
                  let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                DispatchQueue.main.async {
                    result(nil)
                }
                return
            }

            var output: [String: Any] = [:]
            let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
            let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
            let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]

            if let dateTimeOriginal = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                output["dateTimeOriginal"] = dateTimeOriginal
            } else if let dateTime = tiff?[kCGImagePropertyTIFFDateTime as String] as? String {
                output["dateTimeOriginal"] = dateTime
            }

            if let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
                output["width"] = width
            }
            if let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
                output["height"] = height
            }
            if let latitude = gps?[kCGImagePropertyGPSLatitude as String] as? Double {
                let ref = gps?[kCGImagePropertyGPSLatitudeRef as String] as? String
                output["latitude"] = ref == "S" ? -latitude : latitude
            }
            if let longitude = gps?[kCGImagePropertyGPSLongitude as String] as? Double {
                let ref = gps?[kCGImagePropertyGPSLongitudeRef as String] as? String
                output["longitude"] = ref == "W" ? -longitude : longitude
            }

            output["mimeType"] = self.mimeType(for: inputURL)

            DispatchQueue.main.async {
                result(output)
            }
        }
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "heic":
            return "image/heic"
        case "heif":
            return "image/heif"
        case "png":
            return "image/png"
        default:
            return "application/octet-stream"
        }
    }
}
