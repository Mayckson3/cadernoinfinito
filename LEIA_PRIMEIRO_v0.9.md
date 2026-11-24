# Caderno Infinito v0.9.0 — pasta-fonte completa para Windows e Android

Este ZIP contém o código-fonte completo. Não é patch e não depende dos ZIPs anteriores.

## Como compilar com o mínimo de passos

1. **Faça backup dos desenhos** no Caderno Infinito já instalado e preserve o projeto anterior.
2. Extraia TODO o ZIP em uma pasta qualquer (não execute arquivos de dentro do ZIP).
3. Clique duas vezes em **`04_VERIFICAR_NO_C.cmd`**. O script copia o projeto para `C:\Users\SEU_USUARIO\ci090_full` e executa `flutter pub get`, `flutter analyze` e `flutter test`.
4. Somente se os testes passarem, execute **`01_COMPILAR_TUDO_NO_C.cmd`** para compilar Windows e Android. Use `02_COMPILAR_EXE_NO_C.cmd` ou `03_COMPILAR_APK_NO_C.cmd` para compilar apenas uma plataforma.
5. Encontre os resultados em `C:\Users\SEU_USUARIO\ci090_full\dist`:
   - `CadernoInfinito_Windows\caderno_infinito.exe` (copie a pasta Windows inteira com DLLs e data);
   - `CadernoInfinito_Android.apk`.

A primeira compilação usa `flutter create` para preparar as pastas nativas quando necessário. Flutter, Git, Android Studio/SDK e Visual Studio com componentes C++ devem estar instalados no seu computador, como nas compilações anteriores.

**Não compile diretamente na unidade E: / pasta sincronizada pelo Google Drive.** O script já copia a fonte para uma pasta curta no C:, evitando problemas de symlinks e caminhos longos.

## Nova interface

- **Biblioteca no celular:** toque nos chips com ícones para alternar entre Todas, suas pastas e Lixeira.
- **Buscar desenhos:** procure por título, pasta e conteúdo textual; toque no `X` para limpar.
- **Editor → ícone da grade (Ferramentas):** selecione entre 34 ferramentas com nomes e ícones, filtráveis pela pesquisa.
- **Editor → menu de três pontos:** abre a Central de ações, com as funções separadas por categoria. No celular, exportar e camadas estão nessa central para não ocupar a barra superior.
- **Windows:** `Ctrl+K` abre ferramentas; `F1` abre a central; `Ctrl+F` busca texto; `Ctrl+S` salva; `Ctrl+Z` desfaz; `Ctrl+Shift+Z` refaz.

## Google Drive e APK

A lógica do Google Drive foi preservada. O login do Android exige as credenciais OAuth configuradas no Google Cloud para o pacote `br.cadernonuvem.caderno_infinito` e a assinatura SHA-1 do APK. Se houver `oauth_web.json`, `oauth_desktop.json` ou `config.local.json` no projeto antigo, utilize **`IMPORTAR_CONFIG_ANTIGA.cmd`** antes de compilar, observando a documentação `CONEXAO_GOOGLE.md`. Nunca compartilhe arquivos privados de credenciais nem publique esses arquivos no GitHub.

Não desinstale o aplicativo do celular para instalar o APK novo sem antes exportar seus desenhos. A atualização por cima do aplicativo atual só funciona se a assinatura digital corresponder à versão instalada.

## Se houver erro

Copie toda a saída da janela de verificação/compilação. Avisos sobre pacotes mais novos não indicam erro por si só. Este ZIP foi verificado estruturalmente, mas **o Flutter não estava disponível no ambiente de produção deste pacote** para executar a análise, os testes e as compilações reais.

Veja `CHANGELOG_v0.9.md` para as mudanças e limites conhecidos.
