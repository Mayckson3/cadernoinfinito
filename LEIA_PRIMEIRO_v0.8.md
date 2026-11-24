# Caderno Infinito 0.8.0 — compilar sem patches

**Este ZIP é o projeto-fonte completo e não depende dos ZIPs v0.5, v0.6 ou v0.7.**

## Procedimento de compilação no Windows

1. Extraia **todo** o ZIP, não rode arquivos dentro do visualizador de ZIP.
2. Faça backup dos desenhos e da pasta original antes de instalar a nova versão.
3. Dê dois cliques em `04_VERIFICAR_NO_C.cmd`. Ele copia o projeto para a pasta **`C:\Users\SEU_USUARIO\ci080_full`**, instala pacotes e executa `flutter analyze` e `flutter test`.
4. Se estiver tudo certo, dê dois cliques em `01_COMPILAR_TUDO_NO_C.cmd` para gerar os aplicativos para Windows e Android.
5. Resultados em **`C:\Users\SEU_USUARIO\ci080_full\dist`**:
   - `CadernoInfinito_Windows` (copiar **toda a pasta**, não apenas o EXE);
   - `CadernoInfinito_Android.apk`.

Se desejar, use `02_COMPILAR_EXE_NO_C.cmd` ou `03_COMPILAR_APK_NO_C.cmd` separadamente.

## Requisitos

Flutter SDK, Android Studio + SDK, Java do Android Studio, Git e Visual Studio C++ para Windows; requisitos já preparados no computador usado nas compilações anteriores.

## Atenção ao Google Drive

O projeto contém a lógica de sincronização, **mas não contém credenciais OAuth pessoais**. Se você já tem `oauth_web.json`, `oauth_desktop.json` ou `config.local.json` em `C:\Users\SEU_USUARIO\ci`, poderá executar `IMPORTAR_CONFIG_ANTIGA.cmd` na nova pasta antes de compilar. Nunca publique os JSONs de credenciais.

O aplicativo Android instalado só pode receber um APK como atualização se nome do pacote **e certificado de assinatura** corresponderem. Caso contrário, exporte um backup antes de qualquer desinstalação e confira a assinatura.

## Onde encontrar as novas funções

- Editor → **⋮ Outras opções** → Buscar texto, Índice do quadro, Histórico de versões, Mostrar minimapa.
- Editor → **⋮ Outras opções** → Grades e artboard → Ligar/desligar encaixe magnético e sensibilidade à pressão.
- Editor → Ferramentas → **Compasso** e **Curva Bézier**.
- Selecionar objeto → menu da seleção → Vincular a região do índice / Abrir vínculo.
- Windows → Segurar **Shift** ao redimensionar pelos botões de seleção; **Ctrl+F** para buscar.

Leia `CHANGELOG_v0.8.md` para os limites conhecidos, inclusive a pesquisa sem OCR de escrita manuscrita.

## Quando houver erro

Copie o conteúdo completo da janela do PowerShell. NÃO atualize automaticamente todos os pacotes quando aparecer `packages have newer versions` — são apenas avisos. NÃO compile dentro do Google Drive (unidade `E:`): use a pasta local no disco `C:`.

## Verificação desta entrega

O ZIP foi estruturado com scripts, dependências, arquivos Dart e testes. Não havia Flutter SDK no ambiente de preparação; portanto, os builds ainda não foram confirmados e o aplicativo não deve ser tratado como testado em Android/Windows até passar por `flutter analyze`, `flutter test` e execução real.
