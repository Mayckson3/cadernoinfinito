/// Catálogo único de nomes e categorias das ferramentas.
/// IDs internos são estáveis para não afetar o formato dos cadernos antigos.
class ToolCatalog {
  static const labels=<String,String>{
    'cloud':'Nuvem / balão de ideias','balloon':'Balão de fala',
    'rounded rectangle':'Caixa arredondada','capsule':'Cápsula','hexagon':'Hexágono',
    'dashed line':'Reta tracejada','vector curve':'Curva vetorial editável',
    'connector':'Conector curvo','elbow connector':'Conector em cotovelo',
    'straight connector':'Conector reto',
    'pen':'Caneta','fountain':'Caneta-tinteiro','dynamic':'Caneta dinâmica',
    'fixed':'Caneta de espessura fixa','wire':'Traço contínuo','soft pencil':'Lápis macio',
    'hard pencil':'Lápis duro','marker':'Marcador','airbrush':'Aerógrafo',
    'watercolor':'Aquarela','fill':'Preenchimento','dotted':'Pontilhado',
    'line':'Reta','arrow':'Seta','rectangle':'Retângulo','ellipse':'Elipse',
    'triangle':'Triângulo','compass':'Compasso (círculo por raio)','bezier':'Curva Bézier',
    'area':'Medir área','angle':'Medir ângulo','text':'Inserir texto','image':'Importar imagem/PDF','eyedropper':'Conta-gotas','diamond':'Losango',
    'measure':'Medir','select':'Selecionar','lasso':'Laço',
    'pan':'Mover tela','eraser':'Borracha','slice':'Recorte vetorial',
    'nudge':'Ajustar traços','mask':'Máscara de recorte','soft mask':'Máscara suave',
  };
  static String nameOf(String id)=>labels[id]??id;

  static const sections=<String,List<String>>{
      'Escrever e pintar':['pen','fountain','dynamic','fixed','soft pencil',
        'hard pencil','marker','wire','dotted','airbrush','watercolor'],
      'Desenhar formas':['line','arrow','rectangle','ellipse','triangle',
        'diamond','compass','bezier','fill'],
      'Mapas mentais':['cloud','balloon','rounded rectangle','capsule','hexagon',
        'connector','elbow connector','straight connector','dashed line','vector curve'],
      'Selecionar e modificar':['select','lasso','eraser','slice','nudge',
        'mask','soft mask'],
      'Inserir e medir':['text','image','eyedropper','measure','area','angle','pan'],
    };
}
