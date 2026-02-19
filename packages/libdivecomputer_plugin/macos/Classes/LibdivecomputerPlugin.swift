import FlutterMacOS

public class LibdivecomputerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger
        let api = DiveComputerHostApiImpl(messenger: messenger)
        DiveComputerHostApiSetup.setUp(binaryMessenger: messenger, api: api)
    }
}
