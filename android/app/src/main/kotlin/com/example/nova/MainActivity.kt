package com.example.nova

import android.app.PictureInPictureParams
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "skolar/pip"
    private var pipEnabledForBreak = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setPipEnabled" -> {
                    pipEnabledForBreak = call.argument<Boolean>("enabled") ?: false
                    updateAutoPipParams()
                    result.success(true)
                }
                "enterPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            enterPictureInPictureMode(params)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "vibrate" -> {
                    val duration = (call.argument<Int>("duration") ?: 10).toLong()
                    val amplitude = call.argument<Int>("amplitude") ?: 50
                    vibrateDevice(duration, amplitude)
                    result.success(true)
                }
                "hapticSnap" -> {
                    val duration = (call.argument<Int>("duration") ?: 10).toLong()
                    val amplitude = call.argument<Int>("amplitude") ?: 50
                    vibrateDevice(duration, amplitude, useTick = true)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun vibrateDevice(durationMs: Long, amplitude: Int = 50, useTick: Boolean = false) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                val vibrator = vibratorManager?.defaultVibrator
                if (vibrator != null && vibrator.hasVibrator()) {
                    if (useTick && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        try {
                            val effect = VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
                            vibrator.vibrate(effect)
                            return
                        } catch (e: Exception) {
                            // fallback
                        }
                    }
                    val effect = VibrationEffect.createOneShot(durationMs, amplitude.coerceIn(1, 255))
                    vibrator.vibrate(effect)
                }
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                if (vibrator != null && vibrator.hasVibrator()) {
                    if (useTick && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        try {
                            val effect = VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
                            vibrator.vibrate(effect)
                            return
                        } catch (e: Exception) {
                            // fallback
                        }
                    }
                    val effect = VibrationEffect.createOneShot(durationMs, amplitude.coerceIn(1, 255))
                    vibrator.vibrate(effect)
                }
            } else {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(durationMs)
            }
        } catch (e: Exception) {
            // Graceful fallback
        }
    }

    private fun updateAutoPipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .setAutoEnterEnabled(pipEnabledForBreak)
                    .build()
                setPictureInPictureParams(params)
            } catch (e: Exception) {
                // Graceful fallback
            }
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipEnabledForBreak && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val params = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build()
                enterPictureInPictureMode(params)
            } catch (e: Exception) {
                // Graceful fallback
            }
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).invokeMethod("onPipChanged", isInPictureInPictureMode)
        }
    }
}
