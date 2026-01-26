package app.submersion

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var metadataHandler: MetadataWriteHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register platform channel handlers
        metadataHandler = MetadataWriteHandler(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        )
    }
}
