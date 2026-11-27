# Jarvis para Android, beta 2.1

Assistente de voz em Flutter para Android: esfera, voz em português, janelinha flutuante,
stand-by, memória, pesquisa com IAs gratuitas e modelo offline dentro do celular.
Nome do assistente e tratamento ("Senhor") configuráveis.

## 1. Gerar e baixar o APK

1. Cada envio para a branch `main` inicia o fluxo **Gerar APK**.
2. Para baixar um build de teste, abra **Actions**, selecione a execução e baixe `jarvis-apk` em **Artifacts**.
3. Depois que a compilação passar, envie a tag `v2.1.0-beta.1` para publicar a versão Beta 2.1:

   ```bash
   git tag v2.1.0-beta.1
   git push origin v2.1.0-beta.1
   ```

   O fluxo compila o APK e o anexa à pré-release **Assistente Beta 2.1** em **Releases**.
4. Instale o `app-release.apk` (o Android pode pedir para liberar fontes desconhecidas).

Se a compilação falhar, abra o passo que ficou vermelho e envie o texto do erro.

## 2. Primeira abertura

1. Escolha o nome do assistente e como ele te chama.
2. Libere o microfone e a permissão "sobrepor outros apps" (para a bolinha).
3. Para funcionar sem internet, baixe o pacote de português do reconhecimento de voz:
   Configurações do Android > Aplicativos > Google > Reconhecimento de fala offline.

## 3. Como usar

- **Um toque** no botão: começa a ouvir. Depois de 3 s de silêncio ele envia sozinho.
  Outro toque durante a escuta envia na hora. Toque enquanto ele fala ou pensa: ele para.
- **Stand-by**: diga "stand-by" ou "pode parar". A esfera apaga. Toque no botão para acordar.
- **Bolinha**: ao sair do app, aparece por cima das outras telas. Branca = ativo, cinza "zZ" = stand-by.
  Arraste para mover, toque para voltar ao Jarvis.
- O stand-by NÃO escuta o microfone em segundo plano (o Android só permite isso com escuta
  contínua e notificação fixa, que gasta bateria). Ele só ouve com o app aberto e depois de um toque.

## 4. O que ele faz

**Sem internet (por regras, rápido):** alarme, timer, calendário, que horas são, abrir qualquer app
instalado (Play Store, APK ou modificado, pelo nome), abrir configurações (Wi-Fi, Bluetooth, brilho,
bateria, som...), rota no mapa.
Exemplos: "alarme às sete e meia", "timer de cinco minutos", "marca dentista amanhã às 15",
"abre o YouTube", "abre as configurações do Wi-Fi", "como chego em Copacabana".

**Memória (só no aparelho):** "lembra que eu moro em Salvador", "o que você sabe", "esquece Salvador",
"esquece tudo", "conversa nova". Ele também segue o fio das últimas 8 trocas.

**Perguntas livres com internet (tudo gratuito):** em Configurações, cole chaves gratuitas de uma ou mais
IAs. Ele tenta na ordem e, se o limite de uma acabar, usa a próxima: Gemini (aistudio.google.com),
Groq (console.groq.com), Mistral, OpenRouter, Cerebras, Cohere, NVIDIA. Buscadores opcionais: Tavily,
Serper, Brave. Sem chave de busca, ele usa Wikipedia e DuckDuckGo, que respondem menos.

**Perguntas livres sem internet:** modelo Gemma 3 de 1 bilhão de parâmetros dentro do celular
(cerca de 550 MB). Em Configurações > Modelo offline, cole um token do Hugging Face e toque em baixar.
O Gemma é um modelo protegido: crie conta grátis em huggingface.co, aceite a licença em
huggingface.co/litert-community/Gemma3-1B-IT e crie um token de leitura.
No A17 de 4 GB de RAM, a resposta pode levar vários segundos e ele erra mais que as IAs da internet.

## 5. Avisos

- Limites e modelos das camadas gratuitas mudam. Se um provedor parar, o nome do modelo fica em
  `lib/provedores.dart`.
- Algumas camadas gratuitas usam o conteúdo para melhorar os produtos delas: não fale nada pessoal
  nas perguntas que vão para a internet.
- Chaves e memória ficam só no aparelho, mas sem criptografia: não deixe o celular destravado com outros.
- Pacotes de IA local mudam de API com frequência. Se o passo do modelo local der erro de compilação,
  o problema provavelmente está em `lib/modelo_local.dart`: me mande o erro.

## 6. O que fica para a próxima versão

- Mexer dentro de outros apps (tocar botões) exige o serviço de acessibilidade.
- Versão para computador, com o Claude Code como núcleo.
