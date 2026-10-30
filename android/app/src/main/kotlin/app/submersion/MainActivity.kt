package app.submersion

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity): local_auth's biometric
// prompt requires a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private var metadataHandler: MetadataWriteHandler? = null
    private var localMediaHandler: LocalMediaHandler? = null
    private var deviceNameHandler: DeviceNameHandler? = null
    private var systemProxyHandler: SystemProxyHandler? = null
    private var cardEmulationHandler: CardEmulationHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register platform channel handlers
        metadataHandler = MetadataWriteHandler(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        )

        val localMediaChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LocalMediaHandler.CHANNEL,
        )
        localMediaHandler = LocalMediaHandler(applicationContext, localMediaChannel)

        val deviceNameChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceNameHandler.CHANNEL,
        )
        deviceNameHandler = DeviceNameHandler(applicationContext, deviceNameChannel)

        val systemProxyChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SystemProxyHandler.CHANNEL,
        )
        systemProxyHandler = SystemProxyHandler(applicationContext, systemProxyChannel)

        val cardEmulationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CardEmulationHandler.CHANNEL,
        )
        cardEmulationHandler = CardEmulationHandler(this, cardEmulationChannel)
    }

    override fun onPause() {
        cardEmulationHandler?.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        cardEmulationHandler?.onResume()
    }
}
