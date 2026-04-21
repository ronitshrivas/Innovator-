package com.innovation.innovator.reels

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory   // ← NEW IMPORT
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource

class ReelsPlayerPool(private val context: Context) {

    companion object {
        private const val TAG   = "ReelsPool"
        const val  SLOTS        = 3
        // ── NEW: cap how many times we rebuild after a decoder crash.
        // Without this guard, a permanently-unsupported codec profile causes
        // an infinite destroy→rebuild→crash loop that keeps the screen black.
        private const val MAX_RETRIES = 3
    }

    private val main = Handler(Looper.getMainLooper())

    private val players  = arrayOfNulls<ExoPlayer>(SLOTS)
    private val urls     = arrayOfNulls<String>(SLOTS)
    private val tokens   = arrayOfNulls<String>(SLOTS)
    private val surfaces = arrayOfNulls<Surface>(SLOTS)

    // ── NEW: per-slot retry counters
    private val retries  = IntArray(SLOTS) { 0 }

    // ── Public API ─────────────────────────────────────────────────────────

    fun prepare(slot: Int, url: String, token: String) {
        if (slot !in 0 until SLOTS) return
        main.post {
            val existing = players[slot]
            if (existing != null && urls[slot] == url) {
                Log.d(TAG, "prepare slot=$slot same url, reattaching surface")
                val s = surfaces[slot]
                if (s != null && s.isValid) existing.setVideoSurface(s)
                return@post
            }
            Log.d(TAG, "prepare slot=$slot url=$url")
            destroyPlayer(slot)
            retries[slot] = 0          // reset retry counter on fresh prepare
            urls[slot]    = url
            tokens[slot]  = token
            val p = buildPlayer(slot, url, token)
            players[slot] = p
            val s = surfaces[slot]
            if (s != null && s.isValid) {
                Log.d(TAG, "prepare slot=$slot attaching existing surface immediately")
                p.setVideoSurface(s)
            }
        }
    }

    fun play(slot: Int) {
        if (slot !in 0 until SLOTS) return
        main.post {
            var p = players[slot]
            if (p == null) {
                Log.w(TAG, "play slot=$slot no player, rebuilding")
                val url = urls[slot] ?: return@post
                val tok = tokens[slot] ?: ""
                p = buildPlayer(slot, url, tok)
                players[slot] = p
            }
            val s = surfaces[slot]
            if (s != null && s.isValid) {
                Log.d(TAG, "play slot=$slot re-attaching surface before play")
                try { p.setVideoSurface(s) } catch (e: Exception) {
                    Log.w(TAG, "play setVideoSurface failed slot=$slot: $e, rebuilding")
                    rebuildAndPlay(slot); return@post
                }
            } else {
                Log.w(TAG, "play slot=$slot NO VALID SURFACE — video will be black")
            }
            p.playWhenReady = true
            try {
                p.play()
                Log.d(TAG, "play slot=$slot OK, surface=${s?.isValid}")
            } catch (e: Exception) {
                Log.w(TAG, "play() threw slot=$slot: $e, rebuilding")
                rebuildAndPlay(slot)
            }
        }
    }

    fun pause(slot: Int) {
        if (slot !in 0 until SLOTS) return
        main.post { try { players[slot]?.pause() } catch (_: Exception) {} }
    }

    fun setVolume(slot: Int, volume: Float) {
        if (slot !in 0 until SLOTS) return
        main.post { try { players[slot]?.volume = volume.coerceIn(0f, 1f) } catch (_: Exception) {} }
    }

    fun attachSurface(slot: Int, surface: Surface) {
        if (slot !in 0 until SLOTS) return
        Log.d(TAG, "attachSurface slot=$slot valid=${surface.isValid}")
        main.post {
            surfaces[slot] = surface
            val p = players[slot]
            if (p != null && surface.isValid) {
                try {
                    p.setVideoSurface(surface)
                    Log.d(TAG, "attachSurface slot=$slot SUCCESS")
                } catch (e: Exception) {
                    Log.w(TAG, "attachSurface failed slot=$slot: $e, rebuilding")
                    rebuildAndReattach(slot)
                }
            } else {
                Log.w(TAG, "attachSurface slot=$slot player=${p != null} surface.isValid=${surface.isValid}")
            }
        }
    }

    fun detachSurface(slot: Int) {
        if (slot !in 0 until SLOTS) return
        Log.d(TAG, "detachSurface slot=$slot")
        main.post {
            surfaces[slot] = null
            try { players[slot]?.clearVideoSurface() } catch (_: Exception) {}
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

    private fun rebuildAndReattach(slot: Int) {
        val url = urls[slot] ?: return
        val tok = tokens[slot] ?: ""
        destroyPlayer(slot)
        val p = buildPlayer(slot, url, tok)
        players[slot] = p
        val s = surfaces[slot]
        if (s != null && s.isValid) p.setVideoSurface(s)
    }

    private fun rebuildAndPlay(slot: Int) {
        rebuildAndReattach(slot)
        players[slot]?.apply { playWhenReady = true; play() }
    }

    private fun buildPlayer(slot: Int, url: String, token: String): ExoPlayer {

        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(1_500, 20_000, 800, 1_500)
            .build()

        val httpFactory = DefaultHttpDataSource.Factory().apply {
            setConnectTimeoutMs(10_000)
            setReadTimeoutMs(10_000)
            setAllowCrossProtocolRedirects(true)
            if (token.isNotEmpty()) {
                setDefaultRequestProperties(mapOf("Authorization" to "Bearer $token"))
            }
        }

        // ── KEY FIX ──────────────────────────────────────────────────────
        // setEnableDecoderFallback(true) tells ExoPlayer that if the primary
        // (hardware) codec claims it cannot handle this profile/level, it must
        // silently try the next codec in the priority list — which on AOSP
        // devices is always the software decoder (c2.android.avc.decoder).
        //
        // Without this flag ExoPlayer picks the hardware decoder, it crashes
        // with ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES, and the screen
        // stays black forever because we rebuild into the same failure.
        //
        // Affected profiles seen in logs: avc1.F4001E on Xiaomi sky (23076PC4BI)
        // ─────────────────────────────────────────────────────────────────
        val renderersFactory = DefaultRenderersFactory(context)
            .setEnableDecoderFallback(true)

        val mediaItem = MediaItem.fromUri(url)
        val src = if (url.contains(".m3u8") || url.contains("hls")) {
            HlsMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        } else {
            ProgressiveMediaSource.Factory(httpFactory).createMediaSource(mediaItem)
        }

        return ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .setRenderersFactory(renderersFactory)   // ← pass factory here
            .build()
            .also { p ->
                p.addListener(object : Player.Listener {
                    override fun onPlayerError(error: PlaybackException) {
                        Log.e(TAG, "slot=$slot error: ${error.message}")

                        // ── NEW: guard against infinite rebuild loops ────
                        // ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES means
                        // *no* decoder (hardware or software) can handle this
                        // format. Rebuilding will never help — stop trying.
                        if (error.errorCode ==
                            PlaybackException.ERROR_CODE_DECODING_FORMAT_EXCEEDS_CAPABILITIES) {
                            Log.e(TAG, "slot=$slot: codec profile permanently unsupported, " +
                                    "giving up. Server should re-encode with Baseline/Main profile.")
                            return
                        }

                        retries[slot]++
                        if (retries[slot] > MAX_RETRIES) {
                            Log.e(TAG, "slot=$slot: exceeded $MAX_RETRIES retries, giving up.")
                            return
                        }

                        Log.w(TAG, "slot=$slot: retry ${retries[slot]}/$MAX_RETRIES")
                        main.postDelayed({
                            if (players[slot] === p) rebuildAndReattach(slot)
                        }, 500)
                    }
                })
                p.setMediaSource(src)
                p.repeatMode    = Player.REPEAT_MODE_ONE
                p.playWhenReady = false
                p.volume        = 1f
                p.prepare()
                Log.d(TAG, "buildPlayer slot=$slot url=$url")
            }
    }
}