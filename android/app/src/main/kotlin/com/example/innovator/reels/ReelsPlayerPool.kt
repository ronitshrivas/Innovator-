package com.innovation.innovator.reels

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource

/**
 * ReelsPlayerPool — 3 ExoPlayer slots, surface-safe, crash-proof.
 *
 * KEY FIXES vs previous version:
 * 1. Player is NEVER released while a surface is attached — prevents
 *    "setSurface() valid only at Executing states; currently at Released"
 * 2. prepare() checks if player is already healthy before rebuilding
 * 3. attachSurface() calls player.setVideoSurface() safely with a null check
 * 4. detachSurface() calls clearVideoSurface() but NEVER releases the player
 * 5. Error listener rebuilds the player automatically on crash
 */
class ReelsPlayerPool(private val context: Context) {

    companion object {
        private const val TAG = "ReelsPool"
        const val SLOTS = 3
    }

    private val main = Handler(Looper.getMainLooper())

    // Per-slot state
    private val players  = arrayOfNulls<ExoPlayer>(SLOTS)
    private val urls     = arrayOfNulls<String>(SLOTS)
    private val tokens   = arrayOfNulls<String>(SLOTS)
    private val surfaces = arrayOfNulls<android.view.Surface>(SLOTS)

    // ── Public API ─────────────────────────────────────────────────────────

    fun prepare(slot: Int, url: String, token: String) {
        if (slot !in 0 until SLOTS) return
        main.post {
            // Already healthy with the same URL — reattach surface and return
            val existing = players[slot]
            if (existing != null && urls[slot] == url) {
                Log.d(TAG, "slot=$slot already prepared, reattaching surface")
                val s = surfaces[slot]
                if (s != null && s.isValid) existing.setVideoSurface(s)
                return@post
            }
            Log.d(TAG, "prepare slot=$slot url=$url")
            destroyPlayer(slot)
            urls[slot]   = url
            tokens[slot] = token
            val p = buildPlayer(slot, url, token)
            players[slot] = p
            // Attach surface if one is already waiting
            val s = surfaces[slot]
            if (s != null && s.isValid) p.setVideoSurface(s)
        }
    }

    fun play(slot: Int) {
        if (slot !in 0 until SLOTS) return
        main.post {
            val p = players[slot]
            if (p == null) {
                Log.w(TAG, "play slot=$slot — no player, rebuilding")
                val url = urls[slot] ?: return@post
                val tok = tokens[slot] ?: ""
                val fresh = buildPlayer(slot, url, tok)
                players[slot] = fresh
                val s = surfaces[slot]
                if (s != null && s.isValid) fresh.setVideoSurface(s)
                fresh.playWhenReady = true
                fresh.play()
                return@post
            }
            // Re-attach surface every time before playing
            val s = surfaces[slot]
            if (s != null && s.isValid) {
                try { p.setVideoSurface(s) } catch (e: Exception) {
                    Log.w(TAG, "setVideoSurface failed slot=$slot: $e — rebuilding")
                    rebuildAndPlay(slot)
                    return@post
                }
            }
            p.playWhenReady = true
            try { p.play() } catch (e: Exception) {
                Log.w(TAG, "play() failed slot=$slot: $e — rebuilding")
                rebuildAndPlay(slot)
            }
            Log.d(TAG, "play slot=$slot")
        }
    }

    fun pause(slot: Int) {
        if (slot !in 0 until SLOTS) return
        main.post {
            try { players[slot]?.pause() } catch (_: Exception) {}
        }
    }

    fun pauseAll() {
        main.post {
            for (i in 0 until SLOTS) try { players[i]?.pause() } catch (_: Exception) {}
        }
    }

    fun setVolume(slot: Int, volume: Float) {
        if (slot !in 0 until SLOTS) return
        main.post {
            try { players[slot]?.volume = volume.coerceIn(0f, 1f) } catch (_: Exception) {}
        }
    }

    /**
     * Called when SurfaceHolder.surfaceCreated fires.
     * Surface is now valid — attach it to the player.
     */
    fun attachSurface(slot: Int, surface: android.view.Surface) {
        if (slot !in 0 until SLOTS) return
        Log.d(TAG, "attachSurface slot=$slot")
        main.post {
            surfaces[slot] = surface
            val p = players[slot] ?: return@post
            try {
                p.setVideoSurface(surface)
            } catch (e: Exception) {
                Log.w(TAG, "attachSurface setVideoSurface failed slot=$slot: $e")
                // Player crashed — rebuild it
                rebuildAndReattach(slot)
            }
        }
    }

    /**
     * Called when SurfaceHolder.surfaceDestroyed fires.
     * We ONLY clear the surface reference — we never release the player here.
     * The player keeps buffering in the background.
     */
    fun detachSurface(slot: Int) {
        if (slot !in 0 until SLOTS) return
        Log.d(TAG, "detachSurface slot=$slot")
        main.post {
            surfaces[slot] = null
            try {
                // clearVideoSurface stops rendering but keeps buffering
                players[slot]?.clearVideoSurface()
            } catch (_: Exception) {}
        }
    }

    fun release(slot: Int) {
        if (slot !in 0 until SLOTS) return
        main.post { destroyPlayer(slot) }
    }

    fun releaseAll() {
        main.post { for (i in 0 until SLOTS) destroyPlayer(i) }
    }

    // ── Internal ──────────────────────────────────────────────────────────

    /** Safely destroy a player slot */
    private fun destroyPlayer(slot: Int) {
        val p = players[slot] ?: return
        Log.d(TAG, "destroyPlayer slot=$slot")
        try { p.clearVideoSurface() } catch (_: Exception) {}
        try { p.stop() }             catch (_: Exception) {}
        try { p.release() }          catch (_: Exception) {}
        players[slot] = null
        urls[slot]    = null
        tokens[slot]  = null
    }

    /** Rebuild player and reattach surface (used after crash) */
    private fun rebuildAndReattach(slot: Int) {
        val url = urls[slot] ?: return
        val tok = tokens[slot] ?: ""
        destroyPlayer(slot)
        val p = buildPlayer(slot, url, tok)
        players[slot] = p
        val s = surfaces[slot]
        if (s != null && s.isValid) p.setVideoSurface(s)
    }

    /** Rebuild player, attach surface, and immediately play */
    private fun rebuildAndPlay(slot: Int) {
        rebuildAndReattach(slot)
        players[slot]?.apply {
            playWhenReady = true
            play()
        }
    }

    private fun buildPlayer(slot: Int, url: String, token: String): ExoPlayer {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                1_500,   // min: start after 1.5s buffered
                20_000,  // max: buffer up to 20s ahead
                800,     // start playback after 0.8s
                1_500    // resume after rebuffer with 1.5s
            )
            .build()

        val httpFactory = DefaultHttpDataSource.Factory().apply {
            setConnectTimeoutMs(10_000)
            setReadTimeoutMs(10_000)
            setAllowCrossProtocolRedirects(true)
            if (token.isNotEmpty()) {
                setDefaultRequestProperties(
                    mapOf("Authorization" to "Bearer $token")
                )
            }
        }

        val mediaItem = MediaItem.fromUri(url)
        val src = if (url.contains(".m3u8") || url.contains("hls")) {
            HlsMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        } else {
            ProgressiveMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        }

        val player = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .build()

        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) {
                Log.e(TAG, "slot=$slot player error: ${error.message}")
                // Auto-recover: rebuild on next play() call
                main.postDelayed({
                    if (players[slot] === player) {
                        Log.d(TAG, "slot=$slot auto-recovering after error")
                        rebuildAndReattach(slot)
                    }
                }, 500)
            }
        })

        player.setMediaSource(src)
        player.repeatMode    = Player.REPEAT_MODE_ONE
        player.playWhenReady = false
        player.volume        = 1f
        player.prepare()  // starts buffering immediately

        Log.d(TAG, "buildPlayer slot=$slot url=$url")
        return player
    }
}