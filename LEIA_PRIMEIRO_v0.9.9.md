# Caderno Infinito v0.9.9 — projeto completo para EXE e APK

## Novas funções de exclusão rápida

1. Na **biblioteca**, clique na pasta desejada (`Concurso`, `Português` etc.).
2. Clique em **Selecionar vários** e marque os cartões com um clique/toque. Também pode manter pressionado um cartão para começar.
3. Clique em **Selecionar todos** para marcar o conteúdo da lista visível; ou use **Mover selecionados para a Lixeira**.
4. Se quiser remover *todos* os desenhos dessa pasta, use **Mover todos desta pasta para a Lixeira**, mesmo que tenha aplicado uma pesquisa. O aplicativo informa a quantidade total antes de confirmar. Essa ação não atinge subpastas.
5. Na **Lixeira**, escolha **Selecionar vários** para restaurar ou apagar definitivamente os selecionados.

**Importante:** mover para a Lixeira não é exclusão definitiva. Para apagar de verdade, é preciso usar a Lixeira e confirmar a exclusão irreversível. Faça backup dos documentos importantes antes de apagar.

## Compilar no seu Windows

1. Extraia **todo o ZIP**; não aplique patches antigos.
2. Execute `04_VERIFICAR_NO_C.cmd`: deve mostrar `No issues found!` e `All tests passed!`.
3. Execute `01_COMPILAR_TUDO_NO_C.cmd` para gerar Windows e Android, ou os atalhos individuais.
4. O script copia a fonte para `C:\Users\mayckson\ci099_full` (em geral `%USERPROFILE%\ci099_full`, adaptando-se ao usuário do Windows) e compila lá, fora do Google Drive.
5. Resultados: `%USERPROFILE%\ci099_full\dist\CadernoInfinito_Windows\caderno_infinito.exe` (copiar **a pasta inteira**) e `%USERPROFILE%\ci099_full\dist\CadernoInfinito_Android.apk`.

## Cuidado com Google Drive

A configuração OAuth existente não é embutida neste ZIP. Configure a credencial Web e o SHA-1 Android no seu projeto Google Cloud, ou importe o JSON quando solicitado. A falta de OAuth não impede a compilação do APK, mas impede o login Android até configurar.

## Diagnóstico

- Se o verificador apontar erro, copie a saída de `flutter analyze` e `flutter test`.
- Evite compilar diretamente na unidade `E:` (Google Drive) por causa dos links simbólicos de plugins. Use os arquivos `*_NO_C.cmd`.
- Não desinstale o aplicativo anterior sem fazer backup dos cadernos; se a assinatura Android não coincidir, a substituição pode exigir desinstalação e apagar dados locais.
- Os testes Flutter e as builds desta nova versão **não foram executados no ambiente de preparação**; devem ser confirmados no computador.
