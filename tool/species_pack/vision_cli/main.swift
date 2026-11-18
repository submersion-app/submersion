// Runs the app's own vision pipeline (packages/submersion_vision) over a
// list of images, for the accuracy scorer (tool/species_pack/score.py).
//
//   species_vision --manifest M --detector D [--detector D2] --classifier C
//                  --crop-fit F [--detector-boxes] < paths
//
// The manifest is a pack's: format 2 lists one or two detectors, each with
// its format; format 1 has one detector block, the fish detector, read as
// the app reads it. Pass one --detector per detector, in the manifest's
// order. --detector-boxes
// adds each detector's own boxes and the merged boxes, before cropping, to
// every result.
//
// Reads one image path per line on stdin and writes one JSON line per image
// on stdout. The pipeline compiles a model package once and deletes it, so
// pass copies, never a pack's own files.
import Foundation

let usage = "usage: species_vision --manifest M --detector D [--detector D2] --classifier C " +
  "--crop-fit padSquare|centreCrop [--detector-boxes]"

func fail(_ message: String) -> Never {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
  exit(2)
}

/// Every value given for [name], in order.
func values(_ name: String) -> [String] {
  let args = CommandLine.arguments
  var found: [String] = []
  for (i, arg) in args.enumerated() where arg == name {
    guard i + 1 < args.count else { fail(usage) }
    found.append(args[i + 1])
  }
  return found
}

func option(_ name: String) -> String {
  guard let value = values(name).first else { fail(usage) }
  return value
}

func emit(_ object: [String: Any]) {
  guard let data = try? JSONSerialization.data(withJSONObject: object) else { fail("could not encode a result") }
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}

let manifestURL = URL(fileURLWithPath: option("--manifest"))
guard let manifestData = try? Data(contentsOf: manifestURL),
      let manifest = (try? JSONSerialization.jsonObject(with: manifestData)) as? [String: Any],
      let classifier = manifest["classifier"] as? [String: Any] else {
  fail("could not read the manifest")
}

// The detectors and the shared box settings, from either format.
let detectorBlocks: [[String: Any]]
let boxes: [String: Any]
if let list = manifest["detectors"] as? [[String: Any]] {
  guard let shared = manifest["boxes"] as? [String: Any] else { fail("the manifest has detectors but no boxes block") }
  detectorBlocks = list
  boxes = shared
} else if let one = manifest["detector"] as? [String: Any] {
  detectorBlocks = [one.merging(["format": "rfdetr"]) { _, fish in fish }]
  boxes = ["mergeIoU": 0.5, "maxBoxes": one["maxBoxes"] as Any, "cropPadding": one["cropPadding"] as Any]
} else {
  fail("the manifest has no detectors")
}
let detectorPaths = values("--detector")
guard detectorPaths.count == detectorBlocks.count else {
  fail("the manifest has \(detectorBlocks.count) detectors; pass one --detector for each")
}
let withDetectorBoxes = CommandLine.arguments.contains("--detector-boxes")

let settings: VisionModelSettings
do {
  settings = try VisionModelSettings([
    "detectors": zip(detectorBlocks, detectorPaths).map { block, path -> [String: Any] in
      [
        "path": path, "format": block["format"] as Any, "inputSize": block["inputSize"] as Any,
        "mean": block["mean"] as Any, "std": block["std"] as Any,
        "scoreThreshold": block["scoreThreshold"] as Any, "maxBoxes": block["maxBoxes"] as Any,
      ]
    },
    "mergeIoU": boxes["mergeIoU"] as Any,
    "maxBoxes": boxes["maxBoxes"] as Any,
    "cropPadding": boxes["cropPadding"] as Any,
    "classifierPath": option("--classifier"),
    "classifierInputSize": classifier["inputSize"] as Any,
    "classifierMean": classifier["mean"] as Any,
    "classifierStd": classifier["std"] as Any,
    "embeddingSize": classifier["embeddingSize"] as Any,
    "cropThumbnailSize": manifest["cropThumbnailSize"] as Any,
    "cropFit": option("--crop-fit"),
  ])
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
    let result = try pipeline.analyze(["path": path, "withDetectorBoxes": withDetectorBoxes])
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
    var line: [String: Any] = [
      "path": path, "width": result["imageWidth"] as Any, "height": result["imageHeight"] as Any,
      "detections": detections, "detectMs": result["detectMs"] as Any,
    ]
    if let perDetector = result["detectorBoxes"] { line["detectorBoxes"] = perDetector }
    if let merged = result["mergedBoxes"] { line["mergedBoxes"] = merged }
    emit(line)
  } catch let error as VisionError {
    emit(["path": path, "error": error.message])
  } catch {
    emit(["path": path, "error": "\(error)"])
  }
  }
}
