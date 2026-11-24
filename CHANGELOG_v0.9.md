# Caderno Infinito v0.9.0 — interface mais clara, iconográfica e responsiva

## Novidades implementadas

### Biblioteca
- Título e botão **Novo desenho** se adaptam à largura disponível, sem competir pelo mesmo espaço.
- No celular, a navegação rápida por **pastas** e **Lixeira** é feita por chips com ícones e indicação da pasta selecionada; o menu lateral permanece disponível.
- Cartões dos desenhos usam dimensões diferentes em celulares e telas maiores.
- Busca por **título, pasta ou texto** com ação explícita para limpar.
- Ações dos desenhos e das pastas agora apresentam ícones e verbos objetivos; exclusão definitiva continua exigindo confirmação.
- Textos mais concisos nos estados vazios e nos contadores de desenhos.

### Editor
- **Seletor iconográfico de ferramentas**, com 34 opções organizadas nas categorias Escrever e pintar, Desenhar formas, Selecionar e modificar, Inserir e medir.
- Cada ferramenta tem nome descritivo e ícone; ferramentas ativas são destacadas. Uma caixa de pesquisa encontra a ferramenta pelo nome.
- **Central de ações** organizada por finalidade: Organizar e encontrar; Visualização; Desenho e precisão; Arquivos e segurança.
- No celular, os controles superiores exibem apenas as ações essenciais; funções avançadas continuam disponíveis na central de ações.
- Opção **Exportar ou imprimir** dentro da central de ações abre um seletor de formatos com ícones e nomes completos.
- Ícones de ferramentas ganham área de toque mínima e rótulos de acessibilidade.
- Novos atalhos no Windows: **Ctrl+K** abre a escolha de ferramentas; **F1** abre a central de ações. Os demais atalhos continuam disponíveis.
- Também foram mantidas as ações de camadas, minimapa, histórico, marcações, apresentações, desenhos, PDFs e Google Drive.

### Aparência e adaptação
- Tema Material 3 refinado com azul índigo, fundos suaves, botões e chips consistentes, cantos arredondados e uso com toque.
- Pontos de adaptação centralizados no código para celular, tablet e desktop.
- Preservado o sistema claro/escuro e SafeArea do modo de tela cheia do Android.

### Testes adicionados
- Catálogo de ferramentas: nenhuma ferramenta omitida ou duplicada; nomes coerentes.
- Comportamento dos tamanhos de tela de celular, tablet e PC.

## O que não mudou
- Não foi alterado o formato dos arquivos .ci.json nem os IDs dos elementos ou das ferramentas.
- O Google Drive continua dependendo das credenciais OAuth reais do usuário. Este pacote não contém credenciais privadas.
- A v0.9.0 não adiciona OCR de escrita manuscrita, sincronização permanente com o aplicativo fechado ou edição completa de controles Bézier.

## Verificação técnica desta entrega
- Foram realizadas verificações estáticas do código e integridade do pacote ZIP.
- **Não foi executado** `flutter analyze`, `flutter test`, nem builds EXE/APK aqui porque o Flutter não está instalado neste ambiente.
- Rode `04_VERIFICAR_NO_C.cmd` antes de compilar. Se houver erro, copie o log completo para correção.
