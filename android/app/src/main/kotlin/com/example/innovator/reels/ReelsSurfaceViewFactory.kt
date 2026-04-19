package com.innovation.innovator.reels

import android.content.Context
import io.flutter.plugin.common.MessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * ReelsSurfaceViewFactory
 *
 * Registered in ReelsPlayerPlugin with the view type "reels_surface_view".
 * Flutter creates one of these per reel slot using AndroidView().
 *
 * The `creationParams` map must contain:
 *   { "slot": 0 }   ← which player slot this view belongs to
 */
class ReelsSurfaceViewFactory(
    private val pool: ReelsPlayerPool,
    codec: MessageCodec<Any?>
) : PlatformViewFactory(codec) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any> ?: emptyMap()
        val slot   = (params["slot"] as? Int) ?: 0
        return ReelsSurfaceView(context, slot, pool)
    }
}