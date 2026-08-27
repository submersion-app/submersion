package app.submersion

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity): local_auth's biometric
// prompt requires a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    private var metadataHandler: MetadataWriteHandler? = null
    private var localMediaHandler: LocalMediaHandler? = null
    private var deviceNameHandler: DeviceNameHandler? = null

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
        // ContentResolver work runs against the application context, but the
        // document-tree picker needs an Activity to startActivityForResult and
        // a path back through onActivityResult.
        localMediaHandler = LocalMediaHandler(applicationContext, localMediaChannel).also {
            it.attachActivity(this)
        }

        val deviceNameChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceNameHandler.CHANNEL,
        )
        deviceNameHandler = DeviceNameHandler(applicationContext, deviceNameChannel)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (localMediaHandler?.onPickTreeResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        localMediaHandler?.attachActivity(null)
        super.onDestroy()
    }
}
