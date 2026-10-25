package co.brevinb.inkwellkeeper.ui.scan

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.scan.CardRecognizer
import co.brevinb.inkwellkeeper.scan.ScanSession
import co.brevinb.inkwellkeeper.scan.ScannedCardEntry
import co.brevinb.inkwellkeeper.scan.TextScanner
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.AsyncPriceView
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.PriceStyle
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import com.google.mlkit.vision.common.InputImage
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

/**
 * Multi-scan: point at a card, tap the shutter (or turn on Auto), and recognized cards pile up
 * in the tray until you review and add them. Matches the iOS Scan tab.
 */
@Composable
fun ScanScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val context = LocalContext.current
    val session = app.scan
    var hasPermission by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED)
    }
    var denied by remember { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        hasPermission = granted
        denied = !granted
    }
    LaunchedEffect(Unit) { if (!hasPermission) permission.launch(Manifest.permission.CAMERA) }

    var showingReview by remember { mutableStateOf(false) }
    var correcting by remember { mutableStateOf(false) }
    var reveal by remember { mutableStateOf<ScannedCardEntry?>(null) }

    LaunchedEffect(session.scanEventId) {
        val entry = session.lastEntry ?: return@LaunchedEffect
        reveal = entry
        delay(2500)
        reveal = null
    }

    Box(Modifier.fillMaxSize().background(Color.Black)) {
        if (hasPermission) {
            CameraLayer(session, paused = showingReview || correcting || session.pendingSetChoices != null)
        } else {
            CameraUnavailable(
                denied = denied,
                onManualAdd = { nav.navigate(Routes.search()) },
                onOpenSettings = {
                    context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
                },
            )
        }

        Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Spacer(Modifier.weight(1f))
                ScanToggle("Auto", Icons.Filled.Bolt, session.isAutoScanEnabled) { session.isAutoScanEnabled = !session.isAutoScanEnabled }
                ScanToggle("Foil", Icons.Filled.AutoAwesome, session.isFoilMode) { session.isFoilMode = !session.isFoilMode }
            }
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                if (hasPermission) ScanReticle(session.isProcessing, session.isAutoScanEnabled)
                if (session.isProcessing) {
                    Row(
                        Modifier.clip(RoundedCornerShape(16.dp)).background(Color.Black.copy(alpha = 0.6f)).padding(horizontal = 24.dp, vertical = 16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
                        Text("  Recognizing…", style = MaterialTheme.typography.titleMedium, color = Color.White)
                    }
                } else {
                    session.status?.let {
                        Text(it, color = Color.White, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 24.dp)
                            .clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.6f)).padding(horizontal = 14.dp, vertical = 6.dp))
                    }
                }
                androidx.compose.animation.AnimatedVisibility(
                    reveal != null,
                    modifier = Modifier.align(Alignment.BottomEnd).padding(12.dp),
                    enter = slideInHorizontally { it } + fadeIn(),
                    exit = slideOutHorizontally { it } + fadeOut(),
                ) {
                    reveal?.let { entry ->
                        RevealChip(entry, onCorrect = { reveal = null; correcting = true }, onUndo = { session.undoLast(); reveal = null })
                    }
                }
            }
            ControlBar(session, onManualAdd = { nav.navigate(Routes.search()) }, onReview = { showingReview = true })
        }
    }

    if (showingReview) ScanReviewSheet(session) { showingReview = false }
    if (correcting) CardPickerSheet(title = "Correct Card", onDismiss = { correcting = false }) { session.replaceLast(it); correcting = false }
    session.pendingSetChoices?.let { choices -> SetPickerSheet(choices, onSelect = { session.resolveSetChoice(it) }, onCancel = { session.pendingSetChoices = null }) }
}

/** Preview + still capture + (in Auto) throttled frame analysis. */
@Composable
private fun CameraLayer(session: ScanSession, paused: Boolean) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val haptics = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val previewView = remember { PreviewView(context).apply { scaleType = PreviewView.ScaleType.FILL_CENTER } }
    val imageCapture = remember { ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build() }
    val analysis = remember { ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build() }
    val executor = remember { Executors.newSingleThreadExecutor() }
    val currentPaused by rememberUpdatedState(paused)
    val auto = remember { AutoScanState() }

    fun handle(resolution: CardRecognizer.Resolution?) {
        when (resolution) {
            is CardRecognizer.Resolution.Found -> {
                session.add(resolution.card)
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
            }
            is CardRecognizer.Resolution.ChooseSet -> session.pendingSetChoices = resolution.choices
            null -> {}
        }
    }

    DisposableEffect(lifecycleOwner) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val preview = Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider }
            analysis.setAnalyzer(executor) { proxy -> analyzeFrame(proxy, session, auto, { currentPaused }, scope, ::handle) }
            runCatching {
                provider.unbindAll()
                provider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, imageCapture, analysis)
            }
        }, ContextCompat.getMainExecutor(context))
        onDispose {
            runCatching { providerFuture.get().unbindAll() }
            executor.shutdown()
        }
    }

    // Manual capture requests from the shutter button.
    LaunchedEffect(session) {
        captureRequests[session] = {
            if (!session.isProcessing) {
                session.isProcessing = true
                imageCapture.takePicture(executor, object : ImageCapture.OnImageCapturedCallback() {
                    override fun onCaptureSuccess(image: ImageProxy) {
                        val bitmap = TextScanner.rotate(image.toBitmap(), image.imageInfo.rotationDegrees)
                        image.close()
                        scope.launch {
                            val resolution = withContext(Dispatchers.Default) { recognizeStill(bitmap) }
                            session.isProcessing = false
                            if (resolution == null) flashStatus(session, "Card text not readable. Try better lighting or focus.", scope)
                            handle(resolution)
                        }
                    }

                    override fun onError(exception: ImageCaptureException) {
                        scope.launch {
                            session.isProcessing = false
                            flashStatus(session, "Couldn't capture photo", scope)
                        }
                    }
                })
            }
        }
    }

    AndroidView({ previewView }, Modifier.fillMaxSize())
}

/** Hooks the shutter button (in the control bar) to the bound camera. */
private val captureRequests = mutableMapOf<ScanSession, () -> Unit>()

private class AutoScanState {
    var lastAnalysis = 0L
    var armed = true
    var emptyStreak = 0
    var lastAddedName: String? = null
}

private fun recognizer(): CardRecognizer? =
    if (!SetsDataManager.isDataLoaded) null
    else CardRecognizer(SetsDataManager.getAllCards(), SetsDataManager.sets) { SetsDataManager.searchCards(it) }

/** Card-shaped crop first (keeps the collector line legible), full frame as a fallback. */
private suspend fun recognizeStill(bitmap: android.graphics.Bitmap): CardRecognizer.Resolution? {
    val recognizer = recognizer() ?: return null
    val cropTexts = TextScanner.lines(TextScanner.scaled(TextScanner.cardCrop(bitmap), 1600))
    recognizer.recognize(cropTexts)?.let { return it }
    val fullTexts = TextScanner.lines(TextScanner.scaled(bitmap, 1600))
    return recognizer.recognize(fullTexts)
}

/**
 * Auto mode: OCR a frame about every 0.7s. A card is added once, then auto re-arms only after
 * a few frames with no readable card — i.e. when the card leaves the frame, like iOS.
 */
private fun analyzeFrame(
    proxy: ImageProxy,
    session: ScanSession,
    auto: AutoScanState,
    isPaused: () -> Boolean,
    scope: CoroutineScope,
    onResult: (CardRecognizer.Resolution?) -> Unit,
) {
    val now = System.currentTimeMillis()
    val media = proxy.image
    if (!session.isAutoScanEnabled || isPaused() || session.isProcessing || media == null || now - auto.lastAnalysis < 700) {
        proxy.close()
        return
    }
    auto.lastAnalysis = now
    val input = InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees)
    scope.launch {
        val texts = TextScanner.lines(input)
        proxy.close()
        val recognizer = recognizer() ?: return@launch
        val resolution = withContext(Dispatchers.Default) { recognizer.recognize(texts) }
        if (resolution == null) {
            auto.emptyStreak++
            if (auto.emptyStreak >= 2) {
                auto.armed = true
                auto.lastAddedName = null
            }
            return@launch
        }
        auto.emptyStreak = 0
        val name = when (resolution) {
            is CardRecognizer.Resolution.Found -> resolution.card.name
            is CardRecognizer.Resolution.ChooseSet -> resolution.choices.first().name
        }
        // A different card replacing the last one re-arms immediately.
        if (!auto.armed && name == auto.lastAddedName) return@launch
        auto.armed = false
        auto.lastAddedName = name
        onResult(resolution)
    }
}

private fun flashStatus(session: ScanSession, message: String, scope: CoroutineScope) {
    session.status = message
    scope.launch {
        delay(2000)
        if (session.status == message) session.status = null
    }
}

@Composable
private fun ScanReticle(processing: Boolean, auto: Boolean) {
    val color = when {
        processing -> LorcanaGold
        auto -> SystemColors.green
        else -> Color.White
    }
    Canvas(Modifier.fillMaxWidth(0.72f).aspectRatio(0.716f)) {
        val corner = 18.dp.toPx()
        val len = size.minDimension * 0.18f
        val stroke = 4.dp.toPx()
        drawRoundRect(color.copy(alpha = 0.25f), cornerRadius = CornerRadius(corner), style = Stroke(1.5.dp.toPx()))
        // Corner brackets.
        listOf(Offset(0f, 0f) to Offset(1f, 1f), Offset(size.width, 0f) to Offset(-1f, 1f), Offset(0f, size.height) to Offset(1f, -1f), Offset(size.width, size.height) to Offset(-1f, -1f)).forEach { (o, d) ->
            drawLine(color, o, Offset(o.x + d.x * len, o.y), stroke)
            drawLine(color, o, Offset(o.x, o.y + d.y * len), stroke)
        }
    }
}

@Composable
private fun ScanToggle(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, active: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(if (active) LorcanaGold else Color.Black.copy(alpha = 0.55f))
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val tint = if (active) Color.Black else Color.White
        Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
        Text(" $label", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold, color = tint)
    }
}

@Composable
private fun ControlBar(session: ScanSession, onManualAdd: () -> Unit, onReview: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(12.dp).clip(RoundedCornerShape(28.dp)).background(Color.Black.copy(alpha = 0.6f)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        if (session.scannedCards.isNotEmpty()) {
            Row(Modifier.fillMaxWidth().clickable(onClick = onReview), verticalAlignment = Alignment.CenterVertically) {
                Row(horizontalArrangement = Arrangement.spacedBy((-10).dp)) {
                    session.scannedCards.takeLast(5).reversed().forEach { entry ->
                        CardImage(entry.card, Modifier.size(30.dp, 42.dp).clip(RoundedCornerShape(4.dp)).border(0.5.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(4.dp)))
                    }
                }
                Column(Modifier.padding(start = 12.dp).weight(1f)) {
                    Text("${session.totalCount} card${if (session.totalCount == 1) "" else "s"}", fontWeight = FontWeight.Bold, color = Color.White)
                    HaulValue(session)
                }
                Text("Review", fontWeight = FontWeight.Bold, color = LorcanaGold)
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = LorcanaGold)
            }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            SecondaryButton("Add", Icons.Filled.Add, onManualAdd)
            Spacer(Modifier.weight(1f))
            Box(
                Modifier.size(76.dp).clip(CircleShape).background(if (session.isAutoScanEnabled) SystemColors.green else LorcanaGold)
                    .clickable(enabled = !session.isProcessing) { captureRequests[session]?.invoke() },
                contentAlignment = Alignment.Center,
            ) {
                if (session.isProcessing) CircularProgressIndicator(color = Color.White)
                else {
                    Box(Modifier.size(64.dp).border(4.dp, Color.White, CircleShape))
                    if (session.isAutoScanEnabled) Icon(Icons.Filled.Bolt, contentDescription = null, tint = Color.White)
                }
            }
            Spacer(Modifier.weight(1f))
            SecondaryButton("Review", Icons.Filled.CheckCircle, onReview)
        }
    }
}

@Composable
private fun SecondaryButton(title: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Column(Modifier.clickable(onClick = onClick), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(48.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.15f)), contentAlignment = Alignment.Center) {
            Icon(icon, contentDescription = title, tint = Color.White)
        }
        Text(title, style = MaterialTheme.typography.labelSmall, color = Color.White)
    }
}

@Composable
private fun HaulValue(session: ScanSession) {
    var total by remember { mutableStateOf<Double?>(null) }
    val key = session.scannedCards.joinToString { "${it.id}x${it.quantity}" }
    LaunchedEffect(key) {
        total = session.scannedCards.toList().sumOf { e -> (PricingService.getMarketPrice(e.card) ?: 0.0) * e.quantity }
    }
    Text(total?.let { PricingService.formatPrice(it) } ?: "—", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
}

@Composable
private fun RevealChip(entry: ScannedCardEntry, onCorrect: () -> Unit, onUndo: () -> Unit) {
    Row(
        Modifier.widthIn(max = 300.dp).clip(RoundedCornerShape(14.dp)).background(Color.Black.copy(alpha = 0.75f))
            .border(1.dp, LorcanaGold.copy(alpha = 0.35f), RoundedCornerShape(14.dp)).clickable(onClick = onCorrect).padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box {
            CardImage(entry.card, Modifier.size(44.dp, 62.dp).clip(RoundedCornerShape(5.dp)))
            if (entry.variant == CardVariant.FOIL) Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(14.dp).align(Alignment.TopEnd).offset(4.dp, (-4).dp))
        }
        Column(Modifier.weight(1f, fill = false)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.CheckCircle, null, tint = SystemColors.green, modifier = Modifier.size(14.dp))
                Text(" ${entry.card.name}", fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            AsyncPriceView(entry.card, PriceStyle.INLINE)
            Text("Tap to correct", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
        Icon(Icons.Filled.Undo, contentDescription = "Undo scan", tint = Color.White, modifier = Modifier.clickable(onClick = onUndo).padding(4.dp))
    }
}

@Composable
private fun CameraUnavailable(denied: Boolean, onManualAdd: () -> Unit, onOpenSettings: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically)) {
        Icon(Icons.Filled.CameraAlt, null, tint = Color.Gray, modifier = Modifier.size(50.dp))
        Text(if (denied) "Camera access is needed to scan cards." else "Waiting for camera access…", style = MaterialTheme.typography.titleLarge, color = Color.White, textAlign = TextAlign.Center)
        if (denied) LorcanaPrimaryButton(onClick = onOpenSettings) { Text("Open Settings") }
        LorcanaPrimaryButton(onClick = onManualAdd) {
            Icon(Icons.Filled.Add, null)
            Spacer(Modifier.width(6.dp))
            Text("Manual Add Card")
        }
    }
}
