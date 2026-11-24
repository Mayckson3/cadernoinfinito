# Caderno Infinito 0.9.8 — Baixe, verifique e compile

## A) Preparação

1. Faça backup dos cadernos importantes; não desinstale o app atual antes de confirmar a nova compilação.
2. Extraia **todo** o ZIP numa pasta de sua escolha. Os atalhos `*_NO_C.cmd` copiam automaticamente o código para uma pasta local curta, fora do Google Drive, evitando erros de links simbólicos no disco `E:`.
3. Não é preciso copiar patches nem instalar versões anteriores.

## B) Verificação primeiro

Dê dois cliques em **`04_VERIFICAR_NO_C.cmd`**. O comando executa `flutter pub get`, `flutter analyze` e `flutter test` em:

`C:\Users\mayckson\ci098_full`

Resultado esperado: `No issues found!` e `All tests passed!`. Se algum teste falhar, copie o log inteiro.

## C) Compilação

Após a verificação, execute **`01_COMPILAR_TUDO_NO_C.cmd`** para EXE + APK, ou **`02_COMPILAR_EXE_NO_C.cmd`** / **`03_COMPILAR_APK_NO_C.cmd`** para uma plataforma.

A pasta de saída é:

`C:\Users\mayckson\ci098_full\dist`

Copie a pasta Windows completa (EXE, DLLs e `data/`), não apenas o EXE. O APK é gerado como `CadernoInfinito_Android.apk`.

## D) Observações

- Os avisos de versões mais novas de pacotes não indicam, por si sós, um erro.
- Na primeira compilação, as pastas nativas `windows/` e `android/` podem ser criadas automaticamente pelo `flutter create`.
- O Google Drive no Android depende de credenciais OAuth e SHA-1 configurados; isso não impede a compilação.
- Não foi possível executar o Flutter neste ambiente. O log do usuário confirma a análise sem problemas na versão anterior, mas os testes desta versão ainda precisam ser executados no Windows.
