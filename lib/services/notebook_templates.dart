import '../models/sketch.dart';

/// Modelos 100% editáveis: são elementos vetoriais comuns do próprio app.
/// Não requerem downloads, imagens externas ou formatos proprietários.
class NotebookTemplates {
  static const names = <String>[
    'Em branco',
    'Cornell — anotações',
    'Mapa mental',
    'Plano de aula',
    'Revisão de estudos',
    'Planejamento semanal',
  ];

  static const descriptions = <String, String>{
    'Em branco': 'Página livre com a grade escolhida.',
    'Cornell — anotações': 'Pistas, ideias principais e resumo.',
    'Mapa mental': 'Tema central e ramificações organizadas.',
    'Plano de aula': 'Objetivos, conteúdos, atividades e avaliação.',
    'Revisão de estudos': 'Teoria, exemplos, dúvidas e revisão.',
    'Planejamento semanal': 'Quadro de tarefas de segunda a domingo.',
  };

  static Sketch create({required String title, required String folder,
      String template='Em branco', String grid='pautado'}) {
    if (!names.contains(template)) {
      throw ArgumentError.value(template, 'template', 'Modelo desconhecido');
    }
    final d = Sketch(title:title, folder:folder, grid:grid);
    if (template == 'Em branco') return d;
    d.grid='nenhum';
    d.artboardW=794;
    d.artboardH=1123;
    final base = d.layers.first.id;
    const ink = 0xff273449, blue = 0xff5273ac, grey = 0xff9eacbf;

    void text(String value,double x,double y,{double size=19,int color=ink,
      double width=650}) => d.elements.add(InkElement(layerId:base,type:'text',
      text:value,x:x,y:y,w:width,h:size*1.6,size:size,color:color));
    void line(double x,double y,double x2,double y2,{int color=grey,
      double size=1.5}) => d.elements.add(InkElement(layerId:base,
      tool:'line',size:size,color:color,
      points:[InkPoint(x,y),InkPoint(x2,y2)]));
    void box(double x,double y,double w,double h,{int color=blue,
      double size=1.8}) => d.elements.add(InkElement(layerId:base,
      tool:'rectangle',color:color,size:size,
      points:[InkPoint(x,y),InkPoint(x+w,y+h)]));
    void circle(double x,double y,double w,double h,{int color=blue}) =>
      d.elements.add(InkElement(layerId:base,tool:'ellipse',color:color,
        size:2.4,points:[InkPoint(x,y),InkPoint(x+w,y+h)]));

    text(title,45,30,size:28,color:ink);
    line(45,85,750,85,size:2);
    switch (template) {
      case 'Cornell — anotações':
        text('PALAVRAS-CHAVE',55,112,size:15,color:blue);
        text('ANOTAÇÕES',255,112,size:15,color:blue);
        line(235,100,235,870);
        line(45,883,750,883);
        text('RESUMO',55,903,size:15,color:blue);
        for(var y=165.0;y<865;y+=42) line(52,y,744,y,size:.7);
        for(var y=955.0;y<1080;y+=36) line(52,y,744,y,size:.7);
        break;
      case 'Mapa mental':
        circle(262,400,275,138);
        text('TEMA CENTRAL',305,445,size:23,color:blue,width:200);
        const centers = <(double,double)>[
          (80,175),(490,175),(45,705),(480,705)];
        final labels = ['Conceito 1','Conceito 2','Exemplo','Conclusão'];
        for(var i=0;i<centers.length;i++) {
          final (x,y)=centers[i];
          circle(x,y,230,105,color:grey);
          text(labels[i],x+25,y+35,size:17,color:ink,width:180);
          line(x+115,y+105/2,400,468,color:grey);
        }
        break;
      case 'Plano de aula':
        final sections = [
          ('OBJETIVOS',110.0,175.0),
          ('CONTEÚDOS E HABILIDADES',300.0,200.0),
          ('DESENVOLVIMENTO E METODOLOGIA',535.0,310.0),
          ('AVALIAÇÃO E ENCAMINHAMENTOS',880.0,175.0),
        ];
        for(final (label,y,height) in sections) {
          box(45,y,705,height,color:grey,size:1.5);
          text(label,60,y+15,size:15,color:blue);
        }
        break;
      case 'Revisão de estudos':
        final parts=[('O QUE PRECISO ENTENDER',110.0,300.0),
          ('EXEMPLOS / APLICAÇÕES',425.0,255.0),
          ('DÚVIDAS / ERROS',695.0,230.0),
          ('PRÓXIMA REVISÃO',940.0,120.0)];
        for(final (label,y,height) in parts){
          box(45,y,705,height,color:grey,size:1.4);
          text(label,60,y+15,size:16,color:blue);
        }
        break;
      case 'Planejamento semanal':
        const days=['Segunda','Terça','Quarta','Quinta','Sexta','Sábado','Domingo'];
        for(var i=0;i<days.length;i++) {
          final y=113.0+i*139;
          box(45,y,705,128,color:grey,size:1.25);
          text(days[i],60,y+15,size:18,color:blue);
          line(45,y+50,750,y+50,size:1);
        }
        break;
    }
    return d;
  }
}
