package com.jarvis.jarvis_android

import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        // O serviço do indicador usa este canal para avisar o app (stand-by, encerrar).
        var canalJanela: MethodChannel? = null
        var acaoPendente: String? = null
    }

    private var resultadoCofre: MethodChannel.Result? = null
    private val codigoSelecionarCofre = 7302

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        acaoPendente = intent?.getStringExtra("acao")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val acao = intent.getStringExtra("acao") ?: return
        intent.removeExtra("acao")
        val canal = canalJanela
        if (canal != null) canal.invokeMethod("acao", acao) else acaoPendente = acao
    }

    override fun onDestroy() {
        canalJanela = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val janela = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jarvis/janela")
        canalJanela = janela
        janela.setMethodCallHandler { call, result ->
            when (call.method) {
                "mostrar" -> {
                    val i = Intent(this, IndicadorService::class.java)
                        .putExtra("nome", call.argument<String>("nome") ?: "Assistente")
                        .putExtra("estado", call.argument<String>("estado") ?: "ativo")
                        .putExtra("midia", call.argument<Boolean>("midia") ?: true)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "esconder" -> {
                    stopService(Intent(this, IndicadorService::class.java))
                    result.success(null)
                }
                "acaoPendente" -> {
                    val a = acaoPendente
                    acaoPendente = null
                    result.success(a)
                }
                "criarAtalho" -> result.success(criarAtalho(call.argument<String>("nome") ?: "Assistente"))
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
                "buscarNotas" -> {
                    val uri = call.argument<String>("uri")
                    val termos = call.argument<List<String>>("termos") ?: emptyList()
                    val max = call.argument<Int>("max") ?: 3
                    if (uri == null || termos.isEmpty()) {
                        result.success(emptyList<Map<String, String>>())
                        return@setMethodCallHandler
                    }
                    // Varrer o cofre é lento: roda fora da tela principal.
                    Thread {
                        val achados = try {
                            buscarNotas(Uri.parse(uri), termos, max)
                        } catch (e: Exception) {
                            emptyList()
                        }
                        runOnUiThread { result.success(achados) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    // O Android não deixa trocar o nome do ícone principal na hora. O que dá para fazer é
    // pedir um atalho fixo na tela inicial, com o nome escolhido.
    private fun criarAtalho(nome: String): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "Este Android não permite criar atalhos assim."
        val sm = getSystemService(ShortcutManager::class.java) ?: return "Não consegui falar com o gerenciador de atalhos."
        if (!sm.isRequestPinShortcutSupported) return "O seu launcher não aceita atalhos fixos."
        val abrir = packageManager.getLaunchIntentForPackage(packageName) ?: return "Não achei a tela inicial do app."
        abrir.action = Intent.ACTION_MAIN
        val info = ShortcutInfo.Builder(this, "assistente_" + nome.lowercase().hashCode())
            .setShortLabel(nome)
            .setLongLabel(nome)
            .setIcon(Icon.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(abrir)
            .build()
        sm.requestPinShortcut(info, null)
        return "Pedi ao Android para criar o atalho “$nome”. Confirme na tela."
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

    private fun semAcento(s: String): String =
        java.text.Normalizer.normalize(s.lowercase(), java.text.Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "")

    // Procura nas notas .md do cofre (só leitura). Pontua por termos encontrados e devolve
    // os melhores trechos. Ignora pastas ocultas (como .obsidian) e a nota de memória do app.
    private fun buscarNotas(tree: Uri, termos: List<String>, max: Int): List<Map<String, String>> {
        val alvos = termos.map { semAcento(it) }.filter { it.length >= 3 }
        if (alvos.isEmpty()) return emptyList()
        val limiteTempo = System.currentTimeMillis() + 4000
        var lidos = 0
        val achados = mutableListOf<Triple<Int, String, String>>()

        fun varrer(docId: String, nivel: Int) {
            if (nivel > 6) return
            val filhos = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
            val colunas = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
                DocumentsContract.Document.COLUMN_SIZE
            )
            contentResolver.query(filhos, colunas, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    if (System.currentTimeMillis() > limiteTempo || lidos >= 400) return
                    val id = c.getString(0)
                    val nome = c.getString(1) ?: continue
                    val mime = c.getString(2) ?: ""
                    val tamanho = c.getLong(3)
                    if (nome.startsWith(".")) continue
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        varrer(id, nivel + 1)
                        continue
                    }
                    if (!nome.endsWith(".md", true) || nome == "Assistente - Memoria.md") continue
                    if (tamanho <= 0 || tamanho > 200_000) continue
                    lidos++
                    val texto = contentResolver
                        .openInputStream(DocumentsContract.buildDocumentUriUsingTree(tree, id))
                        ?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: continue
                    val limpo = semAcento(texto)
                    val titulo = nome.removeSuffix(".md")
                    val tituloLimpo = semAcento(titulo)
                    var pontos = 0
                    var primeiro = -1
                    for (a in alvos) {
                        var idx = limpo.indexOf(a)
                        var vezes = 0
                        if (idx >= 0 && primeiro < 0) primeiro = idx
                        while (idx >= 0 && vezes < 5) {
                            vezes++
                            idx = limpo.indexOf(a, idx + a.length)
                        }
                        pontos += vezes
                        if (tituloLimpo.contains(a)) pontos += 5
                    }
                    if (pontos > 0) {
                        val ini = (primeiro - 150).coerceAtLeast(0).coerceAtMost(texto.length)
                        val fim = (ini + 700).coerceAtMost(texto.length)
                        val trecho = texto.substring(ini, fim).replace(Regex("\\s+"), " ").trim()
                        achados.add(Triple(pontos, titulo, trecho))
                    }
                }
            }
        }

        varrer(DocumentsContract.getTreeDocumentId(tree), 0)
        return achados.sortedByDescending { it.first }.take(max)
            .map { mapOf("titulo" to it.second, "trecho" to it.third) }
    }
}
