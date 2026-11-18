import 'dart:convert';

/// The spec's example model pack manifest, for the species id tests.
Map<String, Object?> _file(String name, String engine, int size) => {
  'name': name,
  'engine': engine,
  'size': size,
  'sha256': 'a' * 64,
};

Map<String, Object?> manifestMap() => {
  'formatVersion': 1,
  'packVersion': '2026.11.1',
  'detector': {
    'id': 'cfd-rfdetr-nano-640-20260706',
    'inputSize': 640,
    'mean': [0.485, 0.456, 0.406],
    'std': [0.229, 0.224, 0.225],
    'scoreThreshold': 0.3,
    'maxBoxes': 8,
    'cropPadding': 0.10,
  },
  'classifier': {
    'id': 'bioclip-2-vitl14-2957b32',
    'inputSize': 224,
    'mean': [0.48145466, 0.4578275, 0.40821073],
    'std': [0.26862954, 0.26130258, 0.27577711],
    'embeddingSize': 768,
    'logitScale': 100.0,
  },
  'naming': {
    'provisional': true,
    'minCropSide': 64,
    'minOpenScore': 0.15,
    'suggestScore': 0.50,
    'confidentScore': 0.70,
    'suggestScoreNoLocation': 0.70,
    'minAllowedCandidates': 200,
    'topK': 5,
  },
  'region': {'cellDegrees': 5, 'neighbourCells': 1},
  'cropThumbnailSize': 320,
  'files': [
    _file('detector.coreml.zip', 'coreml', 55000000),
    _file('classifier.coreml.zip', 'coreml', 600000000),
    _file('candidates.json', 'all', 1000000),
    _file('text_embeddings.f16', 'all', 12000000),
    _file('regions.bin', 'all', 2000000),
  ],
  'credits': [
    {'name': 'BioCLIP 2', 'licence': 'MIT', 'text': 'Imageomics Institute'},
  ],
};

String manifestJson([void Function(Map<String, Object?> m)? edit]) {
  final m = manifestMap();
  edit?.call(m);
  return jsonEncode(m);
}

/// A format 2 manifest carrying both detectors (issue #4691): the fish
/// detector, then Megalodon.
Map<String, Object?> manifestV2Map() {
  final m = manifestMap();
  m['formatVersion'] = 2;
  m.remove('detector');
  m['detectors'] = <Object?>[
    {
      'id': 'cfd-rfdetr-nano-640-20260706',
      'format': 'rfdetr',
      'file': 'detector',
      'inputSize': 640,
      'mean': [0.485, 0.456, 0.406],
      'std': [0.229, 0.224, 0.225],
      'scoreThreshold': 0.3,
      'maxBoxes': 8,
    },
    {
      'id': 'megalodon-yolo11x-403704d',
      'format': 'yolo',
      'file': 'detector-megalodon',
      'inputSize': 640,
      'mean': [0.0, 0.0, 0.0],
      'std': [1.0, 1.0, 1.0],
      'scoreThreshold': 0.25,
      'maxBoxes': 8,
    },
  ];
  m['boxes'] = {'mergeIoU': 0.5, 'maxBoxes': 8, 'cropPadding': 0.10};
  (m['files']! as List).insert(
    1,
    _file('detector-megalodon.coreml.zip', 'coreml', 110000000),
  );
  return m;
}

String manifestV2Json([void Function(Map<String, Object?> m)? edit]) {
  final m = manifestV2Map();
  edit?.call(m);
  return jsonEncode(m);
}

/// The detector entries of a format 2 manifest map, for editing.
List<Map<String, Object?>> detectorsOf(Map<String, Object?> m) =>
    (m['detectors']! as List).cast<Map<String, Object?>>();
