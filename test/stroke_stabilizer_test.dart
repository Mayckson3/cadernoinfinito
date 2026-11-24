import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/stroke_stabilizer.dart';
import 'package:caderno_infinito/widgets/board_painter.dart';

List<InkPoint> noisyLine() => [for(var i=0;i<=40;i++)
  InkPoint(i*2.0, i==0 || i==40 ? 0.0 : (i.isEven ? 1.0 : -1.0),
    .25+i/50, i/100, i/20)];

double rms(List<InkPoint> p) => math.sqrt(p.fold<double>(0,(s,v)=>s+v.y*v.y)/p.length);

void main() {
  test('Reduz tremor sem alterar pontas, quantidade, pressão ou dados originais', () {
    final points=noisyLine();
    final before=points.map((p)=>p.toJson()).toList();
    final stable=StrokeStabilizer.finish(points,zoom:1,strength:.75);
    expect(rms(stable),lessThan(rms(points)*.5));
    expect(stable.length,points.length);
    expect(stable.first.offset,points.first.offset);
    expect(stable.last.offset,points.last.offset);
    for(var i=0;i<points.length;i++) {
      expect(stable[i].p,points[i].p);
      expect(stable[i].tilt,points[i].tilt);
      expect(stable[i].angle,points[i].angle);
      expect(points[i].toJson(),before[i]);
      expect((stable[i].offset-points[i].offset).distance,lessThanOrEqualTo(2.2500001));
    }
  });
  test('Mantém o vértice e os dois lados de um canto intencional', () {
    final points=[for(var i=0;i<=10;i++)InkPoint(i*2.0,0),
      for(var i=1;i<=10;i++)InkPoint(20,i*2.0)];
    final stable=StrokeStabilizer.finish(points,zoom:1,strength:.75);
    expect(stable[10].offset,points[10].offset);
    for(var i=0;i<=10;i++) { expect(stable[i].y,closeTo(0,1e-8)); }
    for(var i=10;i<stable.length;i++) { expect(stable[i].x,closeTo(20,1e-8)); }
  });
  test('Curva fechada continua fechada e não se converte em reta', () {
    final points=[for(var i=0;i<40;i++)
      InkPoint(15*math.cos(i*math.pi/20),15*math.sin(i*math.pi/20)),InkPoint(15,0)];
    final stable=StrokeStabilizer.finish(points,zoom:1,strength:.75);
    expect(stable.first.offset,stable.last.offset);
    expect(stable.every((p)=>p.offset.distance>13),isTrue);
    expect(stable[10].y,greaterThan(13));
    expect(stable[20].x,lessThan(-13));
  });
  test('Nível zero e acentos mínimos preservam coordenadas', () {
    final points=noisyLine();
    final stable=StrokeStabilizer.finish(points,zoom:1,strength:0);
    expect(stable.map((p)=>p.toJson()).toList(),points.map((p)=>p.toJson()).toList());
    final tiny=[InkPoint(0,0),InkPoint(.4,.5),InkPoint(1,0)];
    expect(StrokeStabilizer.finish(tiny,zoom:1).map((p)=>p.offset).toList(),
      tiny.map((p)=>p.offset).toList());
    expect(StrokeStabilizer.finish([InkPoint(0,0,.4)],zoom:1).single.p,.4);
    expect(StrokeStabilizer.finish([],zoom:1),isEmpty);
  });
  test('Deslocamento em tela é equivalente em diferentes níveis de zoom', () {
    final points=noisyLine();
    final a=StrokeStabilizer.finish(points,zoom:1,strength:.75);
    final b=StrokeStabilizer.finish(points.map((p)=>InkPoint(p.x/4,p.y/4,p.p)).toList(),zoom:4,strength:.75);
    for(var i=0;i<a.length;i++) {
      expect(b[i].x*4,closeTo(a[i].x,1e-8));
      expect(b[i].y*4,closeTo(a[i].y,1e-8));
    }
  });
  test('Amostras repetidas e grandes intervalos não criam valores inválidos', () {
    final points=[InkPoint(0,0),InkPoint(0,0,.2),InkPoint(1,1),
      InkPoint(200,200),InkPoint(201,200),InkPoint(201,200)];
    final stable=StrokeStabilizer.finish(points,zoom:1,strength:1);
    expect(stable.every((p)=>p.x.isFinite && p.y.isFinite),isTrue);
    expect(stable[2].offset,points[2].offset);
    expect(stable[3].offset,points[3].offset);
  });
  test('Filtro é exclusivo de pincéis contínuos e resultado permanece editável', () {
    for(final tool in ['pen','fixed','fountain','dynamic','marker','hard pencil']) {
      expect(StrokeStabilizer.supports(tool),isTrue);
    }
    for(final tool in ['rectangle','line','bezier','fill','area','eraser','mask','dotted','lasso']) {
      expect(StrokeStabilizer.supports(tool),isFalse);
    }
    final stroke=InkElement(layerId:'main',points:StrokeStabilizer.finish(noisyLine(),zoom:1),
      meta:{'stabilizedInk':true});
    final restored=InkElement.fromJson(stroke.toJson());
    expect(restored.meta['stabilizedInk'],isTrue);
    expect(restored.points.map((p)=>p.toJson()).toList(),stroke.points.map((p)=>p.toJson()).toList());
  });
  test('200% remove ondulações largas além da estabilização natural', () {
    final raw=[for(var i=0;i<=100;i++) InkPoint(i.toDouble(),
      3*math.sin(i*math.pi/10),.2+i/125)];
    final natural=StrokeStabilizer.finish(raw,zoom:1,strength:.75);
    final strong=StrokeStabilizer.finish(raw,zoom:1,strength:2);
    expect(rms(strong),lessThan(rms(natural)*.35));
    expect(strong.length,raw.length);
    expect(strong.first.offset,raw.first.offset);
    expect(strong.last.offset,raw.last.offset);
    for(var i=0;i<raw.length;i++) {expect(strong[i].p,raw[i].p);}
  });
  test('200% conserva cantos e laços pequenos', () {
    final corner=[for(var i=0;i<=10;i++) InkPoint(i*2.0,0),
      for(var i=1;i<=10;i++) InkPoint(20,i*2.0)];
    final strong=StrokeStabilizer.finish(corner,zoom:1,strength:2);
    expect(strong[10].offset,corner[10].offset);
    for(var i=0;i<=10;i++) {expect(strong[i].y,closeTo(0,1e-7));}
    for(var i=10;i<strong.length;i++) {expect(strong[i].x,closeTo(20,1e-7));}
    final loop=[for(var i=0;i<40;i++) InkPoint(5*math.cos(i*math.pi/20),
      5*math.sin(i*math.pi/20)),InkPoint(5,0)];
    final polished=StrokeStabilizer.finish(loop,zoom:1,strength:2);
    expect(polished.first.offset,polished.last.offset);
    expect(polished.every((p)=>p.offset.distance>4),isTrue);
  });
  test('200% não deixa lacunas no contorno de pressão e preserva as pontas', () {
    final stroke=InkElement(layerId:'main',points:[InkPoint(0,0,.2),
      InkPoint(10,0,1),InkPoint(20,0,.3),InkPoint(30,0,1)]);
    final path=BoardRenderer.polishedVariablePath(stroke,(i)=>2+stroke.points[i].p*4);
    for(var i=0;i<=30;i++) {
      expect(path.contains(InkPoint(i.toDouble(),0).offset),isTrue);
    }
    expect(path.getBounds().left,lessThan(0));
    expect(path.getBounds().right,greaterThan(30));
    expect(path.contains(InkPoint(15,10).offset),isFalse);
  });
  test('Nível forte é limitado a 200% e mantém os atributos de tinta', () {
    final raw=noisyLine();
    final a=StrokeStabilizer.finish(raw,zoom:1,strength:2);
    final b=StrokeStabilizer.finish(raw,zoom:1,strength:10);
    expect(a.map((p)=>p.toJson()).toList(),b.map((p)=>p.toJson()).toList());
    final c=StrokeStabilizer.finish(raw.map((p)=>InkPoint(p.x/4,p.y/4,p.p,p.tilt,p.angle)).toList(),zoom:4,strength:2);
    for(var i=0;i<a.length;i++) {
      expect(c[i].x*4,closeTo(a[i].x,1e-7));
      expect(c[i].y*4,closeTo(a[i].y,1e-7));
      expect(a[i].tilt,raw[i].tilt);
      expect(a[i].angle,raw[i].angle);
    }
  });
}
