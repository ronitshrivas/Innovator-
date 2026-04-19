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
 * ReelsPlayerPool
 *
 * Manages exactly 3 ExoPlayer instances:
 *   slot 0 → previous reel  (kept alive for fast back-swipe)
 *   slot 1 → current reel   (playing)
 *   slot 2 → next reel      (pre-buffering in background)
 *
 * Because the next reel starts buffering BEFORE the user swipes,
 * play() is nearly instant — no spinner, no delay.
 */
class ReelsPlayerPool(private val context: Context) {

    // Exactly 3 slots
    private val players  = arrayOfNulls<ExoPlayer>(3)
    private val urls     = arrayOfNulls<String>(3)
    private val surfaces = arrayOfNulls<android.view.Surface>(3)
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Prepare a slot: build an ExoPlayer, load the HLS/MP4 URL, start buffering.
     * Safe to call multiple times — if the URL is unchanged, does nothing.
     * If the URL changed, releases the old player and creates a fresh one.
     */
    fun prepare(slot: Int, url: String, token: String) {
        require(slot in 0..2) { "slot must be 0, 1, or 2" }

        // Nothing to do if already prepared with same URL
        if (urls[slot] == url && players[slot] != null) return

        // Release old player for this slot
        releaseSlot(slot)

        urls[slot] = url
        mainHandler.post {
            val player = buildPlayer(url, token)
            players[slot] = player
            // If a surface is already waiting (view created before prepare), attach it
            surfaces[slot]?.let { player.setVideoSurface(it) }
        }
    }

    /** Start/resume playback on a slot. Near-instant if prepare() ran first. */
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
        mainHandler.post {
            players[slot]?.pause()
        }
    }

    /** Set volume on a slot (0.0 = mute, 1.0 = full). */
    fun setVolume(slot: Int, volume: Float) {
        require(slot in 0..2)
        mainHandler.post {
            players[slot]?.volume = volume.coerceIn(0f, 1f)
        }
    }

    /** Seek to positionMs on a slot. */
    fun seekTo(slot: Int, positionMs: Long) {
        require(slot in 0..2)
        mainHandler.post {
            players[slot]?.seekTo(positionMs)
        }
    }

    /**
     * Attach a Surface to a slot.
     * Called by ReelsSurfaceView when the SurfaceHolder is created.
     */
    fun attachSurface(slot: Int, surface: android.view.Surface) {
        require(slot in 0..2)
        surfaces[slot] = surface
        mainHandler.post {
            players[slot]?.setVideoSurface(surface)
        }
    }

    /**
     * Detach the Surface from a slot.
     * Called by ReelsSurfaceView when the SurfaceHolder is destroyed.
     */
    fun detachSurface(slot: Int) {
        require(slot in 0..2)
        surfaces[slot] = null
        mainHandler.post {
            players[slot]?.clearVideoSurface()
        }
    }

    /** Release the player in one slot (frees memory, stops buffering). */
    fun release(slot: Int) {
        require(slot in 0..2)
        releaseSlot(slot)
    }

    /** Release ALL players — call when user leaves the reels screen. */
    fun releaseAll() {
        for (i in 0..2) releaseSlot(i)
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private fun releaseSlot(slot: Int) {
        mainHandler.post {
            players[slot]?.run {
                clearVideoSurface()
                stop()
                release()
            }
            players[slot] = null
            urls[slot]    = null
        }
    }

    private fun buildPlayer(url: String, token: String): ExoPlayer {
        // ── Load control: tuned for short HLS reels ──────────────────────────
        // minBuffer 1.5s  → start playing quickly
        // maxBuffer 12s   → buffer a bit ahead without wasting RAM
        // bufferForPlayback 1s → resume after 1s when rebuffering
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                1_500,   // minBufferMs
                12_000,  // maxBufferMs
                1_000,   // bufferForPlaybackMs
                1_000    // bufferForPlaybackAfterRebufferMs
            )
            .build()

        // ── HTTP data source with auth header if token present ───────────────
        val httpFactory = DefaultHttpDataSource.Factory().apply {
            setConnectTimeoutMs(8_000)
            setReadTimeoutMs(8_000)
            setAllowCrossProtocolRedirects(true)
            if (token.isNotEmpty()) {
                setDefaultRequestProperties(mapOf("Authorization" to "Bearer $token"))
            }
        }

        // ── Choose media source based on URL ─────────────────────────────────
        val mediaItem = MediaItem.fromUri(url)
        val mediaSource = if (url.contains(".m3u8") || url.contains("hls")) {
            // HLS stream → use HlsMediaSource (adaptive bitrate, no stutter)
            HlsMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        } else {
            // Regular MP4/video file → use ProgressiveMediaSource
            ProgressiveMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        }

        // ── Build ExoPlayer ──────────────────────────────────────────────────
        return ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .build()
            .apply {
                setMediaSource(mediaSource)
                repeatMode      = Player.REPEAT_MODE_ONE  // loop the reel
                playWhenReady   = false                   // wait for play()
                volume          = 1f
                prepare()  // ← starts buffering immediately in background
            }
    }
}