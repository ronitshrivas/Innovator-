package com.innovation.innovator.reels

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * ReelsPlayerPlugin
 *
 * Registered in MainActivity.kt like this:
 *
 *   override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
 *       super.configureFlutterEngine(flutterEngine)
 *       flutterEngine.plugins.add(ReelsPlayerPlugin())
 *   }
 */
class ReelsPlayerPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var pool: ReelsPlayerPool

    // ── FlutterPlugin ────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        pool    = ReelsPlayerPool(context)

        channel = MethodChannel(binding.binaryMessenger, "reels_player")
        channel.setMethodCallHandler(this)

        // Register the SurfaceView factory so Flutter can embed native views
        binding.platformViewRegistry.registerViewFactory(
            "reels_surface_view",
            ReelsSurfaceViewFactory(pool, StandardMessageCodec.INSTANCE)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        pool.releaseAll()
    }

    // ── MethodCallHandler ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            // Prepare a slot with a URL — starts buffering immediately.
            // Call this as soon as you know the URL (e.g. feed loaded).
            "prepare" -> {
                val slot  = call.argument<Int>("slot") ?: return result.error("ARG", "slot missing", null)
                val url   = call.argument<String>("url") ?: return result.error("ARG", "url missing", null)
                val token = call.argument<String>("token") ?: ""
                pool.prepare(slot, url, token)
                result.success(null)
            }

            // Start playback for a slot. Near-instant if prepare() was called first.
            "play" -> {
                val slot = call.argument<Int>("slot") ?: return result.error("ARG", "slot missing", null)
                pool.play(slot)
                result.success(null)
            }

            // Pause playback for a slot.
            "pause" -> {
                val slot = call.argument<Int>("slot") ?: return result.error("ARG", "slot missing", null)
                pool.pause(slot)
                result.success(null)
            }

            // Set volume 0.0–1.0.
            "setVolume" -> {
                val slot   = call.argument<Int>("slot") ?: return result.error("ARG", "slot missing", null)
                val volume = call.argument<Double>("volume")?.toFloat() ?: 1f
                pool.setVolume(slot, volume)
                result.success(null)
            }

            // Seek to position in milliseconds.
            "seekTo" -> {
                val slot   = call.argument<Int>("slot") ?: return result.error("ARG", "slot missing", null)
                val posMs  = call.argument<Int>("positionMs")?.toLong() ?: 0L
                pool.seekTo(slot, posMs)
                result.success(null)
            }

            // Release a slot's player (frees memory).
            "release" -> {
                val slot = call.argument<Int>("slot") ?: return result.error("ARG", "slot missing", null)
                pool.release(slot)
                result.success(null)
            }

            // Release ALL players (call when leaving the reels screen).
            "releaseAll" -> {
                pool.releaseAll()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}