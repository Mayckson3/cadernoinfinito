import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:caderno_infinito/widgets/layer_preview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/viewport_fit.dart';
import 'package:caderno_infinito/services/selection_deletion.dart';
import 'package:caderno_infinito/services/advanced_tools.dart';
import 'package:caderno_infinito/services/text_geometry.dart';

void main() {
  test('Zoom enquadra o conteúdo mantendo o centro', () {
    final area=Rect.fromLTWH(100,200,400,150);
    final fit=ViewportFit.compute(area,const Size(800,600));
    expect(fit,isNotNull);
    expect(fit!.zoom,closeTo(1.82,.001));
    expect(100*fit.zoom+fit.pan.dx,closeTo(36,.01));
    expect(200*fit.zoom+fit.pan.dy,closeTo(163.5,.01));
  });

  test('Enquadramento respeita elemento com dimensões baixas e visor vazio', () {
    expect(ViewportFit.compute(Rect.zero,Size.zero),isNull);
    final spot=ViewportFit.compute(Rect.fromLTWH(23,27,0,0),
        const Size(320,200));
    expect(spot,isNotNull);
    expect(spot!.zoom,12);
  });

  test('Retirada por arrastar ignora camada e elemento bloqueados', () {
    final current=InkLayer(name:'Editável');
    final locked=InkLayer(name:'Bloqueada',locked:true);
    final doc=Sketch(layers:[current,locked],elements:[
      InkElement(layerId:current.id,id:'excluir',points:[InkPoint(0,0)]),
      InkElement(layerId:current.id,id:'objeto-travado',locked:true,points:[InkPoint(1,1)]),
      InkElement(layerId:locked.id,id:'camada-travada',points:[InkPoint(2,2)]),
    ]);
    expect(SelectionDeletion.removeEditable(doc,{'excluir','objeto-travado','camada-travada'}),1);
    expect(doc.elements.map((e)=>e.id),containsAll(['objeto-travado','camada-travada']));
  });

  test('Triângulo livre com vértices preserva orientação', () {
    final path=<InkPoint>[];
    const a=Offset(5,15),b=Offset(170,42),c=Offset(60,160);
    void edge(Offset start,Offset finish) {
      for(var i=0;i<=15;i++) {
        final p=Offset.lerp(start,finish,i/15)!;
        path.add(InkPoint(p.dx,p.dy));
      }
    }
    edge(a,b);edge(b,c);edge(c,a);
    expect(AdvancedTools.recognizeShape(path),'triangle');
    final points=AdvancedTools.regularizeShape(path,'triangle');
    expect(points.length,3);
    final vertices=points.map((p)=>p.offset).toList();
    expect(vertices.any((p)=>(p-a).distance<4),true);
    expect(vertices.any((p)=>(p-b).distance<4),true);
    expect(vertices.any((p)=>(p-c).distance<4),true);
  });

  test('Reta inclinada para cima mantém sua direção', () {
    final path=[for(var i=0;i<=15;i++) InkPoint(i*10.0,140-i*8.0)];
    expect(AdvancedTools.recognizeShape(path),'line');
    final points=AdvancedTools.regularizeShape(path,'line');
    expect(points.last.y,lessThan(points.first.y));
  });

  test('Círculo levemente irregular passa a ter eixos iguais', () {
    final path=[for(var i=0;i<=48;i++)InkPoint(
      110+49*math.cos(i*math.pi/24),110+51*math.sin(i*math.pi/24))];
    expect(AdvancedTools.recognizeShape(path),'ellipse');
    final points=AdvancedTools.regularizeShape(path,'ellipse');
    expect((points[1].x-points[0].x).abs(),closeTo((points[1].y-points[0].y).abs(),.001));
  });

  testWidgets('Miniatura de camada desenha sem alterar os objetos', (tester) async {
    final layer=InkLayer(name:'Desenho');
    final doc=Sketch(layers:[layer],elements:[InkElement(layerId:layer.id,
      tool:'line',points:[InkPoint(10,10),InkPoint(100,60)])]);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Center(child:
      SizedBox(width:80,height:55,child:LayerPreview(doc:doc,layerId:layer.id))))));
    expect(find.byType(LayerPreview),findsOneWidget);
    expect(tester.takeException(),isNull);
    expect(doc.elements.length,1);
  });

  testWidgets('Caixa de texto usa métricas reais de caracteres e quebras', (tester) async {
    final short=TextGeometry.measure('Oi',20);
    final long=TextGeometry.measure('Geografia',20);
    final multiline=TextGeometry.measure('Oi\nOi',20);
    expect(short.width,lessThan(long.width));
    expect(multiline.height,greaterThan(short.height));
    final item=InkElement(layerId:'t',type:'text',text:'Oi',
      size:20,x:37,y:65,w:short.width,h:short.height);
    expect(item.bounds.left,37);
    expect(item.bounds.top,65);
    expect(item.bounds.width,closeTo(short.width,.001));
    expect(item.bounds.height,closeTo(short.height,.001));
  });
}
