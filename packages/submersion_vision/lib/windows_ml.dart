/// Windows ML's catalogue of hardware engines, for the marine life engine
/// on Windows. Imports `dart:ffi`: never import it from code the web build
/// reaches.
library;

export 'src/winml/winml_catalog.dart'
    show WinMlCatalog, WinMlCatalogue, WinMlEngine, WinMlReadyState;
