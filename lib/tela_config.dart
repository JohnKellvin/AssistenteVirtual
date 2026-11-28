import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'armazenamento_chaves.dart';
import 'memoria.dart';
import 'cofre_obsidian.dart';
import 'janela.dart';
import 'modelo_local.dart';
import 'provedores.dart';
import 'versao.dart';

class TelaConfig extends StatefulWidget {
  final SharedPreferences prefs;
  const TelaConfig({super.key, required this.prefs});

  @override
  State<TelaConfig> createState() => _TelaConfigState();
}

class _TelaConfigState extends State<TelaConfig> {
  late final TextEditingController _nome;
  late final TextEditingController _tratamento;
  late final TextEditingController _sobre;
  final Map<String, TextEditingController> _chaves = {};
  late final TextEditingController _hf;
  final Set<String> _chavesSalvas = {};
  final Set<String> _removerChaves = {};
  final Map<String, bool> _mostrarChaves = {};
  bool _chavesCarregadas = false;
  bool _salvando = false;
  String? _erroChaves;
  bool _modeloOk = false;
  int? _progresso;
  String _msgModelo = '';
  bool _janelinha = true;
  bool _indicadorMidia = true;
  bool _usarNotas = false;
  String _msgAtalho = '';
  int _tentativasSair = 0;
  bool _cofreConectado = false;
  String _msgMemoria = '';

  // Buscadores gratuitos (opcionais). Wikipedia e DuckDuckGo funcionam sem chave.
  static const _buscadores = {
    'tavily': 'Tavily (tavily.com, 1.000 buscas/mês)',
    'serper': 'Serper (serper.dev, 2.500 buscas grátis)',
    'brave': 'Brave Search (brave.com/search/api)',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    _nome = TextEditingController(text: p.getString('nome') ?? 'Jarvis');
    _tratamento = TextEditingController(
      text: p.getString('tratamento') ?? 'Senhor',
    );
    _sobre = TextEditingController(text: p.getString('sobre') ?? '');
    // Os segredos não voltam para os campos de texto ao abrir as configurações.
    _hf = TextEditingController();
    _janelinha = p.getBool('janelinha') ?? true;
    _indicadorMidia = p.getBool('indicador_midia') ?? true;
    _usarNotas = p.getBool('usar_notas') ?? false;
    _cofreConectado = (p.getString(Memoria.chaveCofre) ?? '').isNotEmpty;
    _msgMemoria = p.getString(Memoria.chaveErroCofre) ?? '';
    ModeloLocal.instalado(p).then((v) {
      if (mounted) setState(() => _modeloOk = v);
    });
    for (final pr in provedoresIA) {
      _chaves[pr.id] = TextEditingController();
    }
    for (final id in _buscadores.keys) {
      _chaves[id] = TextEditingController();
    }
    _carregarEstadoChaves();
  }

  Future<void> _carregarEstadoChaves() async {
    final salvas = <String>{};
    for (final id in ArmazenamentoChaves.ids) {
      if (await ArmazenamentoChaves.ler(id, prefs: widget.prefs) != null) {
        salvas.add(id);
      }
    }
    if (!mounted) return;
    setState(() {
      _chavesSalvas
        ..clear()
        ..addAll(salvas);
      _chavesCarregadas = true;
      if (ArmazenamentoChaves.falhaMigracao) {
        _erroChaves =
            'O Android não conseguiu proteger todas as chaves antigas. '
            'As que falharam continuam no aparelho; tente salvar novamente.';
      }
    });
  }

  Future<void> _salvar() async {
    if (!_chavesCarregadas || _salvando) return;
    setState(() => _salvando = true);
    final p = widget.prefs;
    try {
      for (final id in ArmazenamentoChaves.ids) {
        final controller = id == 'huggingface' ? _hf : _chaves[id];
        final valor = controller?.text.trim() ?? '';
        if (valor.isNotEmpty) {
          await ArmazenamentoChaves.salvar(id, valor, prefs: p);
        } else if (_removerChaves.contains(id)) {
          await ArmazenamentoChaves.apagar(id, prefs: p);
        }
      }
      await p.setString(
        'nome',
        _nome.text.trim().isEmpty ? 'Jarvis' : _nome.text.trim(),
      );
      await p.setString(
        'tratamento',
        _tratamento.text.trim().isEmpty ? 'Senhor' : _tratamento.text.trim(),
      );
      await p.setString('sobre', _sobre.text.trim());
      await p.setBool('janelinha', _janelinha);
      await p.setBool('indicador_midia', _indicadorMidia);
      await p.setBool('usar_notas', _usarNotas && _cofreConectado);
      await Memoria(p).sincronizarCofre();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _erroChaves =
              'Não consegui proteger uma das chaves. Confira o bloqueio do aparelho e tente novamente.';
          _salvando = false;
        });
      }
    }
  }

  Future<void> _baixarModelo() async {
    if (!_chavesCarregadas || _progresso != null) return;
    try {
      final digitado = _hf.text.trim();
      if (digitado.isNotEmpty) {
        await ArmazenamentoChaves.salvar(
          'huggingface',
          digitado,
          prefs: widget.prefs,
        );
        _hf.clear();
        _chavesSalvas.add('huggingface');
      }
      final token = _removerChaves.contains('huggingface')
          ? null
          : await ArmazenamentoChaves.ler(
              'huggingface',
              prefs: widget.prefs,
            );
      if (token == null) {
        setState(
          () => _msgModelo =
              'Cole um token de leitura do Hugging Face antes de baixar.',
        );
        return;
      }
      setState(() {
        _progresso = 0;
        _msgModelo = '';
      });
      final erro = await ModeloLocal.baixar(widget.prefs, token, (p) {
        if (mounted) setState(() => _progresso = p);
      });
      if (!mounted) return;
      final ok = await ModeloLocal.instalado(widget.prefs);
      setState(() {
        _progresso = null;
        _modeloOk = ok;
        _msgModelo = erro ?? 'Modelo instalado. Ele já responde sem internet.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _progresso = null;
          _msgModelo =
              'Não consegui proteger o token neste aparelho. Confira o bloqueio e tente novamente.';
        });
      }
    }
  }

  Future<void> _criarAtalho() async {
    final nome = _nome.text.trim().isEmpty ? 'Jarvis' : _nome.text.trim();
    final msg = await Janela.criarAtalho(nome);
    if (mounted) setState(() => _msgAtalho = msg);
  }

  Future<void> _apagarMemoria() async {
    final m = Memoria(widget.prefs);
    await m.esquecer();
    await m.novaConversa();
    if (mounted) setState(() => _msgModelo = 'Memória apagada.');
  }

  Future<void> _conectarCofre() async {
    try {
      final uri = await CofreObsidian.selecionar();
      if (uri == null || uri.isEmpty) return;
      await Memoria(widget.prefs).conectarCofre(uri);
      if (!mounted) return;
      setState(() {
        _sobre.text = widget.prefs.getString('sobre') ?? '';
        _cofreConectado = true;
        _msgMemoria = widget.prefs.getString(Memoria.chaveErroCofre) ??
            'Cofre conectado. As lembranças serão salvas na nota “Assistente - Memoria.md”.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _msgMemoria =
              'Não consegui conectar essa pasta. Escolha uma pasta do cofre do Obsidian.',
        );
      }
    }
  }

  Future<void> _desconectarCofre() async {
    await Memoria(widget.prefs).desconectarCofre();
    if (mounted) {
      setState(() {
        _cofreConectado = false;
        _msgMemoria =
            'Cofre desconectado. A memória existente no aparelho foi mantida.';
      });
    }
  }

  String _nomeChave(String id) {
    if (id == 'huggingface') return 'Token do Hugging Face';
    for (final provedor in provedoresIA) {
      if (provedor.id == id) return provedor.nome;
    }
    return _buscadores[id] ?? id;
  }

  Future<void> _limparChave(String id, TextEditingController controller) async {
    final temSalva = _chavesSalvas.contains(id);
    if (temSalva) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Apagar chave salva?'),
          content: Text(
            'A chave de ${_nomeChave(id)} será removida deste aparelho.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apagar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }
    setState(() {
      controller.clear();
      if (temSalva) {
        _removerChaves.add(id);
      } else {
        _removerChaves.remove(id);
      }
    });
  }

  Widget _campoChave(
    String id,
    String rotulo,
    TextEditingController controller, {
    String? dica,
  }) {
    final salva = _chavesSalvas.contains(id);
    final remover = _removerChaves.contains(id);
    final dicaEstado = remover
        ? 'Será removida ao sair desta tela.'
        : salva
            ? 'Já está salva com proteção neste aparelho. Deixe vazio para manter.'
            : dica ?? 'Cole a chave aqui. Ela será protegida neste aparelho.';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: 1,
        obscureText: !(_mostrarChaves[id] ?? false),
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [],
        keyboardType: TextInputType.visiblePassword,
        enabled: _chavesCarregadas && !_salvando,
        onChanged: (valor) {
          if (valor.isNotEmpty && _removerChaves.contains(id)) {
            setState(() => _removerChaves.remove(id));
          }
        },
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: dicaEstado,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: (_mostrarChaves[id] ?? false)
                    ? 'Ocultar o texto digitado'
                    : 'Mostrar o texto digitado',
                onPressed: !_chavesCarregadas || _salvando
                    ? null
                    : () => setState(
                          () => _mostrarChaves[id] =
                              !(_mostrarChaves[id] ?? false),
                        ),
                icon: Icon(
                  (_mostrarChaves[id] ?? false)
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
              IconButton(
                tooltip: 'Limpar ou apagar chave',
                onPressed: !_chavesCarregadas ||
                        _salvando ||
                        (!salva && controller.text.isEmpty)
                    ? null
                    : () => _limparChave(id, controller),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(
    String rotulo,
    TextEditingController c, {
    String? dica,
    int linhas = 1,
    bool segredo = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: linhas,
        obscureText: segredo,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: dica,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _titulo(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  sub,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _tentativasSair++;
        // Segunda tentativa de voltar sai mesmo se o salvamento falhar.
        if (!_chavesCarregadas || _tentativasSair > 1) {
          Navigator.of(context).pop();
          return;
        }
        await _salvar();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _campo(
            'Nome do assistente',
            _nome,
            dica: 'Ex.: Jarvis, Sexta-feira, Bia. Aparece no app, na notificação e nas respostas.',
          ),
          _campo(
            'Como ele te chama',
            _tratamento,
            dica: 'Ex.: Senhor, Senhora, ou o seu nome.',
          ),
          _campo(
            'Sobre você (opcional)',
            _sobre,
            dica: 'Quem você é e o que costuma pedir.',
            linhas: 3,
          ),
          _titulo(
            'IAs pela internet',
            'Cole as chaves. Elas são salvas ao sair desta tela. Elas ficam protegidas neste aparelho. Deixe vazio para manter uma chave salva; use a lixeira para removê-la. Confira se a cota não cobra.',
          ),
          if (!_chavesCarregadas)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          if (_erroChaves != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _erroChaves!,
                style: const TextStyle(color: Colors.amberAccent),
              ),
            ),
          for (final pr in provedoresIA)
            _campoChave(
              pr.id,
              pr.nome,
              _chaves[pr.id]!,
              dica:
                  'Chave/API em ${pr.ondeCriarChave}. Será protegida neste aparelho.',
            ),
          _titulo(
            'Buscadores gratuitos',
            'Opcionais. Sem chave ele usa a Wikipedia e o DuckDuckGo, que respondem menos.',
          ),
          for (final e in _buscadores.entries)
            _campoChave(e.key, e.value, _chaves[e.key]!),
          _titulo(
            'Modelo offline',
            'Gemma 3 de 1 bilhão de parâmetros, cerca de 584 MB. Baixa uma vez, com internet, e depois responde sem internet.',
          ),
          _campoChave(
            'huggingface',
            'Token do Hugging Face',
            _hf,
            dica:
                'Grátis. Crie conta em huggingface.co, aceite a licença do Gemma em '
                'huggingface.co/litert-community/Gemma3-1B-IT e crie um token de leitura.',
          ),
          if (_progresso != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(
                value: (_progresso! / 100).clamp(0.0, 1.0),
              ),
            ),
          OutlinedButton(
            onPressed: !_chavesCarregadas || _salvando || _progresso != null
                ? null
                : _baixarModelo,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _modeloOk
                    ? 'Baixar de novo o modelo offline'
                    : 'Baixar modelo offline',
              ),
            ),
          ),
          if (_msgModelo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _msgModelo,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          _titulo(
            'Obsidian como memória',
            'Escolha a pasta do cofre. O app cria e atualiza uma nota com os fatos lembrados e as conversas recentes. Com a opção de notas ligada, ele também procura nas suas outras notas.',
          ),
          OutlinedButton.icon(
            onPressed: _conectarCofre,
            icon: const Icon(Icons.folder_open),
            label: Text(
              _cofreConectado
                  ? 'Trocar cofre do Obsidian'
                  : 'Conectar cofre do Obsidian',
            ),
          ),
          if (_cofreConectado)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _desconectarCofre,
                child: const Text('Desconectar cofre'),
              ),
            ),
          if (_msgMemoria.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _msgMemoria,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          _titulo('Indicador, notas e ícone'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar indicador de ativo'),
            subtitle: const Text(
              'Notificação fixa com o nome do assistente e os botões Falar, Stand-by e Encerrar. Precisa da permissão de notificações.',
            ),
            value: _janelinha,
            onChanged: (v) => setState(() => _janelinha = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Estilo de player de mídia'),
            subtitle: const Text(
              'Cartão parecido com o do seu player de música, e chip na barra de status em alguns celulares. Enquanto o assistente está ativo, o botão play/pause do fone pode ir para ele.',
            ),
            value: _indicadorMidia,
            onChanged: _janelinha ? (v) => setState(() => _indicadorMidia = v) : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar minhas notas do Obsidian nas respostas'),
            subtitle: Text(
              _cofreConectado
                  ? 'Trechos das notas ligadas à pergunta são enviados à IA que responder, inclusive às da internet. Só ative se o cofre não tiver nada sensível.'
                  : 'Conecte um cofre do Obsidian acima para usar esta opção.',
            ),
            value: _usarNotas && _cofreConectado,
            onChanged: _cofreConectado ? (v) => setState(() => _usarNotas = v) : null,
          ),
          OutlinedButton.icon(
            onPressed: _criarAtalho,
            icon: const Icon(Icons.add_to_home_screen),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Criar ícone na tela inicial com esse nome'),
            ),
          ),
          if (_msgAtalho.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _msgAtalho,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
          TextButton(
            onPressed: _apagarMemoria,
            child: const Text('Apagar memória e conversa'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: !_chavesCarregadas || _salvando ? null : _salvar,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_salvando ? 'Salvando...' : 'Salvar'),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Versão $versaoApp',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _tratamento.dispose();
    _sobre.dispose();
    _hf.dispose();
    for (final controller in _chaves.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
