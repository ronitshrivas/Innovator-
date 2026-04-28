package com.innovation.innovator.reels

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource

/**
 * ReelsPlayerPool — 3 ExoPlayers for pre-buffering + 1 shared display surface.
 *
 * KEY DESIGN (fixes black screen):
 *   - Only ONE SurfaceView exists in Flutter (slot 0).
 *   - Surface is moved between ExoPlayers via switchSurface(newSlot).
 *   - Players buffer with NO surface attached — zero cost, no black frames.
 *   - On swipe, surface is handed to the next pre-buffered player → instant play.
 *
 * Slot convention:
 *   slot 0 → previous reel   (or initial current)
 *   slot 1 → current reel    (playing)
 *   slot 2 → next reel       (pre-buffering)
 */
class ReelsPlayerPool(private val context: Context) {

    private val players  = arrayOfNulls<ExoPlayer>(3)
    private val urls     = arrayOfNulls<String>(3)
    private val mainHandler = Handler(Looper.getMainLooper())

    // The single shared display surface (from slot-0 SurfaceView)
    private var displaySurface: android.view.Surface? = null
    // Which ExoPlayer slot currently owns the display surface
    private var displaySlot: Int = -1

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Prepare a slot: load the URL and start buffering in the background.
     * Does NOT require a surface — buffering happens off-screen.
     * Safe to call multiple times; skips if URL is unchanged.
     */
    fun prepare(slot: Int, url: String, token: String) {
        require(slot in 0..2)
        if (urls[slot] == url && players[slot] != null) return
        releaseSlot(slot)
        urls[slot] = url
        mainHandler.post {
            val player = buildPlayer(url, token)
            players[slot] = player
            // If this slot currently owns the display surface, attach it
            if (slot == displaySlot) {
                displaySurface?.let { player.setVideoSurface(it) }
            }
        }
    }

    /**
     * Switch the shared display surface to a new slot.
     * Called on every page change — surface is moved from old player to new.
     */
    fun switchSurface(toSlot: Int) {
        require(toSlot in 0..2)
        mainHandler.post {
            // Detach from old slot
            if (displaySlot in 0..2 && displaySlot != toSlot) {
                players[displaySlot]?.clearVideoSurface()
            }
            displaySlot = toSlot
            // Attach to new slot
            val s = displaySurface
            if (s != null && s.isValid) {
                players[toSlot]?.setVideoSurface(s)
            }
        }
    }

    /** Start/resume playback on a slot. */
    fun play(slot: Int) {
        require(slot in 0..2)
        mainHandler.post {
            players[slot]?.let {
                it.playWhenReady = true
                it.play()
            }
        }
    }

    /** Pause playback on a slot. */
    fun pause(slot: Int) {
        require(slot in 0..2)
        mainHandler.post { players[slot]?.pause() }
    }

    /** Set volume (0.0 = mute, 1.0 = full). */
    fun setVolume(slot: Int, volume: Float) {
        require(slot in 0..2)
        mainHandler.post { players[slot]?.volume = volume.coerceIn(0f, 1f) }
    }

    /** Seek to positionMs on a slot. */
    fun seekTo(slot: Int, positionMs: Long) {
        require(slot in 0..2)
        mainHandler.post { players[slot]?.seekTo(positionMs) }
    }

    /** Release one slot's player. */
    fun release(slot: Int) {
        require(slot in 0..2)
        releaseSlot(slot)
    }

    /** Release ALL players — call when leaving the reels screen. */
    fun releaseAll() {
        for (i in 0..2) releaseSlot(i)
        displaySurface = null
        displaySlot = -1
    }

    // ── Surface lifecycle (called by the single ReelsSurfaceView) ─────────────

    /**
     * Called by ReelsSurfaceView when the SurfaceHolder is created.
     * This is the ONLY surface in the system.
     */
    fun attachDisplaySurface(surface: android.view.Surface) {
        displaySurface = surface
        mainHandler.post {
            // Attach to current display slot (default to 0)
            val slot = if (displaySlot in 0..2) displaySlot else 0
            displaySlot = slot
            if (surface.isValid) {
                players[slot]?.setVideoSurface(surface)
            }
        }
    }

    fun setOnFirstFrameListener(slot: Int, callback: () -> Unit) {
        mainHandler.post {
            players[slot]?.addListener(object : Player.Listener {
                override fun onRenderedFirstFrame() {
                    callback()
                    players[slot]?.removeListener(this)
                }
            })
        }
    }

    /** Called when the SurfaceHolder is destroyed. */
    fun detachDisplaySurface() {
        displaySurface = null
        mainHandler.post {
            if (displaySlot in 0..2) {
                players[displaySlot]?.clearVideoSurface()
            }
        }
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private fun releaseSlot(slot: Int) {
        mainHandler.post {
            players[slot]?.run {
                if (slot == displaySlot) clearVideoSurface()
                stop()
                release()
            }
            players[slot] = null
            urls[slot] = null
        }
    }

    private fun buildPlayer(url: String, token: String): ExoPlayer {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                3_000,   // minBufferMs
                20_000,  // maxBufferMs
                1_500,   // bufferForPlaybackMs
                3_000    // bufferForPlaybackAfterRebufferMs
            )
            .build()

        val httpFactory = DefaultHttpDataSource.Factory().apply {
            setConnectTimeoutMs(8_000)
            setReadTimeoutMs(8_000)
            setAllowCrossProtocolRedirects(true)
            if (token.isNotEmpty()) {
                setDefaultRequestProperties(mapOf("Authorization" to "Bearer $token"))
            }
        }

        val mediaItem = MediaItem.fromUri(url)
        val mediaSource = if (url.contains(".m3u8") || url.contains("hls")) {
            HlsMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        } else {
            ProgressiveMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        }

        return ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .build()
            .apply {
                setMediaSource(mediaSource)
                repeatMode    = Player.REPEAT_MODE_ONE
                playWhenReady = false
                volume        = 1f
                prepare()   // start buffering immediately (no surface needed)
            }
    }
}