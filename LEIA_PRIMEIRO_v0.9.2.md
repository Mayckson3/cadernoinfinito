# Como usar o Caderno Infinito v0.9.2

## Entrega independente

Este ZIP possui todo o projeto-fonte Flutter atual, os testes, scripts e
configuracoes de compilacao. **Nao e um patch.** As pastas nativas `android/`
e `windows/` sao geradas pelo `flutter create` automaticamente quando
faltarem; isso exige que Flutter, SDK Android e Visual Studio/C++ estejam
instalados no computador.

## Compilar sem o erro da unidade E:

1. Descompacte o ZIP inteiro no Windows.
2. Duplo clique em `04_VERIFICAR_NO_C.cmd`. Esse comando copia os fontes
   para `C:\Users\SEU_USUARIO\ci092_full` e executa `flutter analyze`
   e `flutter test`.
3. Somente depois de corrigir qualquer erro identificado, execute
   `01_COMPILAR_TUDO_NO_C.cmd`.
4. O EXE e o APK ficam em `ci092_full\dist`.

Se preferir PowerShell, entre na pasta de build (apos copia):

```powershell
cd "$env:USERPROFILE\ci092_full"
flutter pub get
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release
```

A compilacao via `.cmd` tambem executa a preparacao OAuth e copia os
resultados para a pasta `dist`. Para Windows, transporte a pasta EXE completa,
nao apenas o arquivo `.exe`.

## Novas ferramentas no editor

- Abra **Ações do caderno → Desenho e precisão → Diagnóstico do caderno**
  para ver objetos, camadas, imagens, textos e total de pontos.
- Abra **Ações do caderno → Desenho e precisão → Otimizar traços e reduzir
  pontos** para simplificar riscos redundantes de traços desbloqueados.
  Confirme a acao. Mudancas muito pequenas podem ser suavizadas; faça backup
  antes de alterar trabalhos importantes. Em cadernos grandes demais,
  Desfazer pode nao armazenar todas as etapas.
- Em **Grades e encaixe magnético**, o controle **Captura fluida e econômica**
  ignora pequenos micro-movimentos da caneta. Se preferir registrar todo
  movimento, desative essa opcao.
- No PC, `Ctrl+0` enquadra todo o desenho, `Ctrl+K` seleciona ferramentas,
  `F1` abre as acoes e `Ctrl+S` salva.

## Mudancas de desempenho

- Cursor do mouse atualizado sem reconstruir todo o editor.
- Foco em uma camada sem clonagem completa do documento a cada frame.
- Pintura de quadro com reutilizacao de caixas, caminhos e layout de textos;
  cache invalidado quando o conteudo e modificado.
- Grade pontilhada com densidade adaptativa ao zoom.
- Minimapa reutiliza miniaturas enquanto o conteudo nao muda.
- O snapshot de Desfazer de um traço novo e feito ao finalizar o gesto,
  diminuindo a demora ao pousar a caneta.

## Compatibilidade e precaucoes

O formato dos arquivos `.ci.json` e mantido. Os documentos locais nao sao
apagados pelo script. **Faca backup dos seus desenhos** antes de atualizar;
a sincronizacao do Google Drive so funcionara com credenciais OAuth validas.
O ZIP foi verificado estruturalmente, mas o Flutter e os testes reais
precisam rodar no seu PC. Fluidez depende do aparelho e do tamanho do desenho.
