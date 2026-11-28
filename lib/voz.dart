import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escolha da voz do assistente entre as vozes em português instaladas no Android.
class Voz {
  static Future<List<Map<String, String>>> listar(FlutterTts tts) async {
    final lista = <Map<String, String>>[];
    try {
      final r = await tts.getVoices;
      if (r is List) {
        for (final v in r) {
          if (v is! Map) continue;
          final nome = '${v['name']}';
          final loc = '${v['locale']}';
          if (loc.toLowerCase().replaceAll('_', '-').startsWith('pt')) {
            lista.add({'name': nome, 'locale': loc});
          }
        }
      }
    } catch (_) {}
    lista.sort((a, b) => a['name']!.compareTo(b['name']!));
    return lista;
  }

  /// Nome amigável: "Voz 2 · pt-BR · no aparelho".
  static String rotulo(int indice, Map<String, String> v) {
    final rede = v['name']!.toLowerCase().contains('network');
    return 'Voz ${indice + 1} · ${v['locale']!.replaceAll('_', '-')} · ${rede ? 'precisa de internet' : 'no aparelho'}';
  }

  /// Aplica ao [tts] o que está salvo nas configurações.
  static Future<void> aplicar(FlutterTts tts, SharedPreferences p) async {
    await tts.setLanguage('pt-BR');
    final nome = p.getString('voz_nome') ?? '';
    final loc = p.getString('voz_locale') ?? '';
    if (nome.isNotEmpty && loc.isNotEmpty) {
      try {
        await tts.setVoice({'name': nome, 'locale': loc});
      } catch (_) {}
    }
    await tts.setSpeechRate(p.getDouble('voz_velocidade') ?? 0.5);
    await tts.setPitch(p.getDouble('voz_tom') ?? 1.0);
  }
}
