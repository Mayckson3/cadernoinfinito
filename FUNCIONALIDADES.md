> **Atualização v0.5:** esta versão melhora a facilidade de conexão Google Drive, sem alterar a classificação das ferramentas de desenho: 56 bases, 51 parciais e 3 pendentes. Login de usuário final em poucos cliques **após** a configuração única do projeto OAuth pelo responsável pelo aplicativo. Veja `CONEXAO_GOOGLE.md`.

# Cobertura das 110 funcionalidades do manual Concepts (referência enviada)

**Legenda:** ✅ **Base funcional** = implementação própria utilizável; 🟠 **Parcial** = recurso aproximado ou limitado; ⬜ **Pendente** = ainda não implementado. Não significa equivalência técnica ou visual com o Concepts.

Este projeto é um editor independente. Recursos de assinatura, bibliotecas proprietárias, formatos `.concept/.concepts` e funções profissionais não são automaticamente reproduzidos.
**Contagem após as novas implementações:** 56 bases funcionais; 51 parciais; 3 pendentes (total 110). **Esses indicadores referem-se à presença de código, não a testes reais nem a paridade com Concepts.**

| Nº | Funcionalidade do manual | Estado | Situação nesta versão |
|---:|---|:---:|---|
| 1 | Tela infinita | 🟠 | Tela sem limite fixo; rotação e zoom independentes; impressão por artboard. |
| 2 | Traços vetoriais | 🟠 | Traços e propriedades em JSON; modelagem de caminhos simplificada |
| 3 | Mover o quadro (Pan) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 4 | Zoom de aproximação e afastamento | ✅ | Implementação própria disponível no editor ou na galeria. |
| 5 | Girar a tela | ✅ | Giro do quadro por botões, tecla R e gesto de dois dedos. |
| 6 | Roda de ferramentas e barra de ferramentas | ✅ | Ferramentas rápidas configuráveis e menu com ferramentas completas. |
| 7 | Barra de estado | ✅ | Exibe ferramenta, ampliação, rotação e total de objetos. |
| 8 | Tela cheia e interface limpa | 🟠 | Oculta barras do editor; fullscreen do sistema depende da janela |
| 9 | Desfazer e refazer | ✅ | Implementação própria disponível no editor ou na galeria. |
| 10 | 120 Hz e prévia do pincel por aproximação | 🟠 | Prévia circular do pincel via MouseRegion; depende do dispositivo e não garante 120 Hz. |
| 11 | Caneta comum (Pen) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 12 | Caneta-tinteiro (Fountain Pen) | 🟠 | Variação de largura por deslocamento; não reproduz tinta física. |
| 13 | Caneta dinâmica (Dynamic Pen) | 🟠 | Pressão, tilt e orientação gravados por ponto; resposta aproximada. |
| 14 | Caneta de largura fixa (Fixed Width) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 15 | Ferramenta Wire | ✅ | Largura visual compensada pelo zoom no editor; resultado de exportação pode variar. |
| 16 | Lápis macio (Soft Pencil) | 🟠 | Simulação translúcida, sem textura real de grafite |
| 17 | Lápis duro (Hard Pencil) | 🟠 | Pincel sólido, sem textura realista |
| 18 | Marcador (Marker) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 19 | Aerógrafo (Airbrush) | 🟠 | Desfoque de linha, sem motor de aerografia profissional |
| 20 | Aquarela (Watercolor) | 🟠 | Transparência simples, sem mistura de pigmentos |
| 21 | Preenchimento manual (Fill) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 22 | Linha pontilhada (Dotted) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 23 | Tamanho do pincel | ✅ | Implementação própria disponível no editor ou na galeria. |
| 24 | Opacidade do traço | ✅ | Implementação própria disponível no editor ou na galeria. |
| 25 | Suavização em tempo real | ✅ | Suavização ajustável aplicada aos pontos de traços livres. |
| 26 | Predefinições por ferramenta | ✅ | Predefinições por ferramenta, além de presets nomeados reutilizáveis. |
| 27 | Biblioteca de pincéis profissionais | ⬜ | Ainda não há biblioteca licenciada de texturas ou motor profissional equivalente. |
| 28 | Criação e troca de pincéis personalizados | 🟠 | Pincéis nomeados e suas propriedades; sem criação de ponta/texture raster complexa. |
| 29 | Roda de cores COPIC | 🟠 | Cartela de cores de referência inspirada em marcadores artísticos, não catálogo oficial completo. |
| 30 | Cores RGB | ✅ | Código RGB hexadecimal com ajuste de matiz e cor da amostra. |
| 31 | Cores HSL | ✅ | Controles reais de Matiz, Saturação e Luminosidade (HSLColor). |
| 32 | Conta-gotas / Color Picker | 🟠 | Lê a cor do objeto vetorial e pixels RGBA de imagens importadas, inclusive rotacionadas (sem distorção avançada). |
| 33 | Paletas pessoais, dinâmicas e compartilhadas | 🟠 | Paleta pessoal no arquivo, copiada junto ao documento, sem gerenciador global de paletas. |
| 34 | Seleção por laço (Lasso) | ✅ | Seleção por polígono com interseção de segmentos, vértices e limites de imagem/texto; evita selecionar só pelo centro. |
| 35 | Seletor de item (Item Picker) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 36 | Filtros de seleção | ✅ | Filtra por camada, texto, imagem, traço e itens bloqueados. |
| 37 | Mover, girar e redimensionar seleção | 🟠 | Mover por arrasto; escala/giro em passos via seleção |
| 38 | Escala x esticamento (Scale / Stretch) | ✅ | Esticamento nos eixos X/Y separado da escala uniforme. |
| 39 | Transformações de perspectiva, distorção e inclinação | 🟠 | Inclinação e perspectiva geométrica aproximada; sem deformação profissional de quatro cantos. |
| 40 | Agrupar e desagrupar | ✅ | Implementação própria disponível no editor ou na galeria. |
| 41 | Duplicar | ✅ | Implementação própria disponível no editor ou na galeria. |
| 42 | Bloquear elementos | ✅ | Implementação própria disponível no editor ou na galeria. |
| 43 | Espelhamento horizontal e vertical | ✅ | Implementação própria disponível no editor ou na galeria. |
| 44 | Realce da seleção | ✅ | Implementação própria disponível no editor ou na galeria. |
| 45 | Copiar e colar entre desenhos/aplicativos | 🟠 | JSON editável entre desenhos; seleção de um texto pode ser copiada como texto puro para outros programas. Sem colagem PNG externa. |
| 46 | Nudge: empurrar ou puxar linhas | 🟠 | Deslocamento de pontos por proximidade aproximado |
| 47 | Slice: borracha vetorial destrutiva | 🟠 | Recorta entre pontos com amostragem densa e limites refinados; ainda aproxima curvas complexas. |
| 48 | Máscara rígida (Hard Mask) | 🟠 | Camada de máscara não destrutiva com blend de subtração, efeito depende da ordem. |
| 49 | Máscara suave (Soft Mask) | 🟠 | Borracha de borda desfocada usando blend de subtração, sem máscaras avançadas. |
| 50 | Limpeza rápida por categoria | ✅ | Limpeza por camada, textos, traços, imagens, medição ou tudo, com confirmação. |
| 51 | Grades básicas e tipos de papel | 🟠 | Grades básicas e isométrica simplificada |
| 52 | Grades personalizadas | 🟠 | Espaçamento ajustável; sem customização completa de unidades |
| 53 | Grades de perspectiva 1, 2 e 3 pontos | 🟠 | Grade de perspectiva 1, 2 ou 3 pontos para referência; não são guias magnéticas 3D. |
| 54 | Snap (encaixe) | 🟠 | Snap aplicado às formas geométricas |
| 55 | Escala real de desenho | 🟠 | Escala de referência no documento, sem calibração física |
| 56 | Medidas de comprimento, área e ângulo | ✅ | Medida de segmentos e ângulos, área por contorno e dimensões da seleção. |
| 57 | Etiquetas de medição | 🟠 | Rótulos embutidos nos traços de medida/área; não permite editar independentemente. |
| 58 | Guias geométricas: reta, arco e ângulo | 🟠 | Formas diretas, sem alças dinâmicas de guia |
| 59 | Guias geométricas: retângulo e elipse | 🟠 | Retângulo/elipse desenhados diretamente |
| 60 | Reconhecimento de formas pelo gesto | 🟠 | Ao segurar a caneta, tenta converter reta, círculo/elipse ou retângulo simples. |
| 61 | Área de exportação (Artboard) | 🟠 | A4 ou 16:9; exportação por conteúdo/artboard |
| 62 | Criar e nomear camadas | ✅ | Implementação própria disponível no editor ou na galeria. |
| 63 | Modo automático de camadas | ✅ | Modo automático cria e escolhe camadas por família de ferramentas. |
| 64 | Modo manual de camadas | ✅ | Implementação própria disponível no editor ou na galeria. |
| 65 | Reordenar camadas | ✅ | Implementação própria disponível no editor ou na galeria. |
| 66 | Mostrar/ocultar camadas | ✅ | Implementação própria disponível no editor ou na galeria. |
| 67 | Modo foco (Focus Mode) | ✅ | Implementação própria disponível no editor ou na galeria. |
| 68 | Bloquear, duplicar, mesclar e excluir camadas | ✅ | Implementação própria disponível no editor ou na galeria. |
| 69 | Opacidade de camada | ✅ | Implementação própria disponível no editor ou na galeria. |
| 70 | Camadas especiais: fundo, grade e medições | 🟠 | Fundo e grade calculados separadamente dos objetos |
| 71 | Biblioteca de formas básicas | ✅ | Formas reutilizáveis na biblioteca: retângulo, elipse, triângulo, losango e seta. |
| 72 | Pacotes de objetos profissionais | 🟠 | Modelos básicos agrupados por mapas mentais, fluxogramas e geometria; sem pacotes comerciais. |
| 73 | Objetos criados pelo usuário | ✅ | Salvar seleção como objeto personalizado que pode ser reutilizado no mesmo documento. |
| 74 | Compartilhamento de pacotes pessoais | ✅ | Exportação/importação de modelo em JSON .ciobj, sem loja ou compartilhamento por link. |
| 75 | Pesquisa de imagens Pexels | ✅ | Busca de fotos por API oficial Pexels com chave gratuita configurada pelo usuário. |
| 76 | Importar fotografias JPG e PNG | ✅ | Implementação própria disponível no editor ou na galeria. |
| 77 | Importar arquivos PSD | 🟠 | Importa imagem composta de PSD RGB 8 bits sem compressão ou PackBits; camadas não preservadas. |
| 78 | Importação com escala de imagem | 🟠 | Redimensionamento proporcional na importação |
| 79 | Importar PDF de uma página | 🟠 | Importa PDF como imagens de páginas anotáveis e camadas editáveis de notas. |
| 80 | PDF com várias páginas | 🟠 | Máximo de 40 páginas por importação, numa tela vertical |
| 81 | Reorganizar, substituir e anotar páginas de PDF | 🟠 | Reorganização de páginas rasterizadas com deslocamento das notas cujo centro está na página; vínculo geométrico aproximado. |
| 82 | Exportar JPG | ✅ | Implementação própria disponível no editor ou na galeria. |
| 83 | Exportar PNG transparente | 🟠 | PNG comum e transparente; máscaras simplificadas |
| 84 | Exportar PDF vetorial ou rasterizado | 🟠 | PDF raster comum/multipágina e nova exportação vetorial para linhas e formas opacas; máscaras/texturas exigem raster. |
| 85 | Exportar SVG | 🟠 | SVG de caminhos básicos; texturas não equivalentes |
| 86 | Exportar DXF | 🟠 | DXF somente segmentos LINE |
| 87 | Exportar PSD | 🟠 | Exporta PSD RGB 8 bits sem compressão, achatado, sem camadas Photoshop. |
| 88 | Resolução entre 72 e 600 PPI | ✅ | Seleciona de 72 a 600 PPI com limite de memória para imagens. |
| 89 | Exportar tela, seleção ou artboard | ✅ | Exportação de área artboard, conteúdo total ou seleção em PNG/SVG. |
| 90 | Imprimir | ✅ | Implementação própria disponível no editor ou na galeria. |
| 91 | Galeria de desenhos | ✅ | Galeria com modelos editáveis (Cornell, mapa mental, plano de aula, revisão, semana), além de desenhos em branco. |
| 92 | Pastas, subpastas e projetos ilimitados | ✅ | Implementação própria disponível no editor ou na galeria. |
| 93 | Renomear, duplicar e excluir desenhos | ✅ | Implementação própria disponível no editor ou na galeria. |
| 94 | Agrupamento e ordenação na galeria | ✅ | Implementação própria disponível no editor ou na galeria. |
| 95 | Notas e informações de projeto | ✅ | Implementação própria disponível no editor ou na galeria. |
| 96 | Arquivos nativos .concept e .concepts | ⬜ | Arquivos .concept/.concepts são proprietários e não têm importação nativa; usa .ci.json. |
| 97 | Backup em nuvem | ✅ | Arquivos .ci.json no Drive, cópia .bak e backup exportável de todo o acervo .cibackup.json. |
| 98 | Sincronização entre Windows e Android | ✅ | Integração Drive com detecção de conflitos, duplicatas remotas, checksum no download e bloqueio enquanto o editor estiver aberto (OAuth não validado em aparelhos). |
| 99 | iCloud Drive no iOS | ⬜ | iCloud não é alvo: projeto específico para Windows/Android e Google Drive. |
| 100 | Busca de notas e desenhos | 🟠 | Busca por título, pasta, nota e textos digitados dentro do desenho; sem OCR de caligrafia. |
| 101 | Pressão, inclinação, velocidade e orientação da caneta | 🟠 | Grava pressão, inclinação e orientação, de acordo com os dados disponíveis da caneta. |
| 102 | Rejeição da palma da mão | 🟠 | Ignora eventos de toque quando stylus está ativo; rejeição real depende de drivers. |
| 103 | Função diferente para dedo e caneta | 🟠 | Modo dedo-pan / dedo-escrita, stylus desenha |
| 104 | Gestos multitoque configuráveis | ✅ | Zoom/rotação de dois dedos; gestos opcionais de três dedos (desfazer) e quatro (refazer). |
| 105 | Toque prolongado (Tap + Hold) | ✅ | Pressionar um item por 700 ms com caneta ativa sua seleção quando habilitado. |
| 106 | Atalhos de teclado | 🟠 | Ctrl+Z/Y alternativo Shift+Z, Ctrl+S/A/C/V/X/D, R e Esc; remapeamento não disponível. |
| 107 | Mouse, mesa Wacom e Surface Dial | 🟠 | Mouse e mesa que emite PointerEvents; sem Surface Dial |
| 108 | Tema escuro e tema claro | ✅ | Implementação própria disponível no editor ou na galeria. |
| 109 | Ajustes de fundo, unidade e tamanho da área | 🟠 | Fundo, medida aproximada, artboard |
| 110 | Modo apresentação, widgets e telas dobráveis | 🟠 | Apresentação com barras ocultas, botão sair e navegação por gestos; sem widget do sistema. |

> **Versão 0.3:** mais melhorias funcionais foram introduzidas em PDF, backup e Drive, além da interface clean. Os recursos parciais continuam assim classificados quando não reproduzem o funcionamento completo do Concepts.

> **Validação:** a lista é uma auditoria de código. Não foi possível executar `flutter analyze`, `flutter test`, build Windows/Android, autenticação OAuth ou teste de caneta real. Ferramentas básicas e parciais podem demandar ajustes. Recursos proprietários do Concepts não foram reproduzidos. As 110 funcionalidades **não estão todas completas**.

## O que realmente mudou na versão 0.4

- Melhorias nas funções 15, 32, 34, 45, 47, 84, 91 e 98, com código próprio.
- Funcionalidades de edição de texto e de modelos prontos também foram acrescentadas, embora não sejam linhas independentes das 110 funções do manual.
- **Não estão completas:** as 51 funções parciais continuam com limitações específicas descritas acima, e as 3 pendentes permanecem: biblioteca profissional proprietária equivalente, arquivos `.concept/.concepts` e iCloud para iOS.
- Estes números indicam **presença e escopo do código**; não são resultados de compilação ou teste em aparelho.

---

## Atualização v0.6.0 — alças de transformação

A seleção agora exibe uma caixa de edição com oito alças para esticar/redimensionar, um círculo externo para girar e possibilidade de mover o conjunto pelo interior. Funciona com mouse, toque e caneta; acompanha zoom e rotação do quadro. Shift + girar faz encaixe de 15° no PC. A transformação mantém IDs e arquivos editáveis `.ci.json`.

**Atenção:** esta melhoria não torna todas as 110 funções iguais ao Concepts. A classificação original de recursos parciais e pendentes permanece aplicável até haver testes adicionais e implementações correspondentes.
