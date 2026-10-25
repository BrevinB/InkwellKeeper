package co.brevinb.inkwellkeeper.data

import android.content.Context
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.util.UUID

/** Saves the collector's own card photos in app storage (iOS keeps them in SwiftData). */
object PhotoStore {
    private fun dir(context: Context) = File(context.filesDir, "photos").apply { mkdirs() }

    /** Copies a picked image into app storage and returns its path. */
    fun importImage(context: Context, uri: Uri): String? = runCatching {
        val file = File(dir(context), "${UUID.randomUUID()}.jpg")
        context.contentResolver.openInputStream(uri)?.use { input -> file.outputStream().use { input.copyTo(it) } }
        file.absolutePath
    }.getOrNull()

    /** A fresh file + content Uri for the camera to write into. */
    fun newCaptureTarget(context: Context): Pair<File, Uri> {
        val file = File(dir(context), "${UUID.randomUUID()}.jpg")
        return file to FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }

    fun delete(path: String) {
        runCatching { File(path).delete() }
    }
}
