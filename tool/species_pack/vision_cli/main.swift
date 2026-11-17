// Runs the app's own vision pipeline (packages/submersion_vision) over a
// list of images, for the accuracy scorer (tool/species_pack/score.py).
//
//   species_vision --manifest M --detector D --classifier C --crop-fit F < paths
//
// The manifest's detector block may carry "detectorFormat" ("rfdetr", the
// default, or "yolo"), which the pipeline reads as the app would.
//
// Reads one image path per line on stdin and writes one JSON line per image
// on stdout. The pipeline compiles a model package once and deletes it, so
// pass copies, never a pack's own files.
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
  exit(2)
}

func option(_ name: String) -> String {
  let args = CommandLine.arguments
  guard let i = args.firstIndex(of: name), i + 1 < args.count else {
    fail("usage: species_vision --manifest M --detector D --classifier C --crop-fit padSquare|centreCrop")
  }
  return args[i + 1]
}

func emit(_ object: [String: Any]) {
  guard let data = try? JSONSerialization.data(withJSONObject: object) else { fail("could not encode a result") }
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}

let manifestURL = URL(fileURLWithPath: option("--manifest"))
guard let manifestData = try? Data(contentsOf: manifestURL),
      let manifest = (try? JSONSerialization.jsonObject(with: manifestData)) as? [String: Any],
      let detector = manifest["detector"] as? [String: Any],
      let classifier = manifest["classifier"] as? [String: Any] else {
  fail("could not read the manifest")
}

let settings: VisionModelSettings
do {
  settings = try VisionModelSettings([
    "detectorPath": option("--detector"),
    "classifierPath": option("--classifier"),
    "detectorInputSize": detector["inputSize"] as Any,
    "detectorMean": detector["mean"] as Any,
    "detectorStd": detector["std"] as Any,
    "scoreThreshold": detector["scoreThreshold"] as Any,
    "maxBoxes": detector["maxBoxes"] as Any,
    "cropPadding": detector["cropPadding"] as Any,
    "classifierInputSize": classifier["inputSize"] as Any,
    "classifierMean": classifier["mean"] as Any,
    "classifierStd": classifier["std"] as Any,
    "embeddingSize": classifier["embeddingSize"] as Any,
    "cropThumbnailSize": manifest["cropThumbnailSize"] as Any,
    "cropFit": option("--crop-fit"),
  ].merging(detector["detectorFormat"].map { ["detectorFormat": $0] } ?? [:]) { a, _ in a })
} catch let error as VisionError {
  fail(error.message)
} catch {
  fail("\(error)")
}

let pipeline = VisionPipeline()
do {
  try pipeline.load(settings)
} catch let error as VisionError {
  fail(error.message)
} catch {
  fail("could not load the models: \(error)")
}

while let line = readLine() {
  let path = line.trimmingCharacters(in: .whitespaces)
  if path.isEmpty { continue }
  // One pool per image, as each dispatch block in the app is: without it
  // every decoded image stays alive until the process exits.
  autoreleasepool {
  do {
    let result = try pipeline.analyze(["path": path])
    let detections = (result["detections"] as? [[String: Any]] ?? []).map { d -> [String: Any] in
      let bytes = (d["embedding"] as? FlutterStandardTypedData)?.data ?? Data()
      let floats = bytes.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
      return [
        "x": d["x"] as Any, "y": d["y"] as Any, "w": d["width"] as Any, "h": d["height"] as Any,
        "score": d["score"] as Any,
        "pixelWidth": d["pixelWidth"] as Any, "pixelHeight": d["pixelHeight"] as Any,
        "embedding": floats.map { Double($0) },
        "embedMs": d["embedMs"] as Any,
      ]
    }
    // JSON has no NaN or infinity; such an embedding is the model failing.
    let finite = detections.allSatisfy { d in
      (d["embedding"] as? [Double] ?? []).allSatisfy { $0.isFinite }
    }
    guard finite else {
      emit(["path": path, "error": "the classifier returned a value that is not a number"])
      return
    }
    emit([
      "path": path, "width": result["imageWidth"] as Any, "height": result["imageHeight"] as Any,
      "detections": detections, "detectMs": result["detectMs"] as Any,
    ])
  } catch let error as VisionError {
    emit(["path": path, "error": error.message])
  } catch {
    emit(["path": path, "error": "\(error)"])
  }
  }
}
