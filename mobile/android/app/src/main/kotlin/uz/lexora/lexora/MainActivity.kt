package uz.lexora.lexora

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import android.app.ActivityManager
import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var speechResult: MethodChannel.Result? = null
    private val speechRequestCode = 60421
    private val dictionaryInstallLock = Any()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "uz.lingoy/voice")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                } else if (speechResult != null) {
                    result.error("speech_busy", "Ovozli qidiruv ochilgan.", null)
                } else {
                    val language = if (call.argument<String>("language") == "uz-UZ") "uz-UZ" else "en-US"
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        putExtra(RecognizerIntent.EXTRA_PROMPT, "Lingoy · So‘z yoki iborani ayting")
                    }
                    speechResult = result
                    try {
                        startActivityForResult(intent, speechRequestCode)
                    } catch (error: Exception) {
                        speechResult = null
                        result.error("speech_unavailable", "Nutqni tanish xizmati ochilmadi.", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "uz.lingoy/performance")
            .setMethodCallHandler { call, result ->
                if (call.method == "installDictionary") {
                    // Stream the compressed APK asset on a worker thread instead
                    // of holding a 57 MB ByteData copy in the Dart UI isolate.
                    val expectedHash = call.argument<String>("sha256")
                    val force = call.argument<Boolean>("force") ?: false
                    val target = getDatabasePath("lexora-content-v1.db")
                    Thread {
                        val temporary = File(target.path + ".tmp")
                        try {
                          synchronized(dictionaryInstallLock) {
                            target.parentFile?.mkdirs()
                            if (!target.exists() || force) {
                                assets.open("flutter_assets/assets/dictionary.db").use { input ->
                                    temporary.outputStream().use { fileOutput ->
                                        val output = fileOutput.buffered(65536)
                                        input.copyTo(output, 65536)
                                        output.flush()
                                        fileOutput.fd.sync()
                                    }
                                }
                                if (expectedHash != null) {
                                    val digest = java.security.MessageDigest.getInstance("SHA-256")
                                    temporary.inputStream().buffered(65536).use { input ->
                                        val buffer = ByteArray(65536)
                                        var count = input.read(buffer)
                                        while (count > 0) {
                                            digest.update(buffer, 0, count)
                                            count = input.read(buffer)
                                        }
                                    }
                                    val actual = digest.digest().joinToString("") { "%02x".format(it) }
                                    check(actual == expectedHash) { "Dictionary checksum failed" }
                                }
                                // Content handles have been closed before replacement.
                                // Stale journals must never be replayed into a fresh asset.
                                for (suffix in listOf("-wal", "-shm", "-journal")) {
                                    val sidecar = File(target.path + suffix)
                                    check(!sidecar.exists() || sidecar.delete()) { "Dictionary journal cleanup failed" }
                                }
                                check(temporary.renameTo(target)) { "Dictionary install failed" }
                            }
                          }
                            runOnUiThread { result.success(target.path) }
                        } catch (error: Exception) {
                            temporary.delete()
                            runOnUiThread { result.error("dictionary_install", error.message, null) }
                        }
                    }.start()
                } else if (call.method != "budget") {
                    result.notImplemented()
                } else {
                    val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memory = ActivityManager.MemoryInfo()
                    manager.getMemoryInfo(memory)
                    val power = getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(mapOf(
                        "lowRam" to manager.isLowRamDevice,
                        "memoryMb" to memory.totalMem / (1024 * 1024),
                        "batterySaver" to power.isPowerSaveMode
                    ))
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != speechRequestCode) return
        val pending = speechResult ?: return
        speechResult = null
        if (resultCode == Activity.RESULT_OK) {
            pending.success(data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull())
        } else {
            pending.success(null)
        }
    }

    override fun onDestroy() {
        speechResult?.success(null)
        speechResult = null
        super.onDestroy()
    }
}
