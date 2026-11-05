package co.brevinb.inkwellkeeper.data

import android.util.Log
import coil3.ImageLoader
import coil3.asImage
import coil3.decode.DecodeResult
import coil3.decode.Decoder
import coil3.fetch.SourceFetchResult
import coil3.request.Options
import coil3.size.Scale
import coil3.size.Size
import coil3.size.pxOrElse
import com.radzivon.bartoshyk.avif.coder.Coder
import com.radzivon.bartoshyk.avif.coder.PreferredColorConfig
import com.radzivon.bartoshyk.avif.coder.ScaleMode
import kotlinx.coroutines.runInterruptible
import okio.ByteString.Companion.encodeUtf8

/**
 * Coil decoder for AVIF card art on Android 10–11, which have no platform AVIF support.
 * Only registered below Android 12 (see InkwellKeeperApp); newer versions decode natively.
 */
class AvifDecoder(private val source: SourceFetchResult, private val options: Options) : Decoder {

    override suspend fun decode(): DecodeResult? = runInterruptible {
        try {
            val bytes = source.source.source().readByteArray()
            if (options.size == Size.ORIGINAL) {
                DecodeResult(coder.decode(bytes, PreferredColorConfig.RGBA_8888).asImage(), isSampled = false)
            } else {
                val bitmap = coder.decodeSampled(
                    byteArray = bytes,
                    scaledWidth = options.size.width.pxOrElse { 0 },
                    scaledHeight = options.size.height.pxOrElse { 0 },
                    preferredColorConfig = PreferredColorConfig.RGBA_8888,
                    scaleMode = if (options.scale == Scale.FILL) ScaleMode.FILL else ScaleMode.FIT,
                )
                DecodeResult(bitmap.asImage(), isSampled = true)
            }
        } catch (e: Exception) {
            Log.w("AvifDecoder", "AVIF decode failed", e)
            null
        }
    }

    class Factory : Decoder.Factory {
        override fun create(result: SourceFetchResult, options: Options, imageLoader: ImageLoader): Decoder? {
            val source = result.source.source()
            return if (BRANDS.any { source.rangeEquals(4, it) }) AvifDecoder(result, options) else null
        }
    }

    private companion object {
        val coder by lazy { Coder() }
        /** ISO-BMFF `ftyp` brands at byte offset 4 that identify AVIF files. */
        val BRANDS = listOf("ftypavif", "ftypavis", "ftypmif1", "ftypmsf1").map { it.encodeUtf8() }
    }
}
