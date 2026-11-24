# Google Drive com login simples — Caderno Infinito v0.5

## Depois que o app estiver configurado, a pessoa que usa só faz isto

1. Abra **Caderno Infinito** no Windows ou Android.
2. Toque em **Nuvem → Entrar com Google**.
3. Escolha sua conta Google e autorize o acesso aos **arquivos criados/abertos pelo aplicativo no Drive**.
4. Pronto: a pasta **Meu Drive/Caderno Infinito** é criada automaticamente e recebe os desenhos editáveis `.ci.json`.

**Não é necessário inserir senha no aplicativo, copiar token, digitar Client ID ou configurar uma pasta manualmente.** O login é fornecido pelo Google. Reabra com a mesma conta no outro aparelho. A sincronização é periódica e após o editor ser fechado, **não é coedição instantânea**.

## Etapa única, para quem compila/distribui o aplicativo

Todo app que usa o login Google precisa ser identificado pelo Google com um **projeto OAuth real**. Este projeto-fonte **não inclui as credenciais de outro desenvolvedor** e não pode fazer login no Google antes dessa configuração inicial. O usuário final de um aplicativo já preparado **não precisa repetir essas etapas**.

1. No [Google Cloud Console](https://console.cloud.google.com/), crie **um único projeto** para PC + Android, habilite a **Google Drive API** e configure a tela de consentimento. Use escopo `https://www.googleapis.com/auth/drive.file` (acesso limitado). Para a identificação da conta no Windows, o código também solicita `openid email`. Se a publicação estiver em *Testing*, inclua as contas de teste; para distribuição pública, cumpra a verificação e publicação pertinentes.
2. Nesse mesmo projeto, crie um **cliente OAuth Desktop**, um **cliente OAuth Web** e um **cliente OAuth Android**. Para o Android use o pacote `br.cadernonuvem.caderno_infinito` (confira o `applicationId` gerado) e o SHA-1 da chave de assinatura do APK (debug e/ou release conforme o caso).
3. Baixe os JSON dos clientes Desktop e Web, renomeie para `oauth_desktop.json` e `oauth_web.json` e coloque na raiz do projeto **antes de compilar**. Alternativamente, `google-services.json` com um `oauth_client` de tipo `3` pode substituir `oauth_web.json` para extrair o Web Client ID. Os JSON de OAuth precisam pertencer ao **mesmo projeto Google Cloud**.
4. Execute no PowerShell:

```powershell
.\setup.ps1
.\build.ps1 -Target check
.\build.ps1 -Target windows
.\build.ps1 -Target apk
```

O script `prepare_google_login.ps1` lê os arquivos e escreve os IDs em `config.local.json` **automaticamente**. Ele **não** recolhe a senha da sua conta Google. O Windows ainda permite dispensar `oauth_desktop.json` durante a compilação: ao tocar em **Entrar com Google** pela primeira vez, selecione o JSON Desktop baixado do Cloud; o aplicativo guarda as informações de cliente localmente no armazenamento protegido. **No Android, o Web Client ID precisa entrar no build**; a janela de login não pode inventar um ID OAuth válido.

Se os arquivos JSON tiverem outros nomes, use:

```powershell
.\prepare_google_login.ps1 -WebClientJson "C:\caminho\client_secret_web.json" -DesktopClientJson "C:\caminho\client_secret_desktop.json"
```

Para gerar SHA-1 de debug, após `setup.ps1`:

```powershell
cd android
.\gradlew signingReport
```

Verifique também a assinatura usada no APK distribuído. Para distribuir uma versão de produção, realize verificação e publicação do app no Google Cloud quando exigido pelo Google.

## Segurança e limitações

- **Drive:** permissão `drive.file`, sem acesso global a todas as suas pastas; os arquivos do aplicativo são salvos como arquivos normais em uma pasta visível do Drive. Outros arquivos existentes não são automaticamente lidos.
- **Windows:** login abre o navegador oficial Google e recebe o retorno em `127.0.0.1`, com `state` e PKCE. Os tokens ficam em `flutter_secure_storage` e **não** em arquivos `.ci.json`.
- **Android:** usa `google_sign_in` 7.x, com autenticação e autorização separadas, e o seletor de conta disponibilizado pelo Google.
- **Conflitos:** alterações offline concorrentes criam cópias separadas. Um erro de autorização ou de rede não deve apagar documentos locais.
- **Desconectar** encerra a sessão local, mas não exclui a pasta ou os arquivos do seu Drive. O consentimento pode ser revogado nas configurações da conta Google.
- O primeiro login pode exigir consentimento e, dependendo do modo do projeto OAuth, uma tela de **aplicativo não verificado** ou bloqueio de acesso para contas não inscritas como testadores. Isso precisa ser resolvido pelo responsável pelo projeto Google Cloud.
- Esta entrega **não contém tokens nem IDs OAuth reais**. Sem credenciais do projeto, o login não pode ser validado.
- Esta versão **não foi compilada nem testada contra o Google Drive real** no ambiente de criação. Rode `flutter analyze`, `flutter test` e teste PC/Android com uma conta de teste antes de usar desenhos importantes.

## Referências oficiais

- [Google: OAuth para aplicativos Desktop](https://developers.google.com/identity/protocols/oauth2/native-app)
- [Google: permissões da API Drive](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [Flutter: google_sign_in](https://pub.dev/packages/google_sign_in)
- [Flutter: configuração Android do Google Sign-In](https://pub.dev/packages/google_sign_in_android)
