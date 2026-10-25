package co.brevinb.inkwellkeeper.decks

import java.io.ByteArrayOutputStream

/**
 * Minimal LZFSE codec so deck share codes interoperate with the iOS app, which compresses them
 * with `NSData.compressed(using: .lzfse)`.
 *
 * Decoding is a port of Apple's reference implementation (BSD-licensed, github.com/lzfse/lzfse)
 * covering every block type the encoder emits: uncompressed (`bvx-`), LZVN (`bvxn`, used for
 * inputs under 4 KB — i.e. almost every deck), and LZFSE v2 (`bvx2`).
 *
 * Encoding emits LZVN blocks from a small greedy matcher, which Apple's decoder reads natively.
 */
object Lzfse {
    private const val MAGIC_END = 0x24787662 // bvx$
    private const val MAGIC_RAW = 0x2d787662 // bvx-
    private const val MAGIC_V1 = 0x31787662 // bvx1
    private const val MAGIC_V2 = 0x32787662 // bvx2
    private const val MAGIC_LZVN = 0x6e787662 // bvxn

    class FormatException(message: String) : Exception(message)

    // MARK: - Decode

    fun decode(src: ByteArray): ByteArray {
        val out = ByteArrayOutputStream(src.size * 4)
        var pos = 0
        while (true) {
            if (pos + 4 > src.size) throw FormatException("truncated stream")
            when (val magic = readU32(src, pos)) {
                MAGIC_END -> return out.toByteArray()
                MAGIC_RAW -> {
                    val n = readU32(src, pos + 4)
                    if (n < 0 || pos + 8 + n > src.size) throw FormatException("bad raw block")
                    out.write(src, pos + 8, n)
                    pos += 8 + n
                }
                MAGIC_LZVN -> {
                    val nRaw = readU32(src, pos + 4)
                    val nPayload = readU32(src, pos + 8)
                    val start = pos + 12
                    if (nPayload < 0 || start + nPayload > src.size) throw FormatException("bad lzvn block")
                    out.write(lzvnDecode(src, start, start + nPayload, nRaw))
                    pos = start + nPayload
                }
                MAGIC_V2 -> pos = decodeV2Block(src, pos, out)
                MAGIC_V1 -> throw FormatException("lzfse v1 blocks are not supported")
                else -> throw FormatException("unknown block magic ${Integer.toHexString(magic)}")
            }
        }
    }

    private fun readU32(b: ByteArray, at: Int): Int =
        (b[at].toInt() and 0xff) or ((b[at + 1].toInt() and 0xff) shl 8) or
            ((b[at + 2].toInt() and 0xff) shl 16) or ((b[at + 3].toInt() and 0xff) shl 24)

    private fun readU64(b: ByteArray, at: Int): Long {
        var v = 0L
        for (i in 7 downTo 0) v = (v shl 8) or (b[at + i].toLong() and 0xff)
        return v
    }

    /** Little-endian load of up to 8 bytes; bytes past the end read as zero. */
    private fun loadLE(b: ByteArray, at: Int, count: Int): Long {
        var v = 0L
        for (i in count - 1 downTo 0) {
            val idx = at + i
            val byte = if (idx in b.indices) b[idx].toLong() and 0xff else 0L
            v = (v shl 8) or byte
        }
        return v
    }

    // MARK: LZVN

    private fun lzvnDecode(src: ByteArray, start: Int, end: Int, nRaw: Int): ByteArray {
        val dst = ByteArray(nRaw)
        var d = 0
        var s = start
        var distance = 0

        fun copyLiterals(count: Int, from: Int) {
            if (from + count > end || d + count > nRaw) throw FormatException("lzvn literal overflow")
            System.arraycopy(src, from, dst, d, count)
            d += count
        }

        fun copyMatch(count: Int) {
            if (distance <= 0 || distance > d || d + count > nRaw) throw FormatException("lzvn bad match")
            var from = d - distance
            repeat(count) { dst[d++] = dst[from++] }
        }

        while (s < end) {
            val opc = src[s].toInt() and 0xff
            val low3 = opc and 7
            when {
                opc == 0x06 -> return dst.copyOf(d) // end of stream
                opc == 0x0E || opc == 0x16 -> s += 1 // nop
                opc in 0xA0..0xBF -> { // med_d: 101LLMMM DDDDDDMM DDDDDDDD
                    val l = (opc shr 3) and 3
                    val b12 = (src[s + 1].toInt() and 0xff) or ((src[s + 2].toInt() and 0xff) shl 8)
                    val m = (((opc and 7) shl 2) or (b12 and 3)) + 3
                    distance = b12 ushr 2
                    copyLiterals(l, s + 3)
                    s += 3 + l
                    copyMatch(m)
                }
                opc == 0xE0 -> { // lrg_l
                    val l = (src[s + 1].toInt() and 0xff) + 16
                    copyLiterals(l, s + 2)
                    s += 2 + l
                }
                opc in 0xE1..0xEF -> { // sml_l
                    val l = opc and 0x0F
                    copyLiterals(l, s + 1)
                    s += 1 + l
                }
                opc == 0xF0 -> { // lrg_m
                    val m = (src[s + 1].toInt() and 0xff) + 16
                    s += 2
                    copyMatch(m)
                }
                opc in 0xF1..0xFF -> { // sml_m
                    s += 1
                    copyMatch(opc and 0x0F)
                }
                opc in 0x70..0x7F || opc in 0xD0..0xDF -> throw FormatException("lzvn undefined opcode")
                low3 == 7 -> { // lrg_d: LLMMM111 DDDDDDDD DDDDDDDD
                    val l = (opc shr 6) and 3
                    val m = ((opc shr 3) and 7) + 3
                    distance = (src[s + 1].toInt() and 0xff) or ((src[s + 2].toInt() and 0xff) shl 8)
                    copyLiterals(l, s + 3)
                    s += 3 + l
                    copyMatch(m)
                }
                low3 == 6 -> { // pre_d: LLMMM110 (rows 0x40+), reusing the previous distance
                    if (opc < 0x40) throw FormatException("lzvn undefined opcode")
                    val l = (opc shr 6) and 3
                    val m = ((opc shr 3) and 7) + 3
                    copyLiterals(l, s + 1)
                    s += 1 + l
                    copyMatch(m)
                }
                else -> { // sml_d: LLMMMDDD DDDDDDDD
                    val l = (opc shr 6) and 3
                    val m = ((opc shr 3) and 7) + 3
                    distance = ((opc and 7) shl 8) or (src[s + 1].toInt() and 0xff)
                    copyLiterals(l, s + 2)
                    s += 2 + l
                    copyMatch(m)
                }
            }
        }
        return dst.copyOf(d)
    }

    // MARK: LZFSE v2

    private const val L_SYMBOLS = 20
    private const val M_SYMBOLS = 20
    private const val D_SYMBOLS = 64
    private const val LITERAL_SYMBOLS = 256
    private const val L_STATES = 64
    private const val M_STATES = 64
    private const val D_STATES = 256
    private const val LITERAL_STATES = 1024

    private val L_EXTRA_BITS = intArrayOf(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3, 5, 8)
    private val M_EXTRA_BITS = intArrayOf(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 5, 8, 11)
    private val D_EXTRA_BITS = IntArray(D_SYMBOLS) { it / 4 }
    private val L_BASE = baseValues(L_EXTRA_BITS)
    private val M_BASE = baseValues(M_EXTRA_BITS)
    private val D_BASE = baseValues(D_EXTRA_BITS)

    /** Each symbol's base is the previous base plus the range its extra bits cover. */
    private fun baseValues(extra: IntArray): IntArray {
        val base = IntArray(extra.size)
        for (i in 1 until extra.size) base[i] = base[i - 1] + (1 shl extra[i - 1])
        return base
    }

    private val FREQ_NBITS = intArrayOf(
        2, 3, 2, 5, 2, 3, 2, 8, 2, 3, 2, 5, 2, 3, 2, 14,
        2, 3, 2, 5, 2, 3, 2, 8, 2, 3, 2, 5, 2, 3, 2, 14,
    )
    private val FREQ_VALUE = intArrayOf(
        0, 2, 1, 4, 0, 3, 1, -1, 0, 2, 1, 5, 0, 3, 1, -1,
        0, 2, 1, 6, 0, 3, 1, -1, 0, 2, 1, 7, 0, 3, 1, -1,
    )

    private fun field(v: Long, offset: Int, nbits: Int): Int = ((v ushr offset) and ((1L shl nbits) - 1)).toInt()

    /**
     * Backwards bit reader, as in `fse_in_stream64`. The initial fill is bounded by [initBound];
     * later refills may reach back to the start of the input, like the reference decoder.
     */
    private class BitStream(private val buf: ByteArray, initBound: Int, start: Int, n: Int) {
        private val bufStart = 0
        var accum: Long
        var nbits: Int
        var pos: Int = start

        init {
            if (n != 0) {
                if (pos < initBound + 8) throw FormatException("fse init out of range")
                pos -= 8
                accum = loadLE(buf, pos, 8)
                nbits = n + 64
            } else {
                if (pos < initBound + 7) throw FormatException("fse init out of range")
                pos -= 7
                accum = loadLE(buf, pos, 7)
                nbits = 56
            }
            if (nbits < 56 || nbits >= 64 || (accum ushr nbits) != 0L) throw FormatException("fse bad initial bits")
        }

        fun flush() {
            val add = (63 - nbits) and -8
            val newPos = pos - (add shr 3)
            if (newPos < bufStart) throw FormatException("fse flush out of range")
            pos = newPos
            if (add > 0) {
                val incoming = loadLE(buf, pos, 8) and ((1L shl add) - 1)
                accum = (accum shl add) or incoming
                nbits += add
            }
        }

        fun pull(n: Int): Long {
            nbits -= n
            val result = accum ushr nbits
            accum = if (nbits == 0) 0L else accum and ((1L shl nbits) - 1)
            return result
        }
    }

    private class LiteralTable(val k: IntArray, val symbol: IntArray, val delta: IntArray)

    private class ValueTable(val totalBits: IntArray, val valueBits: IntArray, val delta: IntArray, val vbase: IntArray)

    private fun buildLiteralTable(nStates: Int, freq: IntArray): LiteralTable {
        val k = IntArray(nStates)
        val symbol = IntArray(nStates)
        val delta = IntArray(nStates)
        val nClz = Integer.numberOfLeadingZeros(nStates)
        var t = 0
        var sum = 0
        for (i in freq.indices) {
            val f = freq[i]
            if (f == 0) continue
            sum += f
            if (sum > nStates) throw FormatException("fse freq overflow")
            val kk = Integer.numberOfLeadingZeros(f) - nClz
            val j0 = ((2 * nStates) shr kk) - f
            for (j in 0 until f) {
                symbol[t] = i
                if (j < j0) {
                    k[t] = kk
                    delta[t] = ((f + j) shl kk) - nStates
                } else {
                    k[t] = kk - 1
                    delta[t] = (j - j0) shl (kk - 1)
                }
                t++
            }
        }
        return LiteralTable(k, symbol, delta)
    }

    private fun buildValueTable(nStates: Int, freq: IntArray, extra: IntArray, base: IntArray): ValueTable {
        val total = IntArray(nStates)
        val vbits = IntArray(nStates)
        val delta = IntArray(nStates)
        val vbase = IntArray(nStates)
        val nClz = Integer.numberOfLeadingZeros(nStates)
        var t = 0
        var sum = 0
        for (i in freq.indices) {
            val f = freq[i]
            if (f == 0) continue
            sum += f
            if (sum > nStates) throw FormatException("fse freq overflow")
            val kk = Integer.numberOfLeadingZeros(f) - nClz
            val j0 = ((2 * nStates) shr kk) - f
            for (j in 0 until f) {
                vbits[t] = extra[i]
                vbase[t] = base[i]
                if (j < j0) {
                    total[t] = kk + extra[i]
                    delta[t] = ((f + j) shl kk) - nStates
                } else {
                    total[t] = kk - 1 + extra[i]
                    delta[t] = (j - j0) shl (kk - 1)
                }
                t++
            }
        }
        return ValueTable(total, vbits, delta, vbase)
    }

    private fun decodeV2Block(src: ByteArray, blockStart: Int, out: ByteArrayOutputStream): Int {
        if (blockStart + 32 > src.size) throw FormatException("truncated v2 header")
        val nRaw = readU32(src, blockStart + 4)
        val v0 = readU64(src, blockStart + 8)
        val v1 = readU64(src, blockStart + 16)
        val v2 = readU64(src, blockStart + 24)

        val nLiterals = field(v0, 0, 20)
        val nLiteralPayload = field(v0, 20, 20)
        val nMatches = field(v0, 40, 20)
        val literalBits = field(v0, 60, 3) - 7
        val literalState = intArrayOf(field(v1, 0, 10), field(v1, 10, 10), field(v1, 20, 10), field(v1, 30, 10))
        val nLmdPayload = field(v1, 40, 20)
        val lmdBits = field(v1, 60, 3) - 7
        val headerSize = field(v2, 0, 32)
        var lState = field(v2, 32, 10)
        var mState = field(v2, 42, 10)
        var dState = field(v2, 52, 10)

        // Frequency tables, variable-length coded after the fixed header.
        val freqs = IntArray(L_SYMBOLS + M_SYMBOLS + D_SYMBOLS + LITERAL_SYMBOLS)
        var fp = blockStart + 32
        val fend = blockStart + headerSize
        if (headerSize > 32) {
            var accum = 0L
            var accumBits = 0
            for (i in freqs.indices) {
                while (fp < fend && accumBits + 8 <= 32) {
                    accum = accum or ((src[fp].toLong() and 0xff) shl accumBits)
                    accumBits += 8
                    fp++
                }
                val b = (accum and 31).toInt()
                val n = FREQ_NBITS[b]
                freqs[i] = when (n) {
                    8 -> 8 + ((accum ushr 4) and 0xf).toInt()
                    14 -> 24 + ((accum ushr 4) and 0x3ff).toInt()
                    else -> FREQ_VALUE[b]
                }
                if (n > accumBits) throw FormatException("bad frequency table")
                accum = accum ushr n
                accumBits -= n
            }
            if (accumBits >= 8 || fp != fend) throw FormatException("bad frequency table length")
        }
        var o = 0
        val lFreq = freqs.copyOfRange(o, o + L_SYMBOLS).also { o += L_SYMBOLS }
        val mFreq = freqs.copyOfRange(o, o + M_SYMBOLS).also { o += M_SYMBOLS }
        val dFreq = freqs.copyOfRange(o, o + D_SYMBOLS).also { o += D_SYMBOLS }
        val litFreq = freqs.copyOfRange(o, o + LITERAL_SYMBOLS)

        val literalTable = buildLiteralTable(LITERAL_STATES, litFreq)
        val lTable = buildValueTable(L_STATES, lFreq, L_EXTRA_BITS, L_BASE)
        val mTable = buildValueTable(M_STATES, mFreq, M_EXTRA_BITS, M_BASE)
        val dTable = buildValueTable(D_STATES, dFreq, D_EXTRA_BITS, D_BASE)

        // Literals: read backwards from the end of the literal payload.
        val payloadStart = blockStart + headerSize
        val literalEnd = payloadStart + nLiteralPayload
        val literals = ByteArray(nLiterals + 4)
        run {
            val stream = BitStream(src, 0, literalEnd, literalBits)
            val states = literalState.copyOf()
            var i = 0
            while (i < nLiterals) {
                stream.flush()
                for (lane in 0 until 4) {
                    val st = states[lane]
                    val bits = stream.pull(literalTable.k[st]).toInt()
                    literals[i + lane] = literalTable.symbol[st].toByte()
                    states[lane] = literalTable.delta[st] + bits
                }
                i += 4
            }
        }

        // L/M/D triples: read backwards from the end of the LMD payload.
        val lmdEnd = literalEnd + nLmdPayload
        val stream = BitStream(src, literalEnd, lmdEnd, lmdBits)
        val dst = ByteArray(nRaw)
        var d = 0
        var lit = 0
        var distance = -1

        fun valueDecode(table: ValueTable, state: Int): Pair<Int, Int> {
            stream.flush()
            val bits = stream.pull(table.totalBits[state])
            val newState = table.delta[state] + (bits ushr table.valueBits[state]).toInt()
            val value = table.vbase[state] + (bits and ((1L shl table.valueBits[state]) - 1)).toInt()
            return Pair(newState, value)
        }

        repeat(nMatches) {
            val (ls, l) = valueDecode(lTable, lState); lState = ls
            val (ms, m) = valueDecode(mTable, mState); mState = ms
            val (ds, newD) = valueDecode(dTable, dState); dState = ds
            if (newD != 0) distance = newD
            if (lit + l > nLiterals || d + l + m > nRaw) throw FormatException("lzfse overflow")
            System.arraycopy(literals, lit, dst, d, l)
            lit += l
            d += l
            if (m > 0) {
                if (distance <= 0 || distance > d) throw FormatException("lzfse bad distance")
                var from = d - distance
                repeat(m) { dst[d++] = dst[from++] }
            }
        }
        out.write(dst, 0, d)
        return lmdEnd
    }

    // MARK: - Encode

    /** Compresses as a single LZVN block (Apple's decoder handles any size). */
    fun encode(input: ByteArray): ByteArray {
        val payload = lzvnEncode(input)
        val out = ByteArrayOutputStream(payload.size + 20)
        writeU32(out, MAGIC_LZVN)
        writeU32(out, input.size)
        writeU32(out, payload.size)
        out.write(payload)
        writeU32(out, MAGIC_END)
        return out.toByteArray()
    }

    private fun writeU32(out: ByteArrayOutputStream, v: Int) {
        out.write(v and 0xff)
        out.write((v ushr 8) and 0xff)
        out.write((v ushr 16) and 0xff)
        out.write((v ushr 24) and 0xff)
    }

    private const val MAX_DISTANCE = 0xFFFF
    private const val MIN_MATCH = 3

    /** Greedy hash-chain-free LZVN encoder: one candidate per 3-byte hash. */
    private fun lzvnEncode(src: ByteArray): ByteArray {
        val out = ByteArrayOutputStream(src.size + 16)
        val table = IntArray(1 shl 14) { -1 }
        var anchor = 0
        var i = 0
        var prevDistance = -1

        fun hash(at: Int): Int {
            val v = (src[at].toInt() and 0xff) or ((src[at + 1].toInt() and 0xff) shl 8) or ((src[at + 2].toInt() and 0xff) shl 16)
            return (v * -0x61c88647 ushr 18) and ((1 shl 14) - 1)
        }

        while (i + MIN_MATCH <= src.size) {
            val h = hash(i)
            val candidate = table[h]
            table[h] = i
            if (candidate >= 0 && i - candidate <= MAX_DISTANCE &&
                src[candidate] == src[i] && src[candidate + 1] == src[i + 1] && src[candidate + 2] == src[i + 2]
            ) {
                var len = MIN_MATCH
                while (i + len < src.size && src[candidate + len] == src[i + len]) len++
                val distance = i - candidate
                emitSequence(out, src, anchor, i - anchor, len, distance, prevDistance)
                prevDistance = distance
                i += len
                anchor = i
            } else {
                i++
            }
        }
        emitLiterals(out, src, anchor, src.size - anchor)
        // End of stream: eos opcode followed by 7 zero bytes.
        out.write(0x06)
        repeat(7) { out.write(0) }
        return out.toByteArray()
    }

    /** Literal-only opcodes for runs that can't ride along with a match (more than 3 bytes). */
    private fun emitLiterals(out: ByteArrayOutputStream, src: ByteArray, start: Int, count: Int) {
        var from = start
        var left = count
        while (left > 0) {
            if (left >= 16) {
                val n = minOf(left, 255 + 16)
                out.write(0xE0)
                out.write(n - 16)
                out.write(src, from, n)
                from += n
                left -= n
            } else {
                out.write(0xE0 or left)
                out.write(src, from, left)
                from += left
                left = 0
            }
        }
    }

    private fun emitSequence(
        out: ByteArrayOutputStream,
        src: ByteArray,
        literalStart: Int,
        literalCount: Int,
        matchLength: Int,
        distance: Int,
        prevDistance: Int,
    ) {
        // Match opcodes carry at most 3 literals; flush the rest first.
        var litStart = literalStart
        var litCount = literalCount
        if (litCount > 3) {
            val flushCount = litCount - (litCount and 3)
            emitLiterals(out, src, litStart, flushCount)
            litStart += flushCount
            litCount -= flushCount
        }

        // LLMMM-prefixed opcodes leave some L/M combinations undefined (rows 0x70 and 0xD0),
        // so the match length a short op can carry shrinks as literals grow.
        val maxShort = when (litCount) {
            0 -> 10
            1 -> 8
            2 -> 6
            else -> 4
        }
        var remaining = matchLength
        val first: Int
        if (distance == prevDistance && litCount >= 1) {
            first = minOf(remaining, maxShort)
            out.write((litCount shl 6) or ((first - 3) shl 3) or 6) // pre_d
        } else if (distance < 0x600) {
            first = minOf(remaining, maxShort)
            out.write((litCount shl 6) or ((first - 3) shl 3) or (distance shr 8)) // sml_d
            out.write(distance and 0xff)
        } else if (distance < 0x4000) {
            first = minOf(remaining, 34)
            val m = first - 3
            out.write(0xA0 or (litCount shl 3) or (m shr 2)) // med_d
            val b12 = (distance shl 2) or (m and 3)
            out.write(b12 and 0xff)
            out.write((b12 ushr 8) and 0xff)
        } else {
            first = minOf(remaining, maxShort)
            out.write((litCount shl 6) or ((first - 3) shl 3) or 7) // lrg_d
            out.write(distance and 0xff)
            out.write((distance ushr 8) and 0xff)
        }
        out.write(src, litStart, litCount)
        remaining -= first

        // The rest of a long match reuses the same distance via match-only opcodes.
        while (remaining > 0) {
            if (remaining >= 16) {
                val n = minOf(remaining, 255 + 16)
                out.write(0xF0)
                out.write(n - 16)
                remaining -= n
            } else {
                out.write(0xF0 or remaining)
                remaining = 0
            }
        }
    }
}
