package com.submersion.libdivecomputer

import io.flutter.embedding.engine.plugins.FlutterPlugin

class LibdivecomputerPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        val messenger = binding.binaryMessenger
        val api = DiveComputerHostApiImpl(context, messenger)
        DiveComputerHostApi.setUp(messenger, api)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        DiveComputerHostApi.setUp(binding.binaryMessenger, null)
    }
}
