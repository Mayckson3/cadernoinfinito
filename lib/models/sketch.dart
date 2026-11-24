import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

// Retângulo alinhado aos eixos que envolve uma figura girada. O desenho
// continua armazenado no formato antigo, sem perder a editabilidade.
Rect _rotatedVisualBounds(Rect base, double angle) {
  if (angle == 0 || base.isEmpty) return base;
  final pivot = base.center;
  final co = math.cos(angle), si = math.sin(angle);
  Offset rotated(Offset p) {
    final v = p - pivot;
    return pivot + Offset(v.dx*co-v.dy*si, v.dx*si+v.dy*co);
  }
  final points=[rotated(base.topLeft),rotated(base.topRight),
    rotated(base.bottomLeft),rotated(base.bottomRight)];
  return Rect.fromLTRB(points.map((p)=>p.dx).reduce(math.min),
      points.map((p)=>p.dy).reduce(math.min),
      points.map((p)=>p.dx).reduce(math.max),
      points.map((p)=>p.dy).reduce(math.max));
}

class InkPoint {
  double x, y, p, tilt, angle;
  InkPoint(this.x, this.y, [this.p = 1, this.tilt = 0, this.angle = 0]);
  Offset get offset => Offset(x, y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'p': p, 'tilt': tilt, 'angle': angle};
  factory InkPoint.fromJson(Map<String, dynamic> j) => InkPoint(
      (j['x'] as num).toDouble(), (j['y'] as num).toDouble(),
      (j['p'] as num?)?.toDouble() ?? 1,
      (j['tilt'] as num?)?.toDouble() ?? 0,
      (j['angle'] as num?)?.toDouble() ?? 0);
}

class InkLayer {
  String id, name;
  bool visible, locked;
  double opacity;
  InkLayer({String? id, this.name = 'Camada', this.visible = true,
    this.locked = false, this.opacity = 1}) : id = id ?? newId();
  Map<String, dynamic> toJson() => {'id': id, 'name': name,
    'visible': visible, 'locked': locked, 'opacity': opacity};
  factory InkLayer.fromJson(Map<String, dynamic> j) => InkLayer(
    id: j['id'] as String, name: j['name'] as String? ?? 'Camada',
    visible: j['visible'] as bool? ?? true, locked: j['locked'] as bool? ?? false,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1);
}

class InkElement {
  String id, layerId, type, tool;
  List<InkPoint> points;
  int color;
  double size, opacity, rotation;
  bool locked;
  String text, data;
  double x, y, w, h;
  String? group;
  Map<String, dynamic> meta;
  double skewX, skewY;
  InkElement({String? id, required this.layerId, this.type = 'stroke',
    this.tool = 'pen', List<InkPoint>? points, this.color = 0xff17202c,
    this.size = 3, this.opacity = 1, this.rotation = 0, this.locked = false,
    this.text = '', this.data = '', this.x = 0, this.y = 0,
    this.w = 0, this.h = 0, this.group, this.skewX = 0,
    this.skewY = 0, Map<String, dynamic>? meta})
      : id = id ?? newId(), points = points ?? [], meta = meta ?? {};
  Rect get bounds {
    if (type != 'stroke' || points.isEmpty) {
      if (type == 'text') {
        // O comprimento de todo o texto não pode ser somado à largura do
        // bloco: isso gerava caixas de seleção gigantes em anotações longas.
        final lines=text.split('\n');
        final width=w.abs()>0 ? w.abs() : math.max(30.0,
          lines.map((line)=>line.length).reduce(math.max)*size*.56);
        // Medidas fornecidas por TextPainter no momento da criação/edição.
        // Não somar estimativas de quebras à altura já medida: isso fazia
        // a caixa exceder muito os caracteres realmente desenhados.
        final height=h.abs()>0?h.abs():math.max(1,lines.length)*size*1.25;
        return _rotatedVisualBounds(Rect.fromLTWH(x,y,width,height),rotation);
      }
      return _rotatedVisualBounds(Rect.fromLTWH(x, y, w.abs(), h.abs()),rotation);
    }
    if(tool=='compass' && points.length>=2) {
      return Rect.fromCircle(center:points.first.offset,
        radius:(points.last.offset-points.first.offset).distance).inflate(size/2);
    }
    double minX = points.first.x, maxX = minX, minY = points.first.y, maxY = minY;
    for (final p in points) {
      minX = math.min(minX, p.x); maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y); maxY = math.max(maxY, p.y);
    }
    final base=Rect.fromLTRB(minX, minY, maxX, maxY);
    if(const ['rectangle','ellipse','triangle','diamond','rounded rectangle','cloud','balloon','capsule','hexagon'].contains(tool)) {
      return _rotatedVisualBounds(base,rotation).inflate(size / 2);
    }
    if(const ['connector','elbow connector','straight connector','vector curve','dashed line'].contains(tool) || meta.containsKey('vectorArrow')) {
      final head=meta['vectorArrow'] ?? (const ['connector','elbow connector','straight connector'].contains(tool)?'end':'none');
      if(head!='none')return base.inflate(math.max(9.0,size*4)*.55+size/2);
    }
    return base.inflate(size / 2);
  }
  void translate(double dx, double dy) {
    x += dx; y += dy;
    for (final p in points) { p.x += dx; p.y += dy; }
  }
  void scaleAround(Offset center, double factor) {
    x = center.dx + (x - center.dx) * factor;
    y = center.dy + (y - center.dy) * factor;
    w *= factor; h *= factor; size *= factor;
    for (final p in points) {
      p.x = center.dx + (p.x - center.dx) * factor;
      p.y = center.dy + (p.y - center.dy) * factor;
    }
  }
  void flip({required bool horizontal, required Offset center}) {
    if (horizontal) { x = 2 * center.dx - x - w; }
    else { y = 2 * center.dy - y - h; }
    for (final p in points) {
      if (horizontal) { p.x = 2 * center.dx - p.x; }
      else { p.y = 2 * center.dy - p.y; }
    }
  }
  Map<String, dynamic> toJson() => {
    'id': id, 'layerId': layerId, 'type': type, 'tool': tool,
    'points': points.map((p) => p.toJson()).toList(), 'color': color,
    'size': size, 'opacity': opacity, 'rotation': rotation, 'locked': locked,
    'text': text, 'data': data, 'x': x, 'y': y, 'w': w, 'h': h, 'group': group, 'skewX': skewX, 'skewY': skewY, 'meta': meta,
  };
  factory InkElement.fromJson(Map<String, dynamic> j) => InkElement(
    id: j['id'] as String, layerId: j['layerId'] as String? ?? '',
    type: j['type'] as String? ?? 'stroke', tool: j['tool'] as String? ?? 'pen',
    points: ((j['points'] as List?) ?? []).map((e) => InkPoint.fromJson(e as Map<String, dynamic>)).toList(),
    color: j['color'] as int? ?? 0xff17202c,
    size: (j['size'] as num?)?.toDouble() ?? 3,
    opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
    rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
    locked: j['locked'] as bool? ?? false,
    text: j['text'] as String? ?? '', data: j['data'] as String? ?? '',
    x: (j['x'] as num?)?.toDouble() ?? 0,
    y: (j['y'] as num?)?.toDouble() ?? 0,
    w: (j['w'] as num?)?.toDouble() ?? 0,
    h: (j['h'] as num?)?.toDouble() ?? 0, group: j['group'] as String?,
    skewX: (j['skewX'] as num?)?.toDouble() ?? 0,
    skewY: (j['skewY'] as num?)?.toDouble() ?? 0,
    meta: Map<String,dynamic>.from(j['meta'] as Map? ?? {}));
}

class Sketch {
  String id, title, folder, notes, grid, background, unit, layerMode;
  List<int> palette;
  List<String> quickTools;
  Map<String, dynamic> presets;
  Map<String, dynamic> objectPacks;
  Map<String, dynamic> gestures;
  // Marcadores internos para navegar rapidamente na tela infinita.
  List<Map<String, dynamic>> bookmarks;
  int perspectivePoints;
  bool deleted, snap, showMeasures;
  double gridSpacing, scale, artboardW, artboardH;
  String createdAt, updatedAt;
  List<InkLayer> layers;
  List<InkElement> elements;
  Sketch({String? id, this.title = 'Sem título', this.folder = 'Geral',
    this.notes = '', this.grid = 'pautado', this.background = '#ffffff',
    this.deleted = false, this.snap = false, this.showMeasures = false,
    this.gridSpacing = 35, this.scale = 1, this.unit = 'mm',
    this.layerMode = 'manual', this.perspectivePoints = 1,
    List<int>? palette, List<String>? quickTools, Map<String,dynamic>? presets,
    Map<String,dynamic>? objectPacks, Map<String,dynamic>? gestures,
    List<Map<String,dynamic>>? bookmarks, this.artboardW = 794,
    this.artboardH = 1123, String? createdAt, String? updatedAt,
    List<InkLayer>? layers, List<InkElement>? elements})
      : id = id ?? newId(), createdAt = createdAt ?? DateTime.now().toUtc().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toUtc().toIso8601String(),
        layers = layers ?? [InkLayer(name: 'Anotações')], elements = elements ?? [],
        palette = palette ?? [0xff17202c,0xffef4444,0xfff59e0b,0xff22c55e,0xff3b82f6],
        quickTools = quickTools ?? ['pen','marker','eraser','select','pan','text'],
        presets = presets ?? {}, objectPacks = objectPacks ?? {},
        gestures = gestures ?? {'holdSelect':true,'threeUndo':false,'fourRedo':false,
          'magneticSnap':true,'pressureInk':true,'showMiniMap':false},
        bookmarks = bookmarks ?? [];
  void touch() => updatedAt = DateTime.now().toUtc().toIso8601String();
  InkLayer? layerById(String id) { for (final l in layers) {if(l.id == id) return l;} return null; }
  Rect get contentBounds {
    if (elements.isEmpty) return Rect.fromLTWH(0, 0, artboardW, artboardH);
    Rect r = elements.first.bounds;
    for (final e in elements.skip(1)) { r = r.expandToInclude(e.bounds); }
    return r.inflate(25);
  }
  Map<String, dynamic> toJson() => {
    'version': 2, 'id': id, 'title': title, 'folder': folder, 'notes': notes,
    'grid': grid, 'background': background, 'deleted': deleted,
    'snap': snap, 'showMeasures': showMeasures, 'gridSpacing': gridSpacing,
    'scale': scale, 'unit': unit, 'layerMode': layerMode,
    'perspectivePoints': perspectivePoints, 'palette': palette,
    'quickTools': quickTools, 'presets': presets, 'objectPacks': objectPacks,
    'gestures':gestures, 'bookmarks':bookmarks,
    'artboardW': artboardW, 'artboardH': artboardH,
    'createdAt': createdAt, 'updatedAt': updatedAt,
    'layers': layers.map((e) => e.toJson()).toList(),
    'elements': elements.map((e) => e.toJson()).toList(),
  };
  String serialize() => jsonEncode(toJson());
  Sketch clone() => Sketch.fromJson(jsonDecode(serialize()) as Map<String, dynamic>);
  factory Sketch.fromJson(Map<String, dynamic> j) => Sketch(
    id: j['id'] as String, title: j['title'] as String? ?? 'Sem título',
    folder: j['folder'] as String? ?? 'Geral', notes: j['notes'] as String? ?? '',
    grid: j['grid'] as String? ?? 'pautado', background: j['background'] as String? ?? '#ffffff',
    deleted: j['deleted'] as bool? ?? false, snap: j['snap'] as bool? ?? false,
    showMeasures: j['showMeasures'] as bool? ?? false,
    gridSpacing: (j['gridSpacing'] as num?)?.toDouble() ?? 35,
    scale: (j['scale'] as num?)?.toDouble() ?? 1,
    unit: j['unit'] as String? ?? 'mm',
    layerMode: j['layerMode'] as String? ?? 'manual',
    perspectivePoints: (j['perspectivePoints'] as num?)?.toInt() ?? 1,
    palette: (j['palette'] as List?)?.map((e)=>(e as num).toInt()).toList(),
    quickTools: (j['quickTools'] as List?)?.cast<String>(),
    presets: Map<String,dynamic>.from(j['presets'] as Map? ?? {}),
    objectPacks: Map<String,dynamic>.from(j['objectPacks'] as Map? ?? {}),
    gestures: Map<String,dynamic>.from(j['gestures'] as Map? ?? {}),
    bookmarks: (j['bookmarks'] as List? ?? const [])
      .whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(),
    artboardW: (j['artboardW'] as num?)?.toDouble() ?? 794,
    artboardH: (j['artboardH'] as num?)?.toDouble() ?? 1123,
    createdAt: j['createdAt'] as String?, updatedAt: j['updatedAt'] as String?,
    layers: ((j['layers'] as List?) ?? []).map((e) => InkLayer.fromJson(e as Map<String, dynamic>)).toList(),
    elements: ((j['elements'] as List?) ?? []).map((e) => InkElement.fromJson(e as Map<String, dynamic>)).toList());
}
