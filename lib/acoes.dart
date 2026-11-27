import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'cerebro.dart';

/// Executa as ações no Android usando intents do sistema.
/// Devolve uma frase se algo deu errado, ou null se deu certo.
class Acoes {
  static const _sites = {
    'youtube': 'https://www.youtube.com',
    'whatsapp': 'https://wa.me/',
    'google': 'https://www.google.com',
    'maps': 'https://maps.google.com',
    'mapas': 'https://maps.google.com',
    'gmail': 'https://mail.google.com',
    'instagram': 'https://www.instagram.com',
  };

  static const _ajustes = {
    'wifi': 'android.settings.WIFI_SETTINGS',
    'bluetooth': 'android.settings.BLUETOOTH_SETTINGS',
    'brilho': 'android.settings.DISPLAY_SETTINGS',
    'bateria': 'android.settings.BATTERY_SAVER_SETTINGS',
    'som': 'android.settings.SOUND_SETTINGS',
    'localizacao': 'android.settings.LOCATION_SOURCE_SETTINGS',
    'rede': 'android.settings.WIRELESS_SETTINGS',
    'armazenamento': 'android.settings.INTERNAL_STORAGE_SETTINGS',
    'apps': 'android.settings.APPLICATION_SETTINGS',
    'naoperturbe': 'android.settings.ZEN_MODE_SETTINGS',
    'geral': 'android.settings.SETTINGS',
  };

  static List<AppInfo>? _cache;

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàâã]'), 'a')
      .replaceAll(RegExp(r'[éê]'), 'e')
      .replaceAll('í', 'i')
      .replaceAll(RegExp(r'[óôõ]'), 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .trim();

  /// Abre qualquer app instalado (Play Store, APK ou modificado) pelo nome falado.
  static Future<String?> _abrirApp(String falado) async {
    _cache ??= await InstalledApps.getInstalledApps(true, false);
    final alvo = _norm(falado);
    AppInfo? melhor;
    int pontos = 0;
    for (final app in _cache!) {
      final nome = _norm(app.name);
      int p = 0;
      if (nome == alvo) {
        p = 100;
      } else if (nome.contains(alvo) || alvo.contains(nome)) {
        p = 60 + (nome.length == 0 ? 0 : (40 * alvo.length ~/ nome.length.clamp(1, 1000)));
      } else {
        final palavras = alvo.split(' ').where((w) => w.length > 2);
        p = palavras.where((w) => nome.contains(w)).length * 25;
      }
      if (p > pontos) {
        pontos = p;
        melhor = app;
      }
    }
    if (melhor != null && pontos >= 25) {
      await InstalledApps.startApp(melhor.packageName);
      return null;
    }
    for (final e in _sites.entries) {
      if (alvo.contains(e.key)) {
        await launchUrl(Uri.parse(e.value), mode: LaunchMode.externalApplication);
        return null;
      }
    }
    return 'Não achei esse aplicativo no aparelho.';
  }

  static Future<String?> executar(AcaoPedida a) async {
    try {
      switch (a.tipo) {
        case 'alarme':
          await AndroidIntent(
            action: 'android.intent.action.SET_ALARM',
            arguments: {
              'android.intent.extra.alarm.HOUR': int.parse(a.dados['hora']!),
              'android.intent.extra.alarm.MINUTES': int.parse(a.dados['minuto']!),
              'android.intent.extra.alarm.SKIP_UI': true,
              'android.intent.extra.alarm.MESSAGE': 'Assistente',
            },
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          ).launch();
          return null;
        case 'timer':
          await AndroidIntent(
            action: 'android.intent.action.SET_TIMER',
            arguments: {
              'android.intent.extra.alarm.LENGTH': int.parse(a.dados['segundos']!),
              'android.intent.extra.alarm.SKIP_UI': true,
              'android.intent.extra.alarm.MESSAGE': 'Assistente',
            },
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          ).launch();
          return null;
        case 'evento':
          final ini = int.parse(a.dados['inicio']!);
          await AndroidIntent(
            action: 'android.intent.action.INSERT',
            data: 'content://com.android.calendar/events',
            arguments: {
              'title': a.dados['titulo']!,
              'beginTime': ini,
              'endTime': ini + 3600000,
            },
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          ).launch();
          return null;
        case 'ligar':
          await AndroidIntent(
            action: 'android.intent.action.DIAL',
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          ).launch();
          return null;
        case 'abrir':
          return await _abrirApp(a.dados['nome']!);
        case 'ajuste':
          await AndroidIntent(
            action: _ajustes[a.dados['qual']] ?? 'android.settings.SETTINGS',
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          ).launch();
          return null;
        case 'mapa':
          await launchUrl(
            Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(a.dados['destino']!)}'),
            mode: LaunchMode.externalApplication,
          );
          return null;
      }
    } catch (e) {
      return 'Não consegui fazer isso no aparelho.';
    }
    return null;
  }
}
