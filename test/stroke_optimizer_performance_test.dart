import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/stroke_optimizer.dart';
import 'package:caderno_infinito/widgets/board_painter.dart';

void main() {
  test('Amostragem ignora micromovimento, conserva pressão e zoom', () {
    final a=InkPoint(0,0,1);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(.5,0,1),zoom:1),false);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(1.3,0,1),zoom:1),true);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(.5,0,1),zoom:1,fastMode:false),true);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(.5,0,1),zoom:1,fastMode:true),false);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(.1,0,.7),zoom:1),true);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(.4,0,1),zoom:4),true);
    expect(StrokeOptimizer.shouldSample(a,InkPoint(0,0,1),zoom:0),false);
  });

  test('Reta é reduzida sem mover as extremidades', () {
    final points=[for(var i=0;i<=100;i++)InkPoint(i.toDouble(),0)];
    final reduced=StrokeOptimizer.simplify(points);
    expect(reduced.length,2);
    expect(reduced.first.x,0);
    expect(reduced.last.x,100);
  });

  test('Curva em ângulo mantém o vértice e alteração de pressão', () {
    final points=[InkPoint(0,0),InkPoint(5,0),InkPoint(10,0),
      InkPoint(10,7),InkPoint(10,15)];
    final reduced=StrokeOptimizer.simplify(points,tolerance:.2);
    expect(reduced.any((p)=>p.x==10 && p.y==0),true);
    final pressured=[InkPoint(0,0,1),InkPoint(5,0,.2),InkPoint(10,0,1)];
    expect(StrokeOptimizer.simplify(pressured,tolerance:.5).length,3);
  });

  test('Ferramentas geométricas não são simplificadas manualmente', () {
    expect(StrokeOptimizer.canSimplify('rectangle'),false);
    expect(StrokeOptimizer.canSimplify('compass'),false);
    expect(StrokeOptimizer.canSimplify('pen'),true);
    expect(StrokeOptimizer.canSimplify('dynamic'),true);
  });

  test('Quadro não redesenha sem alterações visuais relevantes', () {
    final doc=Sketch();
    final first=BoardPainter(doc:doc,pan:Offset.zero,zoom:1,revision:1);
    final unchanged=BoardPainter(doc:doc,pan:Offset.zero,zoom:1,revision:1);
    expect(unchanged.shouldRepaint(first),false);
    expect(BoardPainter(doc:doc,pan:const Offset(10,0),zoom:1,revision:1)
      .shouldRepaint(first),true);
    expect(BoardPainter(doc:doc,pan:Offset.zero,zoom:1,revision:2)
      .shouldRepaint(first),true);
    expect(BoardPainter(doc:doc,pan:Offset.zero,zoom:1,revision:1,strokeFrame:2)
      .shouldRepaint(first),true);
    expect(BoardPainter(doc:doc,pan:Offset.zero,zoom:1,revision:1,
      onlyLayerId:doc.layers.first.id).shouldRepaint(first),true);
  });
}
