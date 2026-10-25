package co.brevinb.inkwellkeeper.data

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Persists one root object as JSON in app storage. Saves are debounced and written atomically
 * (temp file + rename) so a crash mid-write never corrupts the previous copy.
 *
 * Encoding happens on the caller's (main) thread because the managers' model objects are
 * mutable and only touched there; only the file write moves to IO.
 */
class JsonFileStore<T>(
    private val file: File,
    private val serializer: KSerializer<T>,
    private val scope: CoroutineScope,
    private val debounceMillis: Long = 400,
) {
    private val writeLock = Mutex()
    private var pending: Job? = null

    suspend fun load(): T? = withContext(Dispatchers.IO) {
        if (!file.exists()) return@withContext null
        runCatching { json.decodeFromString(serializer, file.readText()) }.getOrNull()
    }

    /** Schedules a save of whatever [snapshot] returns once changes settle. */
    fun scheduleSave(snapshot: () -> T) {
        pending?.cancel()
        pending = scope.launch {
            delay(debounceMillis)
            write(json.encodeToString(serializer, snapshot()))
        }
    }

    /** Writes immediately (used when the app goes to the background). */
    fun saveNow(value: T) {
        pending?.cancel()
        val text = json.encodeToString(serializer, value)
        scope.launch { write(text) }
    }

    private suspend fun write(text: String) = withContext(Dispatchers.IO) {
        writeLock.withLock {
            file.parentFile?.mkdirs()
            val temp = File(file.parentFile, "${file.name}.tmp")
            temp.writeText(text)
            if (!temp.renameTo(file)) {
                file.delete()
                temp.renameTo(file)
            }
        }
    }

    companion object {
        val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
            explicitNulls = false
        }
    }
}
