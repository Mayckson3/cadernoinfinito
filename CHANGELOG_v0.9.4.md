# Caderno Infinito 0.9.4 — Menu radial de caneta

## Novo: gestos rápidos sem abrir a barra de ferramentas

- **Segurar a caneta** sobre o quadro por ~480 ms, sem arrastar, mostra um menu radial compacto.
- **Arrastar até o ícone e soltar** escolhe a função em uma única interação.
- Dez ações com ícones e nomes claros: **Caneta, Marcador, Borracha, Selecionar, Laço, Mover quadro, Desfazer, Refazer, Escolher cor e Espessura**.
- O comando destacado exibe o nome no centro do menu. Sem seleção ao soltar, o menu desaparece sem executar ação.
- O menu se ajusta às bordas e ao tamanho da tela; a detecção é feita sem redesenhar o quadro a cada movimento.
- Feedback tátil quando disponível, com haptics somente ao abrir e ao mudar de opção.
- **Windows:** botão direito do mouse abre o mesmo menu sem esperar, útil para canetas identificadas como mouse.
- **Android:** opção de permitir o gesto também com o dedo (desligada por padrão para evitar a palma da mão).
- Três opções em *Precisão / Gestos* para ligar/desligar menu radial, toque com dedo e botão direito do mouse.
- O menu pode ser aberto mesmo quando Texto, Imagem ou Conta-gotas estiverem selecionados; um toque rápido continua executando sua função no ponto escolhido.

## Segurança, compatibilidade e leveza

- Mantidos os gestos de dois dedos, botões laterais e escrita sensível à pressão da 0.9.3.
- Movimento superior a 9 px antes de abrir cancela a espera: escrever continua sem atraso perceptível.
- Não abre sobre a barra de atalhos ou o minimapa, nem enquanto se arrastam alças de seleção.
- Um segundo contato ou evento de cancelamento interrompe o menu sem executar ferramenta.
- Suspender o aplicativo cancela o menu e as esperas pendentes.
- Impede pontos solitários e camadas automáticas vazias ao abrir o menu.
- Não são adicionadas dependências Flutter externas, serviços de rede ou imagens pesadas.
- Preferências do menu são guardadas no próprio caderno; arquivos `.ci.json` anteriores seguem compatíveis.
- Testes adicionados para direção dos ícones, limites da tela, cancelamento e interface visual.

## Validação

O projeto fonte completo e seus testes foram revisados estruturalmente. **Não foi possível rodar `flutter analyze`, `flutter test`, compilar APK/EXE ou testar uma caneta física neste ambiente.** Execute `04_VERIFICAR_NO_C.cmd` no seu Windows antes de instalar o aplicativo.
