package com.openfile.openfile

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.openfile/pdf_renderer"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "renderPdfPages") {
                val path = call.argument<String>("path")
                val pageIndices = call.argument<List<Int>>("pageIndices")
                val dpiScale = (call.argument<Double>("dpiScale") ?: 2.0).toFloat()

                if (path == null) {
                    result.error("INVALID_ARGS", "Path cannot be null", null)
                    return@setMethodCallHandler
                }

                Thread {
                    try {
                        val file = File(path)
                        if (!file.exists()) {
                            runOnUiThread { result.error("FILE_NOT_FOUND", "File does not exist: $path", null) }
                            return@Thread
                        }

                        val fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                        val renderer = PdfRenderer(fileDescriptor)
                        val pageCount = renderer.pageCount
                        val outputPaths = mutableListOf<String>()

                        val pagesToRender = if (pageIndices != null && pageIndices.isNotEmpty()) {
                            pageIndices.filter { it in 0 until pageCount }
                        } else {
                            (0 until minOf(pageCount, 10)).toList()
                        }

                        val cacheDir = applicationContext.cacheDir
                        for (idx in pagesToRender) {
                            val page = renderer.openPage(idx)
                            val width = (page.width * dpiScale).toInt()
                            val height = (page.height * dpiScale).toInt()
                            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            page.close()

                            val outputFile = File(cacheDir, "pdf_page_${System.currentTimeMillis()}_$idx.jpg")
                            val out = FileOutputStream(outputFile)
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, out)
                            out.flush()
                            out.close()
                            bitmap.recycle()

                            outputPaths.add(outputFile.absolutePath)
                        }

                        renderer.close()
                        fileDescriptor.close()

                        runOnUiThread {
                            result.success(outputPaths)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("RENDER_ERROR", e.localizedMessage, null)
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
    }
}
