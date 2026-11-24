# Caderno Infinito v0.9.1 — projeto COMPLETO para compilar

Não é atualização incremental: esta pasta contém a árvore-fonte completa, os testes e os scripts. **Não precisa instalar patches anteriores.** Os diretórios nativos `android/` e `windows/` são criados automaticamente por `flutter create` no primeiro build.

## Antes de substituir qualquer instalação
1. No aplicativo atual, exporte uma cópia dos cadernos em **Preferências → Exportar backup**.
2. Mantenha o ZIP e a pasta-fonte v0.9.0 antigos como backup.
3. Não desinstale o app do Android sem exportar os desenhos; atualizar por cima exige o mesmo identificador de pacote e certificado de assinatura.

## Compilar no Windows 11
1. Extraia **todo** o ZIP em qualquer pasta; não execute diretamente dentro do ZIP.
2. Execute `04_VERIFICAR_NO_C.cmd` (Flutter pub get, análise e testes).
3. Se tudo passar, execute `01_COMPILAR_TUDO_NO_C.cmd` (Windows e Android), ou os arquivos individuais `02_COMPILAR_EXE_NO_C.cmd` e `03_COMPILAR_APK_NO_C.cmd`.
4. O script transfere automaticamente os fontes para `C:\Users\SEU_USUARIO\ci091_full`, evitando falhas de links simbólicos do Flutter na unidade E: sincronizada pelo Google Drive.
5. EXE e dependências: `ci091_full\dist\CadernoInfinito_Windows\`. **Transfira a pasta Windows inteira, não só o EXE.**
6. APK: `ci091_full\dist\CadernoInfinito_Android.apk`.

### Comandos alternativos (PowerShell, dentro de `ci091_full`)
```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define-from-file=config.local.json
flutter build apk --release --dart-define-from-file=config.local.json
```

O build prepara automaticamente `config.local.json` pelo script `prepare_google_login.ps1`. Para o login funcionar, importe seu próprio `oauth_web.json`/`oauth_desktop.json` seguindo `CONEXAO_GOOGLE.md`; **nenhum segredo OAuth está incluído**.

## Correções principais v0.9.1
- Restauração de backups com IDs previamente apagados definitivamente sem travamento: o desenho é recuperado com **novo ID**, preservando a exclusão remota anterior.
- Recuperação de `_permanently_deleted.json` após interrupção: reconhece a lista de IDs, em vez de descartá-la como formato inválido.
- Salvamento mais seguro: arquivo principal corrompido não destrói um backup anterior válido; IDs internos precisam coincidir com o nome do documento.
- Cancelamento do login Google Desktop apresenta erro compreensível, não acesso nulo a `code`.
- Ações de seleção respeitam bloqueios de objetos/camadas. Colar objetos valida conteúdo e tamanho; agrupamentos colados/duplicados ganham identidades próprias.
- Exclusão de camada agora pede confirmação e pode ser desfeita; alterações de camadas entram no histórico do editor.
- Segundo toque durante traço guarda a parte já escrita antes de iniciar o zoom por gesto.
- Encaixe em grade com espaçamento inválido deixa de gerar cálculo indefinido; rolagem somente horizontal não muda o zoom.
- Scripts isolam esta versão em `ci091_full` para não misturar fontes e builds de versões antigas.

## Verificação e limitações
Executada conferência estrutural dos 41 arquivos Dart, verificação do ZIP e inspeção de pontos críticos. Foram adicionados cinco testes regressivos. **Flutter não está instalado no ambiente de preparação**; por isso não foi possível executar `flutter analyze`, `flutter test` ou compilar EXE/APK aqui. Esses passos devem ser validados no seu PC.

A sincronização Google Drive só pode ser considerada funcional após configurar OAuth e testar alterações reais nos dois aparelhos. O app não oferece OCR de manuscritos nem sincronização contínua com o app fechado.
