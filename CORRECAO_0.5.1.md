# Caderno Infinito — correção 0.5.1

## Corrigido a partir do `flutter analyze` (Flutter 3.50.1)

- Sintaxe do operador ternário no cálculo de zoom (`editor_screen.dart:413`).
- Valores numéricos inteiros onde era exigido `double` (raio da borracha).
- Sintaxe da opacidade do preenchimento (`board_painter.dart:194`).
- Nome incorreto do argumento `grid` no renderizador de PDF multipágina.
- Matcher `length(2)` substituído por `hasLength(2)` nos testes.
- `test/widget_test.dart` padrão do `flutter create` substituído por teste real de interface.
- Importação nativa acionável por Preferências > Importar desenho editável.
- Remoção de imports e métodos não utilizados.
- `WillPopScope` atualizado para `PopScope`, preservando salvamento ao voltar.
- Aviso específico de depreciação de `material.dart` ignorado: a alternativa
  sugerida não está presente neste projeto; não fazer importação inexistente.

## Aplicar a correção sem perder a configuração local

Extraia o arquivo `Caderno_Infinito_PATCH_v0.5_para_v0.5.1.zip` sobre a pasta
`CadernoInfinito_v0.5` existente, substituindo os arquivos quando solicitado.
Os diretórios de plataforma e as credenciais locais não fazem parte do patch.

Depois:

```powershell
flutter pub get
flutter analyze
flutter test
```

Se `flutter analyze` apontar novos problemas, envie a saída. Isso pode ocorrer
em razão de diferenças do SDK ou dependências, ainda não verificados aqui.

Para o APK, conclua a instalação de Command-line Tools e execute
`flutter doctor --android-licenses`. Para Windows, instale o Visual Studio C++.

## Validação

Revisão de código e substituições verificadas automaticamente. Sem Flutter SDK
no ambiente de preparação, não foram executados `flutter analyze`,
`flutter test`, compilação Android ou compilação Windows.
