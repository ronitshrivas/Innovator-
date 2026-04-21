package com.innovation.innovator.reels

import android.content.Context
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.platform.PlatformView

class ReelsSurfaceView(
    context: Context,
    private val slot: Int,
    private val pool: ReelsPlayerPool
) : PlatformView, SurfaceHolder.Callback {

    private val surfaceView = SurfaceView(context).apply {
        // CRITICAL: setZOrderOnTop(true) makes the SurfaceView render ON TOP
        // of Flutter's composited layer.
        //
        // setZOrderMediaOverlay(true) renders above other SurfaceViews but
        // BELOW Flutter's UI layer on some devices — causing black screen.
        //
        // setZOrderOnTop(true) is the correct call for full-screen video
        // where you want native video above everything.
        setZOrderOnTop(true)
        holder.addCallback(this@ReelsSurfaceView)
    }

    override fun getView(): View = surfaceView

    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        pool.detachSurface(slot)
    }

    override fun surfaceCreated(holder: SurfaceHolder) {
        pool.attachSurface(slot, holder.surface)
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (holder.surface.isValid) pool.attachSurface(slot, holder.surface)
    }

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        pool.detachSurface(slot)
    }
}