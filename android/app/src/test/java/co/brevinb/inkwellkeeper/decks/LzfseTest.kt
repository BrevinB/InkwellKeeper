package co.brevinb.inkwellkeeper.decks

import org.junit.Assert.assertArrayEquals
import org.junit.Test
import java.io.File
import java.util.Base64

class LzfseTest {
    /** Vectors produced on macOS with `NSData.compressed(using: .lzfse)`: name|raw|compressed. */
    private val vectors: List<Triple<String, ByteArray, ByteArray>> by lazy {
        val text = javaClass.classLoader!!.getResource("lzfse_vectors.txt")!!.readText()
        text.lines().filter { it.isNotBlank() }.map { line ->
            val (name, raw, compressed) = line.split("|")
            Triple(name, Base64.getDecoder().decode(raw), Base64.getDecoder().decode(compressed))
        }
    }

    @Test
    fun decodesAppleLzvnBlock() {
        val (_, raw, compressed) = vectors.first { it.first == "small" }
        assertArrayEquals(raw, Lzfse.decode(compressed))
    }

    @Test
    fun decodesAppleLzfseV2Block() {
        val (_, raw, compressed) = vectors.first { it.first == "big" }
        assertArrayEquals(raw, Lzfse.decode(compressed))
    }

    @Test
    fun encoderRoundTrips() {
        for ((_, raw, _) in vectors) {
            assertArrayEquals(raw, Lzfse.decode(Lzfse.encode(raw)))
        }
        val tricky = ByteArray(5000) { (it % 7 + (it / 300)).toByte() }
        assertArrayEquals(tricky, Lzfse.decode(Lzfse.encode(tricky)))
        assertArrayEquals(ByteArray(0), Lzfse.decode(Lzfse.encode(ByteArray(0))))
    }

    /** Writes encoder output so a Swift script can confirm Apple's decoder accepts it. */
    @Test
    fun exportsEncodedVectorsForAppleCheck() {
        val dir = System.getProperty("lzfse.exportDir") ?: return
        val lines = vectors.joinToString("\n") { (name, raw, _) ->
            "$name|${Base64.getEncoder().encodeToString(raw)}|${Base64.getEncoder().encodeToString(Lzfse.encode(raw))}"
        }
        File(dir, "kotlin_encoded.txt").writeText(lines)
    }
}
