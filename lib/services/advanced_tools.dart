import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../models/sketch.dart';
import 'mind_map_vectors.dart';

/// Ferramentas independentes de plataforma. Formato versionado e editável.
class AdvancedTools {
  static double length(List<InkPoint> points) {
    var result = 0.0;
    for (var i = 1; i < points.length; i++) {
      result += (points[i].offset - points[i - 1].offset).distance;
    }
    return result;
  }

  static double area(List<InkPoint> points) {
    if (points.length < 3) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p = points[i], q = points[(i + 1) % points.length];
      total += p.x * q.y - q.x * p.y;
    }
    return total.abs() / 2;
  }

  static double angleDegrees(Offset origin, Offset end) =>
      (math.atan2(end.dy - origin.dy, end.dx - origin.dx) * 180 / math.pi + 360) % 360;

  /// Recupera uma figura geométrica de gesto com pausa. Conserva os pontos originais
  /// caso o reconhecimento não alcance nível mínimo de confiança.
  static String? recognizeShape(List<InkPoint> points) {
    if (points.length < 8) return null;
    final rect = bounds(points);
    final diagonal = math.max(1.0, math.sqrt(rect.width * rect.width + rect.height * rect.height));
    final first = points.first.offset, last = points.last.offset;
    final close = (first - last).distance < diagonal * .2;
    final chord = (last - first).distance;
    final travel = length(points);
    if (!close && travel > 0 && chord / travel > .92) return 'line';
    if (!close) return null;
    if (rect.width < 12 || rect.height < 12) return null;
    var circleError = 0.0;
    for (final p in points) {
      final rx = (p.x - rect.center.dx) / (rect.width / 2);
      final ry = (p.y - rect.center.dy) / (rect.height / 2);
      circleError += (math.sqrt(rx * rx + ry * ry) - 1).abs();
    }
    if (circleError / points.length < .20) return 'ellipse';
    // A trajetória de um retângulo passa perto das quatro bordas.
    var edgeError = 0.0;
    for (final p in points) {
      edgeError += [
        (p.x - rect.left).abs(), (p.x - rect.right).abs(),
        (p.y - rect.top).abs(), (p.y - rect.bottom).abs()
      ].reduce(math.min) / diagonal;
    }
    if (edgeError / points.length < .045) return 'rectangle';
    // Um triângulo desenhado livremente pode apontar para qualquer direção.
    // Procura 3 vértices e exige que os pontos sigam suas 3 arestas.
    final corners=_triangleCorners(points);
    if(corners!=null && _triangleError(points,corners,diagonal)<.055) {
      return 'triangle';
    }
    return null;
  }

  static double _segmentDistance(Offset p, Offset a, Offset b) {
    final ab=b-a;
    final len=ab.dx*ab.dx+ab.dy*ab.dy;
    if(len<1e-8)return (p-a).distance;
    final t=((p-a).dx*ab.dx+(p-a).dy*ab.dy)/len;
    return (p-(a+ab*t.clamp(0.0,1.0).toDouble())).distance;
  }

  static double _triangleError(List<InkPoint> points,List<Offset> vertices,double diag) {
    var total=0.0;
    for(final point in points) {
      final p=point.offset;
      total+=math.min(_segmentDistance(p,vertices[0],vertices[1]),
        math.min(_segmentDistance(p,vertices[1],vertices[2]),
                 _segmentDistance(p,vertices[2],vertices[0])));
    }
    return total/(points.length*diag);
  }

  static List<Offset>? _triangleCorners(List<InkPoint> points) {
    if(points.length<8)return null;
    // Amostragem limita o custo mesmo em rabiscos de milhares de pontos.
    final sample=<Offset>[];
    final step=math.max(1,(points.length/26).ceil());
    for(var i=0;i<points.length;i+=step){sample.add(points[i].offset);}
    sample.add(points.last.offset);
    var maximum=0.0;
    List<Offset>? triangle;
    for(var a=0;a<sample.length-2;a++) {
      for(var b=a+1;b<sample.length-1;b++) {
        for(var c=b+1;c<sample.length;c++) {
          final ab=sample[b]-sample[a],ac=sample[c]-sample[a];
          final area=(ab.dx*ac.dy-ab.dy*ac.dx).abs();
          if(area>maximum) {
            maximum=area;
            triangle=[sample[a],sample[b],sample[c]];
          }
        }
      }
    }
    final r=bounds(points);
    if(triangle==null || maximum<r.width*r.height*.28)return null;
    return triangle;
  }

  /// Converte o gesto livre numa geometria perfeita, mantendo orientação,
  /// centro e a proporção observada. Quadrados/círculos quase regulares são
  /// ajustados a lados/eixos iguais, sem achatar retângulos nem elipses.
  static List<InkPoint> regularizeShape(List<InkPoint> source,String shape) {
    if(source.isEmpty)return <InkPoint>[];
    if(shape=='line')return [
      InkPoint(source.first.x,source.first.y),
      InkPoint(source.last.x,source.last.y),
    ];
    if(shape=='triangle') {
      final triangle=_triangleCorners(source);
      if(triangle!=null) {
        return triangle.map((v)=>InkPoint(v.dx,v.dy)).toList();
      }
    }
    final rect=bounds(source);
    final ratio=rect.width/math.max(rect.height,1e-9);
    var adjusted=rect;
    if((shape=='ellipse' && ratio>.82 && ratio<1.22) ||
        (shape=='rectangle' && ratio>.87 && ratio<1.15)) {
      final side=(rect.width+rect.height)/2;
      adjusted=Rect.fromCenter(center:rect.center,width:side,height:side);
    }
    return [InkPoint(adjusted.left,adjusted.top),
      InkPoint(adjusted.right,adjusted.bottom)];
  }

  static Rect bounds(List<InkPoint> points) {
    var left = points.first.x, right = left;
    var top = points.first.y, bottom = top;
    for (final p in points) {
      left = math.min(left, p.x); right = math.max(right, p.x);
      top = math.min(top, p.y); bottom = math.max(bottom, p.y);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  static void stretch(InkElement e, Offset center, double sx, double sy) {
    e.x = center.dx + (e.x - center.dx) * sx;
    e.y = center.dy + (e.y - center.dy) * sy;
    e.w *= sx;
    e.h *= sy;
    for (final p in e.points) {
      p.x = center.dx + (p.x - center.dx) * sx;
      p.y = center.dy + (p.y - center.dy) * sy;
    }
  }

  static void shear(InkElement e, Offset center, double x, double y) {
    if (e.type != 'stroke') {
      e.skewX += x;
      e.skewY += y;
      return;
    }
    for (final p in e.points) {
      final dx = p.x - center.dx, dy = p.y - center.dy;
      p.x += x * dy;
      p.y += y * dx;
    }
  }

  /// Ajusta pontos sem gerar novos, simulando leve perspectiva geométrica.
  static void perspective(InkElement e, Offset center, double strength) {
    if (e.type != 'stroke') {
      e.skewX += strength * .20;
      return;
    }
    final rect = e.bounds;
    final width = math.max(1.0, rect.width);
    for (final p in e.points) {
      final weight = 1 + strength * ((p.y - center.dy) / width);
      p.x = center.dx + (p.x - center.dx) * weight.clamp(.2, 3.0);
    }
  }

  static bool matchesFilter(InkElement item, Sketch doc,
      {bool includeLocked = false, String layerId = '', String type = 'todos'}) {
    final layer = doc.layerById(item.layerId);
    if (layer == null || !layer.visible) return false;
    if (!includeLocked && (layer.locked || item.locked)) return false;
    if (layerId.isNotEmpty && item.layerId != layerId) return false;
    if (type == 'texto' && item.type != 'text') return false;
    if (type == 'imagem' && item.type != 'image') return false;
    if (type == 'traço' && item.type != 'stroke') return false;
    return true;
  }

  static const copic = <int>[
    0xff191919,0xffffffff,0xffeeeeee,0xffa6a6a6,0xff585858,
    0xfff6c8c6,0xffe65d5b,0xffae2222,0xfff5a3b7,0xffec7190,
    0xfffbd9aa,0xffffb95d,0xffe98234,0xfff7e5a2,0xfff1d452,
    0xffbbd893,0xff83c57a,0xff4c9653,0xffa5dfd7,0xff46b8b1,
    0xffb4d6f1,0xff6da9e3,0xff3366ac,0xffb1a5d7,0xff7354a3,
    0xffbe9277,0xff926e53,0xff684a3d,0xffdec1a7,0xffa48672,
  ];

  static final builtInPacks = <String, List<Map<String, dynamic>>>{
    'Mapas mentais': [
      {'name':'Nuvem', 'tool':'cloud','width':260.0,'height':160.0},
      {'name':'Balão de fala', 'tool':'balloon','width':210.0,'height':120.0},
      {'name':'Cápsula', 'tool':'capsule','width':200.0,'height':80.0},
      {'name':'Conceito', 'tool':'rectangle','width':210.0,'height':85.0},
      {'name':'Ideia', 'tool':'ellipse','width':165.0,'height':110.0},
      {'name':'Seta', 'tool':'arrow','width':190.0,'height':0.0},
      {'name':'Tópico', 'tool':'triangle','width':115.0,'height':100.0},
    ],
    'Fluxogramas': [
      {'name':'Etapa', 'tool':'rectangle','width':210.0,'height':110.0},
      {'name':'Decisão', 'tool':'diamond','width':200.0,'height':125.0},
      {'name':'Início/Fim', 'tool':'ellipse','width':195.0,'height':70.0},
    ],
    'Geometria': [
      {'name':'Quadrado', 'tool':'rectangle','width':140.0,'height':140.0},
      {'name':'Círculo', 'tool':'ellipse','width':140.0,'height':140.0},
      {'name':'Triângulo', 'tool':'triangle','width':160.0,'height':140.0},
    ],
  };

  /// [at] é o canto superior esquerdo da caixa VISUAL do pacote, inclusive
  /// a margem da espessura dos contornos. Os pontos editáveis das figuras
  /// podem, portanto, ficar ligeiramente para dentro dessa caixa.
  static List<InkElement> instantiateObject(String layerId,
      List<Map<String, dynamic>> objects, Offset at) {
    if (objects.isEmpty) return [];
    final rebuilt = objects.map((e)=>InkElement.fromJson(e)).toList();
    final r = rebuilt.map((e)=>e.bounds).reduce((a,b)=>a.expandToInclude(b));
    final group = newId();
    final ids={for(final e in rebuilt)e.id:newId()};
    for (final e in rebuilt) {
      MindMapVectors.remapLinks(e,ids);
      e.id = ids[e.id]!; e.layerId = layerId; e.locked = false; e.group = group;
      e.translate(at.dx - r.left, at.dy - r.top);
    }
    return rebuilt;
  }

  static String exportPack(String name, List<InkElement> objects) {
    final items = objects.map((e)=>e.toJson()).toList();
    return jsonEncode({'schema':'ci.objects.v1','name':name,'objects':items});
  }

  static List<Map<String,dynamic>> importPack(String text) {
    final json = jsonDecode(text) as Map<String,dynamic>;
    if (json['schema'] != 'ci.objects.v1') throw const FormatException('Pacote de objetos incompatível.');
    final items = (json['objects'] as List? ?? []);
    if (items.length > 500) throw const FormatException('Pacote contém objetos demais.');
    return items.map((e)=>Map<String,dynamic>.from(e as Map)).toList();
  }
}
