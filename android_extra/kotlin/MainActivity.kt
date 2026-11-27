package com.jarvis.jarvis_android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var resultadoCofre: MethodChannel.Result? = null
    private val codigoSelecionarCofre = 7302

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jarvis/janela").setMethodCallHandler { call, result ->
            when (call.method) {
                "temPermissao" -> result.success(Settings.canDrawOverlays(this))
                "pedirPermissao" -> {
                    val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                    startActivity(i)
                    result.success(null)
                }
                "mostrar" -> {
                    if (!Settings.canDrawOverlays(this)) { result.success(false); return@setMethodCallHandler }
                    val i = Intent(this, FloatingService::class.java)
                        .putExtra("standby", call.argument<Boolean>("standby") ?: false)
                        .putExtra("nome", call.argument<String>("nome") ?: "Jarvis")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                    result.success(true)
                }
                "esconder" -> { stopService(Intent(this, FloatingService::class.java)); result.success(null) }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jarvis/obsidian").setMethodCallHandler { call, result ->
            when (call.method) {
                "selecionarCofre" -> {
                    if (resultadoCofre != null) {
                        result.error("ocupado", "Já existe uma seleção de pasta em andamento.", null)
                        return@setMethodCallHandler
                    }
                    resultadoCofre = result
                    val i = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                    }
                    startActivityForResult(i, codigoSelecionarCofre)
                }
                "lerMemoria" -> {
                    val uri = call.argument<String>("uri")
                    if (uri == null) result.error("uri", "Falta o endereço do cofre.", null)
                    else try { result.success(lerMemoria(Uri.parse(uri))) }
                    catch (e: Exception) { result.error("leitura", e.message, null) }
                }
                "salvarMemoria" -> {
                    val uri = call.argument<String>("uri")
                    val texto = call.argument<String>("texto")
                    if (uri == null || texto == null) result.error("dados", "Faltam dados para salvar.", null)
                    else try { salvarMemoria(Uri.parse(uri), texto); result.success(true) }
                    catch (e: Exception) { result.error("gravacao", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Android SDK")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != codigoSelecionarCofre) return
        val pendente = resultadoCofre ?: return
        resultadoCofre = null
        if (resultCode != RESULT_OK || data?.data == null) {
            pendente.success(null)
            return
        }
        val uri = data.data!!
        try {
            val flags = data.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            contentResolver.takePersistableUriPermission(uri, flags)
            pendente.success(uri.toString())
        } catch (e: Exception) {
            pendente.error("permissao", "Não consegui manter acesso à pasta escolhida.", e.message)
        }
    }

    private fun uriDaNota(tree: Uri, criar: Boolean): Uri? {
        val nome = "Assistente - Memoria.md"
        val raiz = DocumentsContract.getTreeDocumentId(tree)
        val filhos = DocumentsContract.buildChildDocumentsUriUsingTree(tree, raiz)
        contentResolver.query(
            filhos,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null, null, null
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nomeCol = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            while (cursor.moveToNext()) {
                if (cursor.getString(nomeCol) == nome) {
                    return DocumentsContract.buildDocumentUriUsingTree(tree, cursor.getString(idCol))
                }
            }
        }
        if (!criar) return null
        return DocumentsContract.createDocument(contentResolver, tree, "text/markdown", nome)
            ?: throw IllegalStateException("Não consegui criar a nota no cofre.")
    }

    private fun lerMemoria(tree: Uri): String {
        val nota = uriDaNota(tree, criar = false) ?: return ""
        return contentResolver.openInputStream(nota)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
    }

    private fun salvarMemoria(tree: Uri, texto: String) {
        val nota = uriDaNota(tree, criar = true)
            ?: throw IllegalStateException("Não consegui abrir a nota no cofre.")
        val existente = contentResolver.openInputStream(nota)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
        val notaDoApp = existente.contains("<!-- JARVIS_DATA_START") && existente.contains("JARVIS_DATA_END -->")
        if (existente.isNotBlank() && !notaDoApp) {
            throw IllegalStateException("Já existe uma nota com esse nome. Renomeie-a para preservar o conteúdo.")
        }
        contentResolver.openOutputStream(nota, "wt")?.bufferedWriter(Charsets.UTF_8)?.use { it.write(texto) }
            ?: throw IllegalStateException("Não consegui abrir a nota para escrita.")
    }
}
