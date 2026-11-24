# Caderno Infinito 0.9.4 — ZIP completo para gerar Windows e Android

Este arquivo contém o **projeto-fonte completo**. Não é patch. Não precisa da 0.9.3 ou de outras versões anteriores para recompilar. As pastas nativas `windows/` e `android/` são recriadas pelo Flutter, se necessário.

## Passo 1 — Verificar o código

1. Extraia o ZIP, inclusive se ele estiver no Google Drive.
2. Abra a pasta extraída e clique em **`04_VERIFICAR_NO_C.cmd`**.
3. O script copia o projeto para `C:\Users\SEU_USUARIO\ci094_full`, evitando o erro de links simbólicos no drive E: e caminhos longos.
4. Ele executa `flutter pub get`, `flutter analyze` e `flutter test`.

## Passo 2 — Gerar os aplicativos

- Clique em **`01_COMPILAR_TUDO_NO_C.cmd`** para gerar EXE e APK.
- Só Windows: **`02_COMPILAR_EXE_NO_C.cmd`**.
- Só Android: **`03_COMPILAR_APK_NO_C.cmd`**.
- Os resultados são copiados para `C:\Users\SEU_USUARIO\ci094_full\dist`.
- **Windows:** distribua a pasta *CadernoInfinito_Windows* inteira (EXE, DLL e dados). **Android:** use *CadernoInfinito_Android.apk*.

## Como usar o menu radial

1. Escolha qualquer ferramenta normal de desenho.
2. **Encoste a caneta e segure parada** por aproximadamente meio segundo.
3. Quando aparecer a roda, **arraste a ponta até uma função**. A função será destacada e o nome aparecerá no centro.
4. **Solte a ponta para executar**. Soltar no centro, longe dos ícones ou cancelar o contato fecha o menu sem executar nenhuma ação.
5. Você pode acessar **Caneta, Marcador, Borracha, Selecionar, Laço, Mover quadro, Desfazer, Refazer, Escolher cor e Espessura**.

**PC:** também é possível clicar e segurar o botão direito do mouse, arrastar e soltar para escolher uma ação.

**Configurações:** *Precisão / Gestos* → "Menu radial ao segurar a caneta"; opcionalmente habilite o menu com dedo ou desligue o botão direito. O menu com dedo começa desligado.

**Compatibilidade:** alguns dispositivos enviam os movimentos da caneta como toque, não como evento de caneta. Nesses casos, habilite a opção "Permitir menu radial também com o dedo" e teste, evitando apoiar a mão no quadro.

## Cuidados

- Faça um backup dos desenhos antes de substituir uma instalação anterior.
- O ZIP não contém as senhas nem as credenciais Google; a integração Drive continua dependendo de OAuth próprio.
- Execute o verificador antes de compilar. **Os builds e testes Flutter ainda não foram executados neste ambiente.**
- A versão mantém a edição vetorial, camadas, Lixeira, exportações e funções da 0.9.3.
