package dev.freeform.freeform_lockstudio

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "freeform_studio/wallpaper")
            .setMethodCallHandler { call, result ->
                if (call.method != "setWallpaper") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val whichName = call.argument<String>("which")
                if (path == null || whichName !in listOf("lock", "home")) {
                    result.error("invalid_argument", "A wallpaper path and target are required", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val bitmap = BitmapFactory.decodeFile(File(path).absolutePath)
                            ?: throw IllegalArgumentException("Exported image could not be decoded")
                        val manager = WallpaperManager.getInstance(applicationContext)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            val which = if (whichName == "lock") WallpaperManager.FLAG_LOCK else WallpaperManager.FLAG_SYSTEM
                            manager.setBitmap(bitmap, null, true, which)
                        } else if (whichName == "home") {
                            manager.setBitmap(bitmap)
                        } else {
                            throw UnsupportedOperationException("Setting a separate lock wallpaper requires Android 7.0 or newer")
                        }
                        bitmap.recycle()
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    } catch (error: Exception) {
                        Handler(Looper.getMainLooper()).post {
                            result.error("wallpaper_failed", error.message ?: "Wallpaper could not be applied", null)
                        }
                    }
                }.start()
            }
    }
}
