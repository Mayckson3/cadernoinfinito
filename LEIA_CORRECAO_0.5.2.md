# Caderno Infinito — atualização v0.5.2

## O que foi corrigido

**No Windows e Android:** cada pasta (exceto Geral) passa a ter um menu `···` com **Renomear** e **Excluir pasta**. Excluir uma pasta com subpastas remove a organização, **não os desenhos**: todos os desenhos desse conjunto, inclusive itens da lixeira, são movidos para **Geral**. O app pede confirmação.

**No Android:** o erro `serverClientId must be provided on Android` vinha do APK sem Client ID OAuth Web. Agora, ao tocar em **Entrar com Google**, se a configuração ainda estiver faltando, o aplicativo permite **selecionar uma única vez o JSON OAuth Web** baixado do Google Cloud, sem digitar IDs. Somente o Client ID é guardado localmente. Você também pode embutir o ID automaticamente ao compilar com `oauth_web.json` usando `build.ps1`.

> **Atenção:** esta correção não cria credenciais Google. Ainda é obrigatório um projeto Google Cloud com **Drive API ativa**, tela de consentimento OAuth e dois clientes OAuth: tipo **Aplicativo Web** e tipo **Android**. O cliente Android deve ter o package name/applicationId e SHA-1 da assinatura correta, mesmo importando o JSON Web no celular.

## Instalar a correção no código-fonte sem perder o projeto

1. Feche Caderno Infinito no PC. Faça backup dos seus desenhos importantes no menu de preferências. Faça também uma cópia do código de `C:\Users\mayckson\ci`.
2. Baixe o arquivo `Caderno_Infinito_PATCH_v0.5.2_Pastas_Login_Google.zip` e deixe-o em Downloads.
3. No PowerShell, execute:

```powershell
Expand-Archive -LiteralPath "$env:USERPROFILE\Downloads\Caderno_Infinito_PATCH_v0.5.2_Pastas_Login_Google.zip" -DestinationPath "$env:USERPROFILE\ci" -Force
cd "$env:USERPROFILE\ci"
flutter pub get
flutter analyze
flutter test
```

4. **Windows:** execute `flutter build windows --release`. Abra a nova versão com `explorer .\build\windows\x64\runner\Release` e execute `caderno_infinito.exe` lá. Não copie o EXE sozinho; preserve a pasta Release completa.
5. **Android:** execute `flutter build apk --release` (permite importar o JSON Web pelo app) ou `.\build.ps1 -Target apk` (pode embutir o ID de `oauth_web.json`). O APK fica em `build\app\outputs\flutter-apk\app-release.apk`. Instale **por cima do aplicativo existente**, sem desinstalar primeiro para não perder dados locais. A versão 0.5.2+7 possui código de versão superior.

Se precisar liberar scripts PowerShell nessa sessão, execute `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force` antes de `.\build.ps1`.

## Configuração do Google Drive: uma vez por projeto

1. Acesse `https://console.cloud.google.com/` e crie/seleciona um projeto. Ative **Google Drive API** e configure a tela de consentimento OAuth. Se estiver em modo *Testing*, inclua a conta que vai utilizar em **Usuários de teste**.
2. Crie credenciais OAuth **Aplicativo Web** e **Android** no mesmo projeto. No cliente Android, configure o `applicationId` do arquivo `android/app/build.gradle.kts` e o **SHA-1 da assinatura usada para instalar o APK**. Para listar impressões digitais, na pasta `android` rode `.\gradlew signingReport` e confira a variante de instalação.
3. Baixe o JSON do cliente **Web** (estrutura começa com `"web": {"client_id": ...}`). Coloque-o no celular e use **Nuvem → Entrar com Google → Selecionar JSON Web**. O código extrai e salva somente o ID público no armazenamento do app; ele não lê nem armazena senhas. Guarde esse JSON com cuidado: pode conter outras credenciais do projeto, e não é necessário mantê-lo no celular após a importação.
4. Alternativamente, coloque esse JSON na raiz do projeto como `oauth_web.json` e rode `.\build.ps1 -Target apk` para gerar um APK já configurado. O usuário final não precisará importar o arquivo. O script não pede a senha da conta Google.
5. Quando o login abrir, escolha sua conta Google, autorize os arquivos do app no Drive e faça um teste criando um desenho de exemplo, sincronizando no Android e no Windows. A sincronização real **não foi validada neste ambiente**.

No PC, o login pode precisar que você selecione uma vez o JSON OAuth do tipo **App para computador**; é uma credencial diferente do JSON Web. 

## Notas importantes
- O patch modifica **código-fonte**, não os desenhos que já estão salvos. Não apague a pasta de dados do app nem desinstale a versão anterior do Android antes de criar backup.
- As pastas vazias são armazenadas localmente em preferências; a sincronização atual envia os **desenhos** `.ci.json`, não necessariamente a lista de pastas vazias entre dispositivos.
- O erro do login pode mudar depois do Web ID: se houver erro 10/DEVELOPER_ERROR, confira SHA-1, package name, projeto Google e testadores.
- Estrutura revisada estaticamente; **é necessário executar** `flutter analyze`, `flutter test`, builds e testes de autenticação real no seu PC e celular.
- Fontes oficiais: https://pub.dev/packages/google_sign_in_android e https://developers.google.com/workspace/drive/api/guides/api-specific-auth
