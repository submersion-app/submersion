package app.submersion

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var metadataHandler: MetadataWriteHandler? = null
    private var localMediaHandler: LocalMediaHandler? = null

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
        // a path back through onActivityResult (FlutterActivity is a plain
        // android.app.Activity, so the AndroidX ActivityResult APIs are not
        // available here).
        localMediaHandler = LocalMediaHandler(applicationContext, localMediaChannel).also {
            it.attachActivity(this)
        }
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
