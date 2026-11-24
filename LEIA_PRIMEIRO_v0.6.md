# Caderno Infinito v0.6.0 — projeto completo

Esta entrega contém **todo o código-fonte Flutter do aplicativo**, não é um patch. Não precisa aplicar os ZIPs v0.5, v0.5.1 ou v0.5.2. As pastas de plataformas `android/` e `windows/` são **geradas automaticamente pelo Flutter na primeira compilação**, se ainda não existirem. Não são fornecidos EXE e APK pré-compilados nesta entrega.

## Mais simples: dois cliques

1. **Descompacte o ZIP em uma pasta de caminho curto**, por exemplo `C:\Users\mayckson\ci06`. Não use a antiga pasta de Downloads com caminho grande: isso já causou erro C1083 no plugin Windows.
2. Abra a pasta onde estão `pubspec.yaml`, `build.ps1` e os arquivos `.cmd`.
3. Dê dois cliques em `VERIFICAR_PROJETO.cmd` para executar `flutter analyze` e `flutter test`.
4. Dê dois cliques em **`COMPILAR_TUDO.cmd`** para gerar EXE e APK; ou use `GERAR_EXE.cmd` e `GERAR_APK.cmd` separadamente.
5. Os resultados são copiados automaticamente para a pasta `dist/`:
   - `dist/CadernoInfinito_Windows/` — **copie a pasta inteira**, com `caderno_infinito.exe`, DLLs e `data/`;
   - `dist/CadernoInfinito_Android.apk` — arquivo para instalar no Android.

Você também pode abrir um PowerShell na pasta e executar:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Target check
powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Target ambos
```

**Atenção:** seu PC precisa continuar com Flutter, Android Studio/SDK/NDK, Git e Visual Studio com C++, que você já instalou antes.

## Nova ferramenta de transformação

No editor, ative **Selecionar** (ou Laço) e selecione um ou mais objetos.

- **Oito alças pequenas** aparecem ao redor: quatro cantos + quatro lados.
- Arraste um canto para modificar a largura e altura.
- Arraste uma alça lateral para alterar apenas uma dimensão.
- Arraste **o círculo de giro acima** da seleção para rodá-la livremente. No PC, segure **Shift** durante a rotação para encaixar em múltiplos de 15°.
- Arraste o interior da seleção para **mover todos os objetos**.
- Use **Desfazer (Ctrl+Z)** caso a transformação não fique como desejado.
- As alças acompanham o zoom, a rotação do quadro, o mouse, a caneta e o toque. Sua aparência permanece discreta.

Os elementos continuam editáveis no formato `.ci.json` utilizado pela v0.5.2. Ainda existem limites em objetos com rotação ou distorção prévia: a caixa é alinhada aos eixos do documento (não ao ângulo visual interno de cada objeto).

## Login Google e dados já existentes

Este ZIP **não inclui senhas, JSONs privados nem os dados locais do seu aparelho**. Isso é intencional.

- Se você já tem `oauth_web.json`, `oauth_desktop.json` ou `config.local.json`, poderá copiá-los da pasta anterior para a **nova pasta do projeto**, sem divulgá-los. O script busca os JSONs automaticamente.
- Sem as credenciais OAuth corretas, o aplicativo ainda compila, mas a sincronização com o Google Drive poderá não funcionar.
- No Android, mantenha **o mesmo nome de pacote** (`br.cadernonuvem.caderno_infinito`) e **a mesma chave de assinatura** para instalar por cima da versão anterior. Na configuração padrão, o Flutter usa a assinatura de debug até ser configurada uma chave de release própria. Se a assinatura mudar, o Android pode rejeitar a atualização; não desinstale o aplicativo com desenhos importantes sem exportar backup.
- A funcionalidade de sincronização permanece a da v0.5.2 e necessita teste real entre dispositivos. Compilar não valida o OAuth.

## Para próximas alterações

Guarde este ZIP e sua pasta `ci06`. Em atualizações futuras, peça **a pasta completa atualizada**, não apenas patch. Sempre faça backup de desenhos e credenciais antes de trocar o código, e execute a verificação antes de gerar EXE/APK.

## Verificação

O código foi revisado e passou por checagem estática de estrutura dos arquivos nesta entrega. **Não foi possível rodar Flutter/Windows/Android SDK neste ambiente**; rode `VERIFICAR_PROJETO.cmd` e a compilação no seu computador para confirmar a compatibilidade efetiva com seu Flutter 3.50.1.

### Usar a configuração OAuth da pasta anterior

Se o projeto anterior estiver em `C:\Users\mayckson\ci`, execute `IMPORTAR_CONFIG_ANTIGA.cmd` na nova pasta **antes de compilar**. O comando copia apenas as configurações ausentes, sem sobrepor credenciais novas; não envia arquivos para a internet e não modifica os desenhos. Isso não dispensa criar as credenciais corretas no Google Cloud se ainda não estiverem configuradas.
