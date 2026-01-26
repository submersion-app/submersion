import Flutter
import Photos
import AVFoundation
import CoreLocation
import ImageIO
import MobileCoreServices

/// Handles writing dive metadata to photos and videos via platform channel.
///
/// Supports:
/// - JPEG/HEIC/HEIF photos via CGImageDestination
/// - MOV/MP4 videos via AVFoundation
class MetadataWriteHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.submersion.app/metadata",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "writeMetadata":
            guard let args = call.arguments as? [String: Any],
                  let assetId = args["assetId"] as? String,
                  let metadata = args["metadata"] as? [String: Any],
                  let description = args["description"] as? String,
                  let isVideo = args["isVideo"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }

            let keepOriginal = args["keepOriginal"] as? Bool ?? false

            writeMetadata(
                assetId: assetId,
                metadata: metadata,
                description: description,
                isVideo: isVideo,
                keepOriginal: keepOriginal,
                result: result
            )

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func writeMetadata(
        assetId: String,
        metadata: [String: Any],
        description: String,
        isVideo: Bool,
        keepOriginal: Bool,
        result: @escaping FlutterResult
    ) {
        // Check photo library authorization
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "Photo library access not authorized",
                details: nil
            ))
            return
        }

        // Find the asset
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = fetchResult.firstObject else {
            result(FlutterError(
                code: "ASSET_NOT_FOUND",
                message: "Asset not found with ID: \(assetId)",
                details: nil
            ))
            return
        }

        // Check if asset is editable
        guard asset.canPerform(.properties) else {
            result(FlutterError(
                code: "READ_ONLY",
                message: "Asset cannot be modified (may be in iCloud or shared album)",
                details: nil
            ))
            return
        }

        if isVideo {
            writeVideoMetadata(asset: asset, metadata: metadata, description: description, keepOriginal: keepOriginal, result: result)
        } else {
            writePhotoMetadata(asset: asset, metadata: metadata, description: description, result: result)
        }
    }

    // MARK: - Photo Metadata

    private func writePhotoMetadata(
        asset: PHAsset,
        metadata: [String: Any],
        description: String,
        result: @escaping FlutterResult
    ) {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true

        asset.requestContentEditingInput(with: options) { [weak self] input, info in
            guard let self = self, let input = input else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Could not get content editing input",
                        details: nil
                    ))
                }
                return
            }

            guard let inputURL = input.fullSizeImageURL else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Could not get image URL",
                        details: nil
                    ))
                }
                return
            }

            // Read existing image data
            guard let imageSource = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Could not read image source",
                        details: nil
                    ))
                }
                return
            }

            // Get existing metadata
            var existingMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] ?? [:]

            // Build GPS metadata
            var gpsDict = existingMetadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]

            if let depth = metadata["depthMeters"] as? Double {
                gpsDict[kCGImagePropertyGPSAltitude as String] = abs(depth)
                gpsDict[kCGImagePropertyGPSAltitudeRef as String] = 1 // Below sea level
            }

            if let lat = metadata["latitude"] as? Double,
               let lon = metadata["longitude"] as? Double {
                gpsDict[kCGImagePropertyGPSLatitude as String] = abs(lat)
                gpsDict[kCGImagePropertyGPSLatitudeRef as String] = lat >= 0 ? "N" : "S"
                gpsDict[kCGImagePropertyGPSLongitude as String] = abs(lon)
                gpsDict[kCGImagePropertyGPSLongitudeRef as String] = lon >= 0 ? "E" : "W"
            }

            existingMetadata[kCGImagePropertyGPSDictionary as String] = gpsDict

            // Build TIFF metadata for description
            var tiffDict = existingMetadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiffDict[kCGImagePropertyTIFFImageDescription as String] = description
            existingMetadata[kCGImagePropertyTIFFDictionary as String] = tiffDict

            // Build EXIF metadata
            var exifDict = existingMetadata[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            exifDict[kCGImagePropertyExifUserComment as String] = description
            existingMetadata[kCGImagePropertyExifDictionary as String] = exifDict

            // Create output
            let output = PHContentEditingOutput(contentEditingInput: input)
            let outputURL = output.renderedContentURL

            // Determine UTI based on original file
            let uti = self.getImageUTI(for: inputURL)

            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                uti,
                1,
                nil
            ) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Could not create image destination",
                        details: nil
                    ))
                }
                return
            }

            // Copy the image with updated metadata
            CGImageDestinationAddImageFromSource(destination, imageSource, 0, existingMetadata as CFDictionary)

            guard CGImageDestinationFinalize(destination) else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Could not finalize image with metadata",
                        details: nil
                    ))
                }
                return
            }

            // Set adjustment data (required for Photos to accept the edit)
            let adjustmentData = PHAdjustmentData(
                formatIdentifier: "com.submersion.app.metadata",
                formatVersion: "1.0",
                data: description.data(using: .utf8) ?? Data()
            )
            output.adjustmentData = adjustmentData

            // Commit the changes
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest(for: asset)
                request.contentEditingOutput = output
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(
                            code: "WRITE_FAILED",
                            message: error?.localizedDescription ?? "Failed to save changes",
                            details: nil
                        ))
                    }
                }
            }
        }
    }

    private func getImageUTI(for url: URL) -> CFString {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "heic", "heif":
            return AVFileType.heic as CFString
        case "png":
            return kUTTypePNG
        case "jpg", "jpeg":
            return kUTTypeJPEG
        default:
            return kUTTypeJPEG
        }
    }

    // MARK: - Video Metadata

    private func writeVideoMetadata(
        asset: PHAsset,
        metadata: [String: Any],
        description: String,
        keepOriginal: Bool,
        result: @escaping FlutterResult
    ) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current

        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, audioMix, info in
            guard let self = self, let urlAsset = avAsset as? AVURLAsset else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Could not get video asset",
                        details: nil
                    ))
                }
                return
            }

            self.writeVideoMetadataToAsset(
                asset: asset,
                videoURL: urlAsset.url,
                metadata: metadata,
                description: description,
                keepOriginal: keepOriginal,
                result: result
            )
        }
    }

    private func writeVideoMetadataToAsset(
        asset: PHAsset,
        videoURL: URL,
        metadata: [String: Any],
        description: String,
        keepOriginal: Bool,
        result: @escaping FlutterResult
    ) {
        // Create AVAsset for reading
        let avAsset = AVAsset(url: videoURL)

        // Create export session
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetPassthrough) else {
            DispatchQueue.main.async {
                result(FlutterError(
                    code: "WRITE_FAILED",
                    message: "Could not create export session",
                    details: nil
                ))
            }
            return
        }

        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".mov")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        // Create metadata items
        var metadataItems: [AVMutableMetadataItem] = []

        // Add description
        let descItem = AVMutableMetadataItem()
        descItem.key = AVMetadataKey.commonKeyDescription as NSString
        descItem.keySpace = .common
        descItem.value = description as NSString
        metadataItems.append(descItem)

        // Add location if available
        if let lat = metadata["latitude"] as? Double,
           let lon = metadata["longitude"] as? Double {
            let locationItem = AVMutableMetadataItem()
            locationItem.key = AVMetadataKey.commonKeyLocation as NSString
            locationItem.keySpace = .common
            locationItem.value = "\(lat >= 0 ? "+" : "")\(lat)\(lon >= 0 ? "+" : "")\(lon)/" as NSString
            metadataItems.append(locationItem)
        }

        // Add title with site name
        if let siteName = metadata["siteName"] as? String {
            let titleItem = AVMutableMetadataItem()
            titleItem.key = AVMetadataKey.commonKeyTitle as NSString
            titleItem.keySpace = .common
            titleItem.value = siteName as NSString
            metadataItems.append(titleItem)
        }

        exportSession.metadata = metadataItems

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                // Import the modified video back to Photos
                PHPhotoLibrary.shared().performChanges({
                    let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                    creationRequest?.creationDate = asset.creationDate
                    creationRequest?.location = asset.location
                }) { success, error in
                    // Clean up temp file
                    try? FileManager.default.removeItem(at: outputURL)

                    if success {
                        // Delete original if user chose not to keep it
                        if !keepOriginal {
                            PHPhotoLibrary.shared().performChanges({
                                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                            }) { _, deleteError in
                                // Log but don't fail the operation if delete fails
                                if let deleteError = deleteError {
                                    print("Warning: Could not delete original video: \(deleteError.localizedDescription)")
                                }
                                DispatchQueue.main.async {
                                    result(true)
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                result(true)
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            result(FlutterError(
                                code: "WRITE_FAILED",
                                message: error?.localizedDescription ?? "Failed to save video",
                                details: nil
                            ))
                        }
                    }
                }

            case .failed:
                try? FileManager.default.removeItem(at: outputURL)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: exportSession.error?.localizedDescription ?? "Export failed",
                        details: nil
                    ))
                }

            case .cancelled:
                try? FileManager.default.removeItem(at: outputURL)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Export was cancelled",
                        details: nil
                    ))
                }

            default:
                break
            }
        }
    }
}
