package co.brevinb.inkwellkeeper.scan

import android.graphics.Bitmap
import android.graphics.Matrix
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/** On-device OCR with ML Kit (the Android counterpart of Vision's text recognizer). */
object TextScanner {
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    /** Recognized lines, the same granularity Vision's observations give the iOS matcher. */
    suspend fun lines(image: InputImage): List<String> = suspendCancellableCoroutine { cont ->
        recognizer.process(image)
            .addOnSuccessListener { text ->
                cont.resume(text.textBlocks.flatMap { block -> block.lines.map { it.text } })
            }
            .addOnFailureListener { cont.resume(emptyList()) }
    }

    suspend fun lines(bitmap: Bitmap): List<String> = lines(InputImage.fromBitmap(bitmap, 0))

    fun rotate(bitmap: Bitmap, degrees: Int): Bitmap {
        if (degrees == 0) return bitmap
        val matrix = Matrix().apply { postRotate(degrees.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    /**
     * The card-shaped center of the frame, where the on-screen guide sits. OCR on card-only
     * pixels keeps the tiny collector line legible and background text out of name matching.
     */
    fun cardCrop(bitmap: Bitmap): Bitmap {
        val aspect = 0.716f
        var w = (bitmap.width * 0.86f).toInt()
        var h = (w / aspect).toInt()
        if (h > bitmap.height * 0.92f) {
            h = (bitmap.height * 0.92f).toInt()
            w = (h * aspect).toInt()
        }
        val x = (bitmap.width - w) / 2
        val y = (bitmap.height - h) / 2
        return Bitmap.createBitmap(bitmap, x.coerceAtLeast(0), y.coerceAtLeast(0), w.coerceAtMost(bitmap.width), h.coerceAtMost(bitmap.height))
    }

    /** Downscales so the long side is at most [max] pixels. */
    fun scaled(bitmap: Bitmap, max: Int): Bitmap {
        val long = maxOf(bitmap.width, bitmap.height)
        if (long <= max) return bitmap
        val f = max.toFloat() / long
        return Bitmap.createScaledBitmap(bitmap, (bitmap.width * f).toInt(), (bitmap.height * f).toInt(), true)
    }
}
