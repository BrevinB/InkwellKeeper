package co.brevinb.inkwellkeeper.ui.onboarding

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CenterFocusWeak
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import co.brevinb.inkwellkeeper.R
import co.brevinb.inkwellkeeper.ui.components.LorcanaBackground
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlinx.coroutines.launch

/** First-launch welcome: features, then the Dreamborn import pitch. */
@Composable
fun OnboardingSheet(onFinish: (importNow: Boolean) -> Unit) {
    val pager = rememberPagerState { 2 }
    val scope = rememberCoroutineScope()
    Dialog(onDismissRequest = { onFinish(false) }, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        LorcanaBackground(Modifier.fillMaxSize()) {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                HorizontalPager(pager, Modifier.weight(1f)) { page ->
                    if (page == 0) WelcomePage() else ImportPage()
                }
                Row(Modifier.fillMaxWidth().padding(horizontal = 24.dp), horizontalArrangement = Arrangement.Center) {
                    repeat(2) { index ->
                        Box(Modifier.padding(4.dp).size(8.dp).clip(CircleShape).background(if (pager.currentPage == index) LorcanaGold else Color.Gray.copy(alpha = 0.5f)))
                    }
                }
                Row(Modifier.fillMaxWidth().padding(24.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (pager.currentPage == 1) {
                        TextButton(onClick = { onFinish(false) }) { Text("Skip for Now", color = Color.Gray) }
                        Spacer(Modifier.weight(1f))
                        LorcanaPrimaryButton(onClick = { onFinish(true) }) { Text("Import Now") }
                    } else {
                        Spacer(Modifier.weight(1f))
                        LorcanaPrimaryButton(onClick = { scope.launch { pager.animateScrollToPage(1) } }) { Text("Next") }
                    }
                }
            }
        }
    }
}

@Composable
private fun WelcomePage() {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically)) {
        Image(painterResource(R.drawable.app_icon_art), contentDescription = null, modifier = Modifier.size(110.dp).clip(RoundedCornerShape(24.dp)))
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Welcome to", style = MaterialTheme.typography.titleMedium, color = Color.Gray)
            Text("Ink Well Keeper", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = LorcanaGold)
        }
        Text("Your ultimate Disney Lorcana collection manager", style = MaterialTheme.typography.bodyLarge, color = Color.White, textAlign = TextAlign.Center)
        Text("Free • No Ads • No Tracking", style = MaterialTheme.typography.labelLarge, color = LorcanaGold)
        Text("Powerful Features", style = MaterialTheme.typography.titleMedium, color = Color.White)
        Feature(Icons.Filled.CenterFocusWeak, "Scan Cards", "Use your camera to quickly add cards to your collection")
        Feature(Icons.Filled.BarChart, "Track Value", "See real-time pricing and total collection value")
        Feature(Icons.Filled.LibraryBooks, "Browse Sets", "Explore all Lorcana sets and track your progress")
        Feature(Icons.Filled.Download, "Import Collections", "Easily import from Dreamborn.ink or CSV files")
    }
}

@Composable
private fun Feature(icon: ImageVector, title: String, description: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
        Icon(icon, null, tint = LorcanaGold, modifier = Modifier.size(28.dp))
        Column {
            Text(title, style = MaterialTheme.typography.titleSmall, color = Color.White)
            Text(description, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}

@Composable
private fun ImportPage() {
    Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically)) {
        Icon(Icons.Filled.Download, null, tint = LorcanaGold, modifier = Modifier.size(70.dp))
        Text("Import Your Collection", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = Color.White)
        Text("Already tracking cards on Dreamborn.ink?", style = MaterialTheme.typography.bodyLarge, color = Color.Gray, textAlign = TextAlign.Center)
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.Gray.copy(alpha = 0.1f)).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Step(1, "Export your collection from Dreamborn.ink as CSV")
            Step(2, "Tap 'Import Now' below")
            Step(3, "Select your exported file")
        }
        Text("You can also add cards manually or by scanning anytime!", style = MaterialTheme.typography.labelMedium, color = Color.Gray, textAlign = TextAlign.Center)
    }
}

@Composable
private fun Step(number: Int, text: String) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(28.dp).clip(CircleShape).background(LorcanaGold), contentAlignment = Alignment.Center) {
            Text("$number", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, color = Color.Black)
        }
        Text(text, style = MaterialTheme.typography.bodyMedium, color = Color.White)
    }
}
