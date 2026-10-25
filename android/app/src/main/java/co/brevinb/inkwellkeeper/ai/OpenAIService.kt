package co.brevinb.inkwellkeeper.ai

import co.brevinb.inkwellkeeper.BuildConfig
import co.brevinb.inkwellkeeper.billing.SubscriptionManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.isActive
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

data class ChatMessage(val role: String, val content: String)

/** [userFacing] errors (limit reached, subscription not verified) are shown instead of the generic failure text. */
class OpenAIException(message: String, val userFacing: Boolean = false) : Exception(message)

/** Which AI feature is asking; the proxy picks the model, temperature and daily limit for it. */
enum class AIFeature(val wireName: String, val directModel: String, val directTemperature: Double?) {
    RULES("rules", "gpt-4o", 0.3),
    DECK("deck", "gpt-4o-mini", null),
}

/**
 * Streaming chat completions, mirroring the iOS OpenAIService.
 *
 * Release builds go through the AI proxy (`ai.proxyUrl`), which holds the OpenAI key, checks the
 * RevenueCat Pro entitlement and enforces the daily limits server-side. Debug builds without a
 * proxy can call OpenAI directly with a key from the git-ignored `local.properties`.
 */
object OpenAIService {
    private const val OPENAI_ENDPOINT = "https://api.openai.com/v1/chat/completions"

    private val client = OkHttpClient.Builder().readTimeout(120, TimeUnit.SECONDS).build()
    private val json = Json { ignoreUnknownKeys = true }

    private val usesProxy: Boolean get() = BuildConfig.AI_PROXY_URL.isNotBlank()

    val isConfigured: Boolean get() = usesProxy || BuildConfig.OPENAI_API_KEY.isNotBlank()

    fun stream(messages: List<ChatMessage>, feature: AIFeature): Flow<String> = flow {
        if (!isConfigured) throw OpenAIException("Service not available. Please try again later.")
        val wireMessages = JsonArray(messages.map { buildJsonObject { put("role", it.role); put("content", it.content) } })
        val request = if (usesProxy) {
            val userId = SubscriptionManager.appUserId ?: throw OpenAIException("Your Pro subscription couldn't be verified. Try Restore Purchases.", userFacing = true)
            Request.Builder().url(BuildConfig.AI_PROXY_URL)
                .header("X-App-User-Id", userId)
                .post(buildJsonObject { put("feature", feature.wireName); put("messages", wireMessages) }.toString().toRequestBody(jsonMedia))
                .build()
        } else {
            val body = buildJsonObject {
                put("model", feature.directModel)
                put("stream", true)
                put("messages", wireMessages)
                // Reasoning models reject non-default temperatures; only gpt-4 accepts it.
                feature.directTemperature?.let { if (feature.directModel.startsWith("gpt-4")) put("temperature", it) }
            }
            Request.Builder().url(OPENAI_ENDPOINT)
                .header("Authorization", "Bearer ${BuildConfig.OPENAI_API_KEY}")
                .post(body.toString().toRequestBody(jsonMedia))
                .build()
        }
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw OpenAIException(errorMessage(response.code), userFacing = response.code in setOf(401, 403, 429))
            val source = response.body?.source() ?: throw OpenAIException("Invalid response from OpenAI API.")
            while (currentCoroutineContext().isActive) {
                val line = source.readUtf8Line() ?: break
                if (!line.startsWith("data: ")) continue
                val data = line.removePrefix("data: ")
                if (data == "[DONE]") break
                val content = runCatching {
                    (json.parseToJsonElement(data).jsonObject["choices"]?.jsonArray?.firstOrNull()?.jsonObject
                        ?.get("delta") as? JsonObject)?.get("content")?.let { (it as? JsonPrimitive)?.takeIf { p -> p.isString }?.content }
                }.getOrNull()
                if (!content.isNullOrEmpty()) emit(content)
            }
        }
    }.flowOn(Dispatchers.IO)

    /** Non-streaming convenience: collects the whole reply. */
    suspend fun complete(messages: List<ChatMessage>, feature: AIFeature): String {
        val sb = StringBuilder()
        stream(messages, feature).collect { sb.append(it) }
        return sb.toString()
    }

    private val jsonMedia = "application/json".toMediaType()

    /** The proxy answers 401 without an active entitlement and 429 once today's limit is used. */
    private fun errorMessage(code: Int): String = when (code) {
        401, 403 -> "Your Pro subscription couldn't be verified. Try Restore Purchases."
        429 -> "You've reached today's AI limit. It resets tomorrow."
        else -> "The AI service returned an error (HTTP $code). Please try again."
    }

}
