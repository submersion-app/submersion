/// The ONNX Runtime the build hook ships, per target: the official package
/// to download, its SHA-256, and the libraries to take out of it, each with
/// its own SHA-256. Pinned to ONNX Runtime 1.28, the version Windows ML
/// 2.5.96 ships (1.28.3), so the processor path is the same code on Android,
/// Windows and Linux. Apple platforms use Core ML and get nothing.
///
/// Sources (official, Microsoft's): Maven Central for Android, NuGet's
/// `Microsoft.ML.OnnxRuntime` for Linux, and NuGet's
/// `Microsoft.Windows.AI.MachineLearning` (Windows ML) for Windows, whose
/// three libraries sit beside the executable with no Windows App SDK
/// bootstrap (findings, docs/design/findings/2026-11-20-windows-ml-unpackaged.md).
/// To move to a new version, replace every URL and hash here, the vendored
/// headers in `third_party/onnxruntime/`, and the generated bindings
/// (`cd tool/ffigen && dart run ffigen_ort.dart`).
library;

/// The asset id the engine's ONNX Runtime binding is bound to
/// (`ort_native.dart`).
const String ortNativeAsset = 'src/ort/ort_native.dart';

/// The asset id Windows ML's catalogue binding is bound to
/// (`winml_native.dart`).
const String winMlNativeAsset = 'src/winml/winml_native.dart';

/// DirectML, which nothing binds: ONNX Runtime loads it by name from beside
/// the executable.
const String directMlAsset = 'src/winml/directml';

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

const _winMlNuget =
    'https://api.nuget.org/v3-flatcontainer/microsoft.windows.ai.machinelearning/'
    '2.5.96/microsoft.windows.ai.machinelearning.2.5.96.nupkg';
const _winMlNugetSha256 =
    '35d6e84feb4142e8cecaf36704fa3ab0fc8251d892850fb80e8341f7d09653a3';

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
    url: _ortNuget,
    sha256: _ortNugetSha256,
    libraries: [
      OrtLibrary(
        assetName: ortNativeAsset,
        entry: 'runtimes/linux-x64/native/libonnxruntime.so',
        sha256:
            '1461ef7cc3d9e49982591721683cc3e3a55580aeca9a5254e7aac47b75ee4bab',
      ),
    ],
  ),
  // Windows ML 2.5.96 (ONNX Runtime 1.28.3). Its distribution terms were
  // accepted by the maintainer on 2026-11-20: the installer shows them
  // (windows/installer), and they come with the app's licences.
  'windows-x64': OrtArchive(
    url: _winMlNuget,
    sha256: _winMlNugetSha256,
    libraries: [
      OrtLibrary(
        assetName: ortNativeAsset,
        entry: 'runtimes/win-x64/native/onnxruntime.dll',
        sha256:
            'f4904f839c48216fa98c83847a9eb8ded25e3258105630cad98916329a0538ef',
      ),
      OrtLibrary(
        assetName: winMlNativeAsset,
        entry:
            'runtimes/win-x64/native/Microsoft.Windows.AI.MachineLearning.dll',
        sha256:
            '8205a572b36423860a7a584e67d6c4f2dd2ece497ab8a3c82129c114fb6d7be0',
      ),
      OrtLibrary(
        assetName: directMlAsset,
        entry: 'runtimes/win-x64/native/DirectML.dll',
        sha256:
            '82c6e345cc62a9d1e06874aac4e3e1f990432a2baeae5888477933e26b2c0894',
      ),
    ],
  ),
};

/// What to download for [os] and [architecture] (the build hook's
/// `OS.name` and `Architecture.name`), or null where nothing ships.
OrtArchive? ortArchiveFor(String os, String architecture) =>
    _archives['$os-$architecture'];
