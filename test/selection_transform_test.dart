import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/selection_transform.dart';

void main() {
  InkElement rectangle(String id, double x, double y, double w, double h) =>
      InkElement(id:id,layerId:'layer',tool:'rectangle',size:2,points:[
        InkPoint(x,y),InkPoint(x+w,y+h)]);

  test('alças projetadas acompanham zoom, panorama e giro do quadro', () {
    const pan=Offset(50, 90);
    const point=Offset(30, 40);
    final screen=SelectionTransform.toScreen(point,pan,2,math.pi/2);
    expect(screen.dx,closeTo(-30,1e-7));
    expect(screen.dy,closeTo(150,1e-7));
    final world=SelectionTransform.toWorld(screen,pan,2,math.pi/2);
    expect(world.dx,closeTo(point.dx,1e-7));
    expect(world.dy,closeTo(point.dy,1e-7));
    const bounds=Rect.fromLTWH(10,10,100,70);
    final positions=SelectionTransform.handlePositions(bounds,
      pan:pan,zoom:2,viewRotation:math.pi/2);
    expect(SelectionTransform.hitTest(positions[SelectionHandle.rotate]!,bounds,
      pan:pan,zoom:2,viewRotation:math.pi/2),SelectionHandle.rotate);
    expect(SelectionTransform.hitTest(positions[SelectionHandle.southEast]!,bounds,
      pan:pan,zoom:2,viewRotation:math.pi/2),SelectionHandle.southEast);
  });

  test('redimensionar canto mantém lado oposto e IDs de cada objeto', () {
    const rect=Rect.fromLTWH(10, 20, 100, 80);
    final target=SelectionTransform.resizedBounds(rect,
        SelectionHandle.southEast,const Offset(210,180));
    expect(target.topLeft,rect.topLeft);
    expect(target.width,200);
    expect(target.height,160);
    final original=rectangle('original',20,30,50,40);
    final result=SelectionTransform.resize([original],rect,target).single;
    expect(result.id,'original');
    expect(result.points.first.x,30);
    expect(result.points.first.y,40);
    expect(result.points.last.x,130);
    expect(result.points.last.y,120);
    expect(original.points.first.x,20); // não altera o snapshot anterior
  });

  test('alça lateral só altera a dimensão correspondente', () {
    const original=Rect.fromLTWH(20,30,100,80);
    final target=SelectionTransform.resizedBounds(original,
        SelectionHandle.east,const Offset(190,999));
    expect(target.left,20);
    expect(target.top,30);
    expect(target.right,190);
    expect(target.bottom,110);
  });

  test('movimentação preserva dados, camada e imagem', () {
    final input=InkElement(id:'img',layerId:'one',type:'image',data:'data:image/png;base64,AA',
        x:30,y:40,w:80,h:90,rotation:.3,group:'g');
    final result=SelectionTransform.translate([input],const Offset(20,-10)).single;
    expect(result.x,50);
    expect(result.y,30);
    expect(result.w,80);
    expect(result.group,'g');
    expect(result.rotation,.3);
    expect(input.x,30);
  });

  test('rotação de texto atualiza orientação e mantém o centro orbital', () {
    final original=InkElement(id:'txt',layerId:'one',type:'text',text:'Olá',
        x:70,y:40,w:20,h:20);
    final updated=SelectionTransform.rotate([original],const Offset(50,50),math.pi/2).single;
    expect(updated.x,40);
    expect(updated.y,70);
    expect(updated.rotation,closeTo(math.pi/2,1e-7));
    expect(updated.text,'Olá');
  });

  test('seleção de vários objetos gira como conjunto, sem alterar originais', () {
    final a=rectangle('a',0,0,10,10);
    final b=rectangle('b',100,0,10,10);
    final items=SelectionTransform.rotate([a,b],const Offset(55,5),math.pi);
    // Retângulos permanecem definidos por dois cantos e pelo ângulo.
    // A rotação de 180° troca os CENTROS visuais das duas figuras;
    // não precisamos inverter os pontos de controle para desenhá-las.
    expect(items[0].bounds.center.dx,closeTo(105,1e-7));
    expect(items[1].bounds.center.dx,closeTo(5,1e-7));
    expect(items[0].bounds.center.dy,closeTo(5,1e-7));
    expect(items[1].bounds.center.dy,closeTo(5,1e-7));
    expect(items[0].rotation,closeTo(math.pi,1e-7));
    expect(items[1].rotation,closeTo(math.pi,1e-7));
    expect(items[0].id,'a');
    expect(items[1].id,'b');
    expect(a.points.first.x,0);
    expect(b.points.first.x,100);
    expect(a.rotation,0);
    expect(b.rotation,0);
  });

  test('traço livre gira seus pontos sem alterar o original', () {
    final line=InkElement(id:'linha',layerId:'layer',
      tool:'pen',points:[InkPoint(0,0),InkPoint(10,0)]);
    final rotated=SelectionTransform.rotate([line],const Offset(5,0),math.pi).single;
    expect(rotated.points.first.x,closeTo(10,1e-7));
    expect(rotated.points.last.x,closeTo(0,1e-7));
    expect(rotated.points.first.y,closeTo(0,1e-7));
    expect(rotated.rotation,0); // traços livres têm pontos rotacionados
    expect(line.points.first.x,0);
    expect(line.points.last.x,10);
  });

  test('formas geométricas guardam rotação e limites visuais corretos', () {
    final original=rectangle('shape',10,20,80,40);
    final next=SelectionTransform.rotate([original],const Offset(50,40),math.pi/2).single;
    expect(next.rotation,closeTo(math.pi/2,1e-7));
    expect(next.bounds.width,closeTo(42,1e-6));
    expect(next.bounds.height,closeTo(82,1e-6));
    // Os dois pontos base preservam o formato editável.
    expect(next.points.length,2);
    expect(original.rotation,0);
  });

  test('redimensionamento não inverte nem colapsa a caixa', () {
    const initial=Rect.fromLTWH(10,10,100,80);
    final next=SelectionTransform.resizedBounds(initial,
        SelectionHandle.northWest,const Offset(1000,1000));
    expect(next.width,greaterThanOrEqualTo(4));
    expect(next.height,greaterThanOrEqualTo(4));
    expect(next.right,initial.right);
    expect(next.bottom,initial.bottom);
  });
}

// Testes complementares de proporção estão no pacote v0.8.
