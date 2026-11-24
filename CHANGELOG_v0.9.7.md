# Caderno Infinito v0.9.7 — Correções de análise e compilação

Base: projeto **v0.9.6**. Esta entrega é um ZIP completo, não um patch.

## Erros corrigidos

- `lib/screens/editor_screen.dart`: substituído `Wrap(mainAxisSize: ...)` inválido por `Row(mainAxisSize: ...)` na lista de personalização do menu radial.
- `lib/widgets/document_minimap.dart`: substituído `onJump(...)` por `widget.onJump(...)` no toque do minimapa.
- Removidos **nove imports desnecessários** identificados no log de `flutter analyze` enviado pelo usuário.
- Incluído teste de widget para confirmar que tocar no minimapa invoca seu callback sem exceção.
- Versão atualizada para `0.9.7+19` e pasta isolada de compilação alterada para `%USERPROFILE%\ci097_full`.

## Mantido

Menu radial com **centro sem ícones**, ícones externos, personalização das ações e o restante do projeto-fonte da versão anterior.

## Validação e limites

- Substituições verificadas por script com ocorrência exata e comparação de arquivos.
- Integridade do ZIP e inventário SHA-256 conferidos.
- **Não foi executado `flutter analyze`, `flutter test` nem `flutter build` neste ambiente**, pois Flutter/Dart SDK não está instalado. Execute `04_VERIFICAR_NO_C.cmd` antes de compilar.
