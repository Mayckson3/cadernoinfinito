# Caderno Infinito v1.0.1 — projeto completo para EXE e APK

## Correção v1.0.1
O campo de texto agora declara a linha de base alfabética exigida pelo Flutter. A edição no quadro e a formatação por trecho permanecem.

## Compilar
1. Extraia todo o ZIP (não sobreponha um projeto anterior).
2. Execute `04_VERIFICAR_NO_C.cmd`. Se análise e testes passarem, execute `01_COMPILAR_TUDO_NO_C.cmd`.
3. Pasta de compilação local: `%USERPROFILE%\ci101_full`. O Flutter prepara as pastas nativas quando ausentes.
4. Resultados: `%USERPROFILE%\ci101_full\dist\CadernoInfinito_Windows\caderno_infinito.exe` (copie a pasta inteira) e `%USERPROFILE%\ci101_full\dist\CadernoInfinito_Android.apk`.
5. Faça backup dos cadernos antes de atualizar. As credenciais OAuth devem ser configuradas separadamente; não compartilhe JSONs de credenciais.

## Texto no quadro
1. Selecione **Inserir texto**. Na barra inferior (ou no botão de tamanho em tela cheia), toque em **Fonte padrão** e informe o tamanho antes de digitar.
2. Toque com a caneta ou mouse no lugar onde o texto começa; em modo dedo para navegar, use a caneta para escrever.
3. Digite diretamente no quadro. A barra contextual tem B/I/U, tachado, destaque, cor e tamanho de trecho. Deslize horizontalmente para acessar mais ícones no celular.
4. Selecione caracteres usando a seleção normal do campo de texto; toque no ícone para formatar só o trecho. Sem seleção, os estilos se aplicam à próxima digitação. O botão de tamanho à esquerda altera toda a caixa. O ícone Tamanho do trecho ajusta só a seleção ou a digitação seguinte.
5. Toque no ✓ ou em uma área vazia para concluir; X ou Esc cancela. Ctrl+Enter conclui no PC. Uma anotação vazia não é criada; para apagar uma caixa existente, use Selecionar → Excluir.
6. Para editar texto existente, toque nele com a ferramenta Texto, ou selecione o objeto e use Editar texto. Para mover, redimensionar e girar, use Selecionar. A formatação é salva no arquivo editável.

## Observações
- Fonte padrão inicial: 18 px do quadro. O tamanho visual acompanha o zoom. A preferência é por caderno.
- A interface usa as fontes do sistema; diferenças de fonte/métricas entre Windows e Android ou em leitores SVG são possíveis.
- A exportação PDF vetorial de linhas e formas mantém sua restrição anterior (não aceita textos); use PDF comum ou SVG para texto.
- A nova execução dos testes Flutter está pendente neste ambiente. Verifique no seu PC antes de substituir a versão anterior.
