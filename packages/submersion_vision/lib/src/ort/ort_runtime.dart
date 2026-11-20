import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'package:submersion_vision/src/ort/ort_c_api.g.dart';
import 'package:submersion_vision/src/ort/ort_native.dart';

/// The C API version these bindings were generated from (ONNX Runtime 1.28).
const int _ortApiVersion = 28;

/// Where a session runs.
enum OrtDevice {
  /// The processor.
  cpu,

  /// The GPU when ONNX Runtime finds one it can use, else an NPU, else the
  /// processor (its device selection policy).
  preferGpu,

  /// DirectML, on Windows.
  directMl,
}

/// How a session is opened.
class OrtSessionSettings {
  const OrtSessionSettings({
    this.intraOpThreads = 0,
    this.device = OrtDevice.cpu,
  });

  /// Threads for one operator; 0 lets ONNX Runtime choose.
  final int intraOpThreads;
  final OrtDevice device;
}

/// A float32 tensor: its shape and its values.
class OrtTensor {
  const OrtTensor(this.shape, this.data);

  final List<int> shape;
  final Float32List data;
}

/// A failure ONNX Runtime reported, or a model it cannot run.
class OrtException implements Exception {
  const OrtException(this.message);

  final String message;

  @override
  String toString() => 'OrtException($message)';
}

typedef _Status = Pointer<OrtStatus>;

/// ONNX Runtime's environment and API table. One per isolate is enough.
class OrtRuntime {
  OrtRuntime._(this._api, this._env);

  /// The runtime in the library the build hook ships, or the one at
  /// [libraryPath] (tests and the scoring runner on a Mac).
  factory OrtRuntime.open({String? libraryPath}) {
    final Pointer<OrtApiBase> base;
    try {
      base = libraryPath == null
          ? ortGetApiBaseFromAsset()
          : DynamicLibrary.open(libraryPath).lookupFunction<
              Pointer<OrtApiBase> Function(),
              Pointer<OrtApiBase> Function()
            >('OrtGetApiBase')();
    } on Object catch (e) {
      throw OrtException('ONNX Runtime could not be loaded: $e');
    }
    final getApi = base.ref.GetApi.asFunction<Pointer<OrtApi> Function(int)>();
    final api = getApi(_ortApiVersion);
    if (api == nullptr) {
      final version = base.ref.GetVersionString
          .asFunction<Pointer<Char> Function()>()()
          .cast<Utf8>()
          .toDartString();
      throw OrtException(
        'ONNX Runtime $version does not offer API version $_ortApiVersion',
      );
    }
    final env = calloc<Pointer<OrtEnv>>();
    final logId = 'submersion'.toNativeUtf8();
    try {
      _check(
        api,
        api.ref.CreateEnv
            .asFunction<
              _Status Function(int, Pointer<Char>, Pointer<Pointer<OrtEnv>>)
            >()(
          OrtLoggingLevel.ORT_LOGGING_LEVEL_WARNING.value,
          logId.cast(),
          env,
        ),
      );
      return OrtRuntime._(api, env.value);
    } finally {
      calloc.free(logId);
      calloc.free(env);
    }
  }

  final Pointer<OrtApi> _api;
  final Pointer<OrtEnv> _env;
  bool _closed = false;

  /// Opens the model at [modelPath].
  OrtModelSession openSession(
    String modelPath, {
    OrtSessionSettings settings = const OrtSessionSettings(),
  }) {
    _open();
    final api = _api;
    final optionsOut = calloc<Pointer<OrtSessionOptions>>();
    final sessionOut = calloc<Pointer<OrtSession>>();
    try {
      _check(
        api,
        api.ref.CreateSessionOptions
            .asFunction<
              _Status Function(Pointer<Pointer<OrtSessionOptions>>)
            >()(optionsOut),
      );
      final options = optionsOut.value;
      try {
        _configure(options, settings);
        final path = _ortPath(modelPath);
        try {
          _check(
            api,
            api.ref.CreateSession
                .cast<
                  NativeFunction<
                    _Status Function(
                      Pointer<OrtEnv>,
                      Pointer<Void>,
                      Pointer<OrtSessionOptions>,
                      Pointer<Pointer<OrtSession>>,
                    )
                  >
                >()
                .asFunction<
                  _Status Function(
                    Pointer<OrtEnv>,
                    Pointer<Void>,
                    Pointer<OrtSessionOptions>,
                    Pointer<Pointer<OrtSession>>,
                  )
                >()(_env, path, options, sessionOut),
          );
        } finally {
          calloc.free(path);
        }
      } finally {
        api.ref.ReleaseSessionOptions
            .asFunction<void Function(Pointer<OrtSessionOptions>)>()(options);
      }
      return OrtModelSession._(api, sessionOut.value, settings.device);
    } finally {
      calloc.free(optionsOut);
      calloc.free(sessionOut);
    }
  }

  /// Registers a hardware engine's library with the environment under
  /// [name] (Windows ML hands these out).
  void registerProviderLibrary(String name, String path) {
    _open();
    final nativeName = name.toNativeUtf8();
    final nativePath = _ortPath(path);
    try {
      _check(
        _api,
        _api.ref.RegisterExecutionProviderLibrary
            .cast<
              NativeFunction<
                _Status Function(Pointer<OrtEnv>, Pointer<Char>, Pointer<Void>)
              >
            >()
            .asFunction<
              _Status Function(Pointer<OrtEnv>, Pointer<Char>, Pointer<Void>)
            >()(_env, nativeName.cast(), nativePath),
      );
    } finally {
      calloc.free(nativeName);
      calloc.free(nativePath);
    }
  }

  /// Releases the environment. Sessions opened from it must be closed first.
  void close() {
    if (_closed) return;
    _closed = true;
    _api.ref.ReleaseEnv.asFunction<void Function(Pointer<OrtEnv>)>()(_env);
  }

  void _open() {
    if (_closed) throw const OrtException('the runtime is closed');
  }

  void _configure(Pointer<OrtSessionOptions> options, OrtSessionSettings s) {
    final api = _api;
    if (s.intraOpThreads > 0) {
      _check(
        api,
        api.ref.SetIntraOpNumThreads
            .asFunction<_Status Function(Pointer<OrtSessionOptions>, int)>()(
          options,
          s.intraOpThreads,
        ),
      );
    }
    // Idle threads wait rather than spin, which keeps a phone cool between
    // frames.
    final key = 'session.intra_op.allow_spinning'.toNativeUtf8();
    final value = '0'.toNativeUtf8();
    try {
      _check(
        api,
        api.ref.AddSessionConfigEntry
            .asFunction<
              _Status Function(
                Pointer<OrtSessionOptions>,
                Pointer<Char>,
                Pointer<Char>,
              )
            >()(options, key.cast(), value.cast()),
      );
    } finally {
      calloc.free(key);
      calloc.free(value);
    }
    switch (s.device) {
      case OrtDevice.cpu:
        break;
      case OrtDevice.preferGpu:
        _check(
          api,
          api.ref.SessionOptionsSetEpSelectionPolicy
              .asFunction<_Status Function(Pointer<OrtSessionOptions>, int)>()(
            options,
            OrtExecutionProviderDevicePolicy
                .OrtExecutionProviderDevicePolicy_PREFER_GPU
                .value,
          ),
        );
      case OrtDevice.directMl:
        final name = 'DML'.toNativeUtf8();
        try {
          _check(
            api,
            api.ref.SessionOptionsAppendExecutionProvider
                .asFunction<
                  _Status Function(
                    Pointer<OrtSessionOptions>,
                    Pointer<Char>,
                    Pointer<Pointer<Char>>,
                    Pointer<Pointer<Char>>,
                    int,
                  )
                >()(options, name.cast(), nullptr, nullptr, 0),
          );
        } finally {
          calloc.free(name);
        }
    }
  }
}

/// One loaded model.
class OrtModelSession {
  OrtModelSession._(this._api, this._session, this._device) {
    final allocatorOut = calloc<Pointer<OrtAllocator>>();
    try {
      _check(
        _api,
        _api.ref.GetAllocatorWithDefaultOptions
            .asFunction<_Status Function(Pointer<Pointer<OrtAllocator>>)>()(
          allocatorOut,
        ),
      );
      final allocator = allocatorOut.value;
      _inputNames = _names(allocator, input: true);
      _outputNames = _names(allocator, input: false);
    } finally {
      calloc.free(allocatorOut);
    }
    final infoOut = calloc<Pointer<OrtMemoryInfo>>();
    try {
      _check(
        _api,
        _api.ref.CreateCpuMemoryInfo
            .asFunction<
              _Status Function(int, int, Pointer<Pointer<OrtMemoryInfo>>)
            >()(
          OrtAllocatorType.OrtArenaAllocator.value,
          OrtMemType.OrtMemTypeDefault.value,
          infoOut,
        ),
      );
      _memoryInfo = infoOut.value;
    } finally {
      calloc.free(infoOut);
    }
  }

  final Pointer<OrtApi> _api;
  final Pointer<OrtSession> _session;
  final OrtDevice _device;
  late final Pointer<Pointer<Char>> _inputNames;
  late final Pointer<Pointer<Char>> _outputNames;
  late final Pointer<OrtMemoryInfo> _memoryInfo;
  int _outputCount = 0;
  bool _closed = false;

  /// The device the session was opened for.
  String get device => _device.name;

  /// Runs the model's first input and returns every output, in order.
  List<OrtTensor> run(OrtTensor input) {
    if (_closed) throw const OrtException('the session is closed');
    final api = _api;
    final count = input.data.length;
    final data = calloc<Float>(count);
    final shape = calloc<Int64>(input.shape.length);
    final inputValue = calloc<Pointer<OrtValue>>();
    final outputs = calloc<Pointer<OrtValue>>(_outputCount);
    try {
      data.asTypedList(count).setAll(0, input.data);
      for (var i = 0; i < input.shape.length; i++) {
        shape[i] = input.shape[i];
      }
      _check(
        api,
        api.ref.CreateTensorWithDataAsOrtValue
            .asFunction<
              _Status Function(
                Pointer<OrtMemoryInfo>,
                Pointer<Void>,
                int,
                Pointer<Int64>,
                int,
                int,
                Pointer<Pointer<OrtValue>>,
              )
            >()(
          _memoryInfo,
          data.cast(),
          count * sizeOf<Float>(),
          shape,
          input.shape.length,
          ONNXTensorElementDataType.ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT.value,
          inputValue,
        ),
      );
      try {
        _check(
          api,
          api.ref.Run
              .asFunction<
                _Status Function(
                  Pointer<OrtSession>,
                  Pointer<OrtRunOptions>,
                  Pointer<Pointer<Char>>,
                  Pointer<Pointer<OrtValue>>,
                  int,
                  Pointer<Pointer<Char>>,
                  int,
                  Pointer<Pointer<OrtValue>>,
                )
              >()(
            _session,
            nullptr,
            _inputNames,
            inputValue,
            1,
            _outputNames,
            _outputCount,
            outputs,
          ),
        );
        return [for (var i = 0; i < _outputCount; i++) _read(outputs[i])];
      } finally {
        final release = api.ref.ReleaseValue
            .asFunction<void Function(Pointer<OrtValue>)>();
        release(inputValue.value);
        for (var i = 0; i < _outputCount; i++) {
          if (outputs[i] != nullptr) release(outputs[i]);
        }
      }
    } finally {
      calloc.free(data);
      calloc.free(shape);
      calloc.free(inputValue);
      calloc.free(outputs);
    }
  }

  /// Releases the model's memory.
  void close() {
    if (_closed) return;
    _closed = true;
    _api.ref.ReleaseMemoryInfo
        .asFunction<void Function(Pointer<OrtMemoryInfo>)>()(_memoryInfo);
    _api.ref.ReleaseSession.asFunction<void Function(Pointer<OrtSession>)>()(
      _session,
    );
    _freeNames(_inputNames, 1);
    _freeNames(_outputNames, _outputCount);
  }

  /// The model's input or output names, copied into memory this session
  /// owns. Only the first input is used.
  Pointer<Pointer<Char>> _names(
    Pointer<OrtAllocator> allocator, {
    required bool input,
  }) {
    final api = _api;
    final countOut = calloc<Size>();
    final nameOut = calloc<Pointer<Char>>();
    try {
      _check(
        api,
        (input ? api.ref.SessionGetInputCount : api.ref.SessionGetOutputCount)
            .asFunction<_Status Function(Pointer<OrtSession>, Pointer<Size>)>()(
          _session,
          countOut,
        ),
      );
      final count = input ? 1 : countOut.value;
      if (input && countOut.value < 1) {
        throw const OrtException('the model has no input');
      }
      if (!input) _outputCount = count;
      final names = calloc<Pointer<Char>>(count);
      final getName =
          (input ? api.ref.SessionGetInputName : api.ref.SessionGetOutputName)
              .asFunction<
                _Status Function(
                  Pointer<OrtSession>,
                  int,
                  Pointer<OrtAllocator>,
                  Pointer<Pointer<Char>>,
                )
              >();
      final free = api.ref.AllocatorFree
          .asFunction<_Status Function(Pointer<OrtAllocator>, Pointer<Void>)>();
      for (var i = 0; i < count; i++) {
        _check(api, getName(_session, i, allocator, nameOut));
        final name = nameOut.value.cast<Utf8>().toDartString();
        _check(api, free(allocator, nameOut.value.cast()));
        names[i] = name.toNativeUtf8().cast();
      }
      return names;
    } finally {
      calloc.free(countOut);
      calloc.free(nameOut);
    }
  }

  void _freeNames(Pointer<Pointer<Char>> names, int count) {
    for (var i = 0; i < count; i++) {
      calloc.free(names[i]);
    }
    calloc.free(names);
  }

  OrtTensor _read(Pointer<OrtValue> value) {
    final api = _api;
    final infoOut = calloc<Pointer<OrtTensorTypeAndShapeInfo>>();
    final sizeOut = calloc<Size>();
    final typeOut = calloc<UnsignedInt>();
    final dataOut = calloc<Pointer<Void>>();
    try {
      _check(
        api,
        api.ref.GetTensorTypeAndShape
            .asFunction<
              _Status Function(
                Pointer<OrtValue>,
                Pointer<Pointer<OrtTensorTypeAndShapeInfo>>,
              )
            >()(value, infoOut),
      );
      final info = infoOut.value;
      try {
        _check(
          api,
          api.ref.GetTensorElementType
              .asFunction<
                _Status Function(
                  Pointer<OrtTensorTypeAndShapeInfo>,
                  Pointer<UnsignedInt>,
                )
              >()(info, typeOut),
        );
        if (typeOut.value !=
            ONNXTensorElementDataType
                .ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT
                .value) {
          throw OrtException(
            'an output is not float32 (element type ${typeOut.value})',
          );
        }
        _check(
          api,
          api.ref.GetDimensionsCount
              .asFunction<
                _Status Function(
                  Pointer<OrtTensorTypeAndShapeInfo>,
                  Pointer<Size>,
                )
              >()(info, sizeOut),
        );
        final rank = sizeOut.value;
        final dims = calloc<Int64>(rank == 0 ? 1 : rank);
        final List<int> shape;
        try {
          _check(
            api,
            api.ref.GetDimensions
                .asFunction<
                  _Status Function(
                    Pointer<OrtTensorTypeAndShapeInfo>,
                    Pointer<Int64>,
                    int,
                  )
                >()(info, dims, rank),
          );
          shape = [for (var i = 0; i < rank; i++) dims[i]];
        } finally {
          calloc.free(dims);
        }
        _check(
          api,
          api.ref.GetTensorShapeElementCount
              .asFunction<
                _Status Function(
                  Pointer<OrtTensorTypeAndShapeInfo>,
                  Pointer<Size>,
                )
              >()(info, sizeOut),
        );
        final count = sizeOut.value;
        _check(
          api,
          api.ref.GetTensorMutableData
              .asFunction<
                _Status Function(Pointer<OrtValue>, Pointer<Pointer<Void>>)
              >()(value, dataOut),
        );
        final values = Float32List(count)
          ..setAll(0, dataOut.value.cast<Float>().asTypedList(count));
        return OrtTensor(shape, values);
      } finally {
        api.ref.ReleaseTensorTypeAndShapeInfo
            .asFunction<void Function(Pointer<OrtTensorTypeAndShapeInfo>)>()(
          info,
        );
      }
    } finally {
      calloc.free(infoOut);
      calloc.free(sizeOut);
      calloc.free(typeOut);
      calloc.free(dataOut);
    }
  }
}

/// [path] as ONNX Runtime's `ORTCHAR_T` string: UTF-16 on Windows, UTF-8
/// elsewhere. Freed with `calloc.free`.
Pointer<Void> _ortPath(String path) => Platform.isWindows
    ? path.toNativeUtf16().cast()
    : path.toNativeUtf8().cast();

/// Throws the message of a failed [status], freeing it.
void _check(Pointer<OrtApi> api, _Status status) {
  if (status == nullptr) return;
  final message = api.ref.GetErrorMessage
      .asFunction<Pointer<Char> Function(_Status)>()(status)
      .cast<Utf8>()
      .toDartString();
  api.ref.ReleaseStatus.asFunction<void Function(_Status)>()(status);
  throw OrtException(message);
}
