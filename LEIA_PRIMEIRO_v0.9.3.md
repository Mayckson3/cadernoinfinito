# Caderno Infinito v0.9.3 — Instruções para compilar

Este ZIP é **o código-fonte completo**, incluindo testes, recursos, scripts e
configurações necessários para reconstruir os aplicativos Flutter. Não é patch.
As pastas nativas `android/` e `windows/` são geradas automaticamente pelo
Flutter na primeira compilação, se não existirem.

## Compilar sem erro de caminhos longos / symlink do Google Drive

1. Extraia o ZIP, mesmo que esteja no Google Drive (E:).
2. Execute `04_VERIFICAR_NO_C.cmd`: copia para o disco C:, executa
   `flutter pub get`, `flutter analyze` e `flutter test`.
3. Se a verificação passar, execute `01_COMPILAR_TUDO_NO_C.cmd`.
4. Os resultados aparecerão em `C:\Users\SEU_USUARIO\ci093_full\dist`:
   - `CadernoInfinito_Windows/` (copie a pasta TODA com o EXE, DLL e dados)
   - `CadernoInfinito_Android.apk`
5. Atalhos adicionais: `02_COMPILAR_EXE_NO_C.cmd` ou
   `03_COMPILAR_APK_NO_C.cmd` para compilar apenas uma plataforma.

## Usar com a caneta

- Toque no pequeno ícone de caneta no canto superior esquerdo do quadro
  para abrir ou recolher os **Atalhos rápidos**.
- Botão lateral principal pressionado: borracha temporária. Solte a caneta
  da tela para voltar à ferramenta anterior (depende de caneta compatível).
- Segundo botão da caneta: laço de seleção (dependente do hardware).
- Caneta invertida: borracha temporária (se o aparelho informar essa ponta).
- Toque breve com dois dedos: **Desfazer**. Arrastar/pinçar não desfaz.
- **Precisão / Gestos**: ative ou desative os atalhos, configure o modo
  "Mover quadro com o dedo; escrever com a caneta" e os gestos de 3/4 dedos.
- Na barra rápida: ferramentas, cor, predefinições de 1,5 / 3,5 / 8 / 14 px.
- Windows: Alt+B (pincel anterior), Alt+E (borracha), Alt+V (selecionar).

## Segurança

- Faça backup dos cadernos antes de substituir uma versão antiga.
- O login do Google depende de credenciais OAuth próprias, não incluídas.
- Sem o Flutter neste ambiente, não foram executados builds reais de EXE/APK.
  A análise e os testes devem passar no seu computador antes de usar a versão.
