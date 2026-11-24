# Caderno Infinito 0.9.5 — Instruções

## Menu da caneta

Segure a ponta imóvel por aproximadamente 0,5 s, arraste para um dos **ícones** do círculo e solte. A ação destacada mostra o nome no centro. Soltar sem escolher cancela. No Windows, também é possível segurar o botão direito do mouse e arrastar.

A ação usada por último recebe um pequeno ponto discreto. A cor de destaque identifica a ação sobre a qual a caneta está posicionada.

## Personalizar

Abra **Grade, precisão e página > Personalizar ícones do menu radial**. Use + para adicionar, – para retirar e as setas para escolher a ordem. Entre 4 e 10 ações. Para voltar ao padrão, toque em **Restaurar padrão**.

No mesmo painel, altere **Vibração discreta no menu radial**. Os recursos ficam salvos por caderno.

## Compilar EXE e APK

1. Extraia este ZIP completo, sem sobrepor os arquivos de outro projeto.
2. Execute `04_VERIFICAR_NO_C.cmd`.
3. Execute `01_COMPILAR_TUDO_NO_C.cmd`.
4. Os scripts copiam o projeto para `%USERPROFILE%\ci095_full` antes de compilar. Os resultados ficam em `dist`.

**Não compile dentro de `E:\My Drive`**: links simbólicos de plugins podem falhar. OAuth Google continua exigindo as credenciais do projeto Google Cloud. O pacote contém o código fonte; não contém executáveis gerados.

**Validação:** arquivos e estrutura conferidos; testes e compilação Flutter não executados neste ambiente. Faça backup dos seus cadernos antes de instalar outra versão.
