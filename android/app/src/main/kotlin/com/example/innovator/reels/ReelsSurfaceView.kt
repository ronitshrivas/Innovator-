package com.innovation.innovator.reels

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.platform.PlatformView

/**
 * ReelsSurfaceView
 *
 * A native Android SurfaceView that attaches itself to the correct
 * ExoPlayer slot in ReelsPlayerPool when the surface is ready.
 *
 * Why SurfaceView and not TextureView?
 *   - SurfaceView renders on a separate hardware overlay — zero GPU cost
 *     for the Flutter compositor.
 *   - TextureView copies every frame through the GPU — ~30% more battery,
 *     more heat, more dropped frames on mid-range phones.
 */
class ReelsSurfaceView(
    context: Context,
    private val slot: Int,
    private val pool: ReelsPlayerPool
) : PlatformView, SurfaceHolder.Callback {

    private val surfaceView = SurfaceView(context).apply {
        // Keep the surface alive when off-screen (avoids recreating it on scroll)
        holder.addCallback(this@ReelsSurfaceView)
    }

    // ── PlatformView ─────────────────────────────────────────────────────────

    override fun getView(): View = surfaceView

    override fun dispose() {
        pool.detachSurface(slot)
        surfaceView.holder.removeCallback(this)
    }

    // ── SurfaceHolder.Callback ───────────────────────────────────────────────

    override fun surfaceCreated(holder: SurfaceHolder) {
        // Surface is ready — hand it to the player in this slot
        pool.attachSurface(slot, holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        // No action needed — ExoPlayer handles resolution changes internally
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        pool.detachSurface(slot)
    }
}