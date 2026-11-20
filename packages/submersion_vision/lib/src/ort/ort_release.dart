/// The ONNX Runtime the build hook ships, per target: the official package
/// to download, its SHA-256, and the libraries to take out of it, each with
/// its own SHA-256. Pinned to ONNX Runtime 1.28, the version Windows ML
/// 2.5.96 ships (1.28.3), so the processor path is the same code on Android,
/// Windows and Linux. Apple platforms use Core ML and get nothing.
///
/// Sources (official, Microsoft's): Maven Central for Android and NuGet's
/// `Microsoft.ML.OnnxRuntime` for Linux and Windows. To move to a new
/// version, replace every URL and hash here, the vendored headers in
/// `third_party/onnxruntime/`, and the generated bindings
/// (`dart run tool/ffigen_ort.dart`).
library;

/// The asset id the engine's ONNX Runtime binding is bound to
/// (`ort_native.dart`).
const String ortNativeAsset = 'src/ort/ort_native.dart';

/// One library inside an [OrtArchive], shipped as a code asset.
class OrtLibrary {
  const OrtLibrary({
    required this.assetName,
    required this.entry,
    required this.sha256,
  });

  /// The code asset's name within this package.
  final String assetName;

  /// The library's path inside the archive.
  final String entry;
  final String sha256;
}

/// A package to download, and the libraries it carries.
class OrtArchive {
  const OrtArchive({
    required this.url,
    required this.sha256,
    required this.libraries,
  });

  final String url;
  final String sha256;
  final List<OrtLibrary> libraries;

  /// The file name the download is kept under.
  String get fileName => Uri.parse(url).pathSegments.last;
}

const _androidAar =
    'https://repo1.maven.org/maven2/com/microsoft/onnxruntime/'
    'onnxruntime-android/1.28.0/onnxruntime-android-1.28.0.aar';
const _androidAarSha256 =
    'f351a0638696f54b35184290dbc001d66daae17281ad0b548d2c70347d53b8a9';

const _ortNuget =
    'https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/'
    '1.28.0/microsoft.ml.onnxruntime.1.28.0.nupkg';
const _ortNugetSha256 =
    '769d1d3ea8ab6cd69f737c9dd4d4462aa4ad0ccfa106eaf506efc40d7bead5db';

const _archives = <String, OrtArchive>{
  'android-arm64': OrtArchive(
    url: _androidAar,
    sha256: _androidAarSha256,
    libraries: [
      OrtLibrary(
        assetName: ortNativeAsset,
        entry: 'jni/arm64-v8a/libonnxruntime.so',
        sha256:
            'f826d8efb03adf0a84f10e7ba408f9d4cd11b0a2ccd8d08aeb0f7451fb50cacc',
      ),
    ],
  ),
  'android-x64': OrtArchive(
    url: _androidAar,
    sha256: _androidAarSha256,
    libraries: [
      OrtLibrary(
        assetName: ortNativeAsset,
        entry: 'jni/x86_64/libonnxruntime.so',
        sha256:
            '8a31feb45126d981ffac430bd10bc66cfa1036e0864a9fbd80a94121f3085800',
      ),
    ],
  ),
  'linux-x64': OrtArchive(
    url:
        'https://api.nuget.org/v3-flatcontainer/microsoft.ml.onnxruntime/'
        '1.28.0/microsoft.ml.onnxruntime.1.28.0.nupkg',
    sha256: '769d1d3ea8ab6cd69f737c9dd4d4462aa4ad0ccfa106eaf506efc40d7bead5db',
    libraries: [
      OrtLibrary(
        assetName: ortNativeAsset,
        entry: 'runtimes/linux-x64/native/libonnxruntime.so',
        sha256:
            '1461ef7cc3d9e49982591721683cc3e3a55580aeca9a5254e7aac47b75ee4bab',
      ),
    ],
  ),
  // Plain ONNX Runtime (MIT), the processor only, until Windows ML's
  // distribution terms are settled for a GPLv3 app (piece 3, section 2a).
  'windows-x64': OrtArchive(
    url: _ortNuget,
    sha256: _ortNugetSha256,
    libraries: [
      OrtLibrary(
        assetName: ortNativeAsset,
        entry: 'runtimes/win-x64/native/onnxruntime.dll',
        sha256:
            '18370c375f07357fa5874344a9d9ac17e6b6fe1eb18b1dd209d79483b4470257',
      ),
    ],
  ),
};

/// What to download for [os] and [architecture] (the build hook's
/// `OS.name` and `Architecture.name`), or null where nothing ships.
OrtArchive? ortArchiveFor(String os, String architecture) =>
    _archives['$os-$architecture'];
