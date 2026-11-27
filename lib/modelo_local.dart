import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de linguagem que roda dentro do celular, sem internet.
/// Gemma 3 de 1 bilhão de parâmetros, versão compactada (cerca de 550 MB).
/// O download é feito uma vez, com internet, e só quando o dono pedir.
class ModeloLocal {
  static const _urlModelo =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm';

  static bool _iniciado = false;
  static InferenceModel? _modelo;

  /// Chamar uma vez no começo do app.
  static Future<void> iniciar(SharedPreferences prefs) async {
    if (_iniciado) return;
    final token = prefs.getString('chave_huggingface')?.trim();
    await FlutterEdgeAi.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
      huggingFaceToken: (token == null || token.isEmpty) ? null : token,
    );
    _iniciado = true;
  }

  static Future<bool> instalado(SharedPreferences prefs) async => prefs.getBool('modelo_local_ok') ?? false;

  /// Baixa e instala o modelo. [progresso] recebe de 0 a 100.
  /// O Gemma 3 é um modelo "protegido": é preciso uma conta gratuita no Hugging Face,
  /// aceitar a licença do Gemma e criar um token de leitura.
  static Future<String?> baixar(SharedPreferences prefs, void Function(int) progresso) async {
    try {
      await iniciar(prefs);
      await FlutterEdgeAi.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(_urlModelo).withProgress((p) => progresso(p.round())).install();
      await prefs.setBool('modelo_local_ok', true);
      return null;
    } catch (e) {
      return 'Não consegui baixar o modelo. Confira a internet e o token do Hugging Face.';
    }
  }

  static Future<InferenceModel> _carregar(SharedPreferences prefs) async {
    await iniciar(prefs);
    // Limite de memória pensado em celular de 4 GB: contexto curto, CPU.
    return _modelo ??= await FlutterEdgeAi.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.cpu,
    );
  }

  /// Responde offline. Devolve null se o modelo não está instalado ou deu erro.
  static Future<String?> responder(SharedPreferences prefs,
      {required String sistema, required String pergunta}) async {
    if (!await instalado(prefs)) return null;
    try {
      final modelo = await _carregar(prefs);
      final chat = await modelo.openChat(systemInstruction: sistema);
      try {
        await chat.addQueryChunk(Message.text(text: pergunta, isUser: true));
        final r = await chat.generateChatResponse();
        final texto = (r is TextResponse) ? r.token : r.toString();
        return texto.trim().isEmpty ? null : texto.trim();
      } finally {
        await chat.close();
      }
    } catch (_) {
      _modelo = null;
      return null;
    }
  }

  static Future<void> liberar() async {
    try {
      await _modelo?.close();
    } catch (_) {}
    _modelo = null;
  }
}
