# Caderno Infinito v0.9.7 — Projeto completo corrigido

Este pacote contém o **código-fonte completo** (Flutter) da versão v0.9.7, testes, documentação e atalhos de compilação. Não é patch. **As pastas nativas** Android e Windows são geradas pelo Flutter na primeira compilação por meio de `flutter create`.

## Como usar no Windows

1. Faça uma cópia de segurança de seus cadernos importantes antes de instalar o novo aplicativo.
2. Extraia o ZIP em pasta própria, **fora do Google Drive em E:**. Se extrair em E:, use os atalhos `*_NO_C.cmd`, que copiam o projeto para o disco C:.
3. Execute **`04_VERIFICAR_NO_C.cmd`**. O script copia o projeto para `C:\Users\mayckson\ci097_full` (ou `%USERPROFILE%\ci097_full`) e executa `flutter pub get`, `flutter analyze` e `flutter test`.
4. Somente depois de verificar sem erros, execute **`01_COMPILAR_TUDO_NO_C.cmd`** para construir Windows + Android, ou escolha o atalho da plataforma desejada.
5. Acesse `%USERPROFILE%\ci097_full\dist` para encontrar o APK Android e a pasta com o EXE Windows e seus arquivos auxiliares.

## Erros resolvidos

- Parâmetro `mainAxisSize` inválido em um `Wrap` da configuração do menu radial.
- Chamada sem `widget.` do callback `onJump` no minimapa.
- Nove avisos de imports desnecessários.

Os avisos de pacotes com versões mais recentes podem continuar e não significam falha. O login Google no Android depende de OAuth configurado corretamente.

**Status:** correções feitas no código; testes Flutter e compilação real ainda precisam ser executados no PC. Se o analisador apresentar outros problemas após esta versão, envie a saída integral.
