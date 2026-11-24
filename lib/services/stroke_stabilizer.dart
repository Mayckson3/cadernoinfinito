import 'dart:math' as math;
import 'dart:ui';
import '../models/sketch.dart';

/// Filtro de acabamento em coordenadas do quadro. Atua apenas ao finalizar
/// a escrita, não durante a captura dos eventos da caneta.
class StrokeStabilizer {
  static const double defaultStrength = 1.25;
  static const double maxStrength = 2.0;

  static bool supports(String tool) => const {
    'pen', 'fixed', 'hard pencil', 'soft pencil', 'marker', 'wire',
    'dynamic', 'fountain', 'watercolor', 'airbrush',
  }.contains(tool);

  /// Preserva a densidade de pontos, pressão, inclinação e orientação.
  /// Não converte a caligrafia em formas geométricas. Os extremos e cantos
  /// sustentados ficam fixos. O deslocamento em cada etapa é limitado em pixels
  /// lógicos da tela, independentemente do zoom de captura.
  static List<InkPoint> finish(List<InkPoint> points,
      {required double zoom, double strength = defaultStrength}) {
    if (points.length < 3 || !zoom.isFinite || zoom <= 0 ||
        !strength.isFinite || strength <= 0 ||
        points.any((p) => !p.x.isFinite || !p.y.isFinite)) {
      return List.of(points);
    }
    final level = strength.clamp(0.0, maxStrength).toDouble();
    if (level > .75) {
      // Primeiro remove ruído fino; depois corrige ondulações mais amplas.
      // Assim a regressão não interpreta tremor de alta frequência como curva.
      return _polished(finish(points,zoom:zoom,strength:.75),zoom,level);
    }
    final n = points.length;
    final arc = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      arc[i] = arc[i - 1] + (points[i].offset - points[i - 1].offset).distance * zoom;
    }
    // Pontos, acentos curtíssimos e amostras inválidas não são remodelados.
    if (!arc.last.isFinite || arc.last < 4) return List.of(points);

    final radius = 4.0 + 5.0 * level;
    final maxShift = (3.0 * level) / zoom;
    final left = List<int>.generate(n, (i) => i);
    final right = List<int>.generate(n, (i) => i);
    final fixed = List<bool>.filled(n, false);
    final weights = List<double>.filled(n, 1.0);
    final turns = List<double>.filled(n, 0);
    for (var i = 1; i < n - 1; i++) {
      final u = points[i].offset - points[i - 1].offset;
      final v = points[i + 1].offset - points[i].offset;
      turns[i] = u.dx * v.dy - u.dy * v.dx;
    }
    fixed.first = true;
    fixed.last = true;
    for (var i = 1; i < n - 1; i++) {
      var a = i - 1;
      var b = i + 1;
      // Janelas curtas, limitadas por comprimento de arco e por número de
      // amostras. O custo é linear mesmo em traços excepcionalmente longos.
      while (a > 0 && i - a < 10 && arc[i] - arc[a] < radius) { a--; }
      while (b < n - 1 && b - i < 10 && arc[b] - arc[i] < radius) { b++; }
      left[i] = a;
      right[i] = b;
      if (arc[i] - arc[i - 1] > radius * 1.8 ||
          arc[i + 1] - arc[i] > radius * 1.8) {
        fixed[i] = true;
        continue;
      }
      // Uma mudança de direção sustentada em uma janela maior é diferente
      // de uma oscilação isolada do sensor. Protege vértices e laços pequenos.
      final u = points[i].offset - points[a].offset;
      final v = points[b].offset - points[i].offset;
      final ul = u.distance;
      final vl = v.distance;
      if (ul * zoom >= 2.5 && vl * zoom >= 2.5) {
        final cosine = (u.dx * v.dx + u.dy * v.dy) / (ul * vl);
        if (cosine < .22) {
          fixed[i] = true;
        } else {
          // Curvas sustentadas recebem menos correção que trechos quase
          // retos: evita encolher letras arredondadas ou círculos pequenos.
          final alternating = turns[i] * turns[i - 1] < 0 ||
              turns[i] * turns[i + 1] < 0;
          if (!alternating) {
            weights[i] = ((cosine - .78) / .20).clamp(.18, 1.0).toDouble();
          }
        }
      }
    }
    // Uma janela não atravessa um vértice protegido. Os dois lados do
    // canto são tratados de modo independente, sem arredondá-lo.
    var anchor = 0;
    for (var i = 1; i < n - 1; i++) {
      if (fixed[i]) { anchor = i; continue; }
      if (left[i] < anchor) left[i] = anchor;
    }
    anchor = n - 1;
    for (var i = n - 2; i > 0; i--) {
      if (fixed[i]) { anchor = i; continue; }
      if (right[i] > anchor) right[i] = anchor;
    }

    final original = points.map((p) => p.offset).toList(growable: false);
    var current = List.of(original);
    final passes = level >= .65 ? 3 : 2;
    for (var pass = 0; pass < passes; pass++) {
      final next = List.of(current);
      for (var i = 1; i < n - 1; i++) {
        if (fixed[i]) continue;
        final a = left[i], b = right[i];
        final broadLength = arc[b] - arc[a];
        final localLength = arc[i + 1] - arc[i - 1];
        if (broadLength <= 1e-9 || localLength <= 1e-9) continue;
        // Interpolação ponderada por distância, em vez de uma média simples:
        // evita arrastar pontos quando a velocidade de escrita varia.
        final t = (arc[i] - arc[a]) / broadLength;
        final s = (arc[i] - arc[i - 1]) / localLength;
        final broad = current[a] + (current[b] - current[a]) * t;
        final local = current[i - 1] + (current[i + 1] - current[i - 1]) * s;
        final target = local * .65 + broad * .35;
        final candidate = current[i] + (target - current[i]) * (.65 * level * weights[i]);
        final delta = candidate - original[i];
        final distance = delta.distance;
        next[i] = distance > maxShift
            ? original[i] + delta * (maxShift / distance)
            : candidate;
      }
      // Cada passagem lê uma cópia estável: não há viés na direção da escrita.
      current = next;
    }
    return [for (var i = 0; i < n; i++)
      InkPoint(current[i].dx, current[i].dy, points[i].p, points[i].tilt, points[i].angle)];
  }
  /// Ajuste quadrático local: preserva curvatura, em vez de puxar cada
  /// ponto para uma reta. A regressão usa comprimento de arco e pesos por
  /// distância, não quantidade de eventos (velocidades de escrita variam).
  static List<InkPoint> _polished(List<InkPoint> points, double zoom, double level) {
    final original = points.map((p) => p.offset).toList(growable: false);
    final n = original.length;
    final arc = List<double>.filled(n, 0);
    for (var i = 1; i < n; i++) {
      arc[i] = arc[i-1] + (original[i]-original[i-1]).distance * zoom;
    }
    if (!arc.last.isFinite || arc.last < 4) return List.of(points);
    final power = (level-.75)/1.25;
    final radius = math.min(12.0 + 20.0*power, math.max(5.0, arc.last*.27));
    final maxShift = math.min(5.0 + 10.0*power, arc.last*.14)/zoom;
    final anchors = List<bool>.filled(n, false);
    anchors[0] = anchors[n-1] = true;
    // A separação grande entre eventos não é uma curva observada; não a
    // usar como vizinhança. Vértices nítidos e sustentados são protegidos.
    final gap = math.max(18.0, radius*1.25);
    for (var i = 1; i < n; i++) {
      if (arc[i]-arc[i-1] > gap) anchors[i-1] = anchors[i] = true;
    }
    for (var i = 1; i < n-1; i++) {
      if (anchors[i]) continue;
      final u = original[i]-original[i-1], v = original[i+1]-original[i];
      final denom = u.distance*v.distance;
      if (denom < 1e-9 || (u.dx*v.dx+u.dy*v.dy)/denom > .20) continue;
      var a=i-1, b=i+1;
      while (a>0 && !anchors[a] && i-a<20 && arc[i]-arc[a]<5) {a--;}
      while (b<n-1 && !anchors[b] && b-i<20 && arc[b]-arc[i]<5) {b++;}
      final left=original[i]-original[a], right=original[b]-original[i];
      final d=left.distance*right.distance;
      if (left.distance*zoom>=3 && right.distance*zoom>=3 &&
          d>1e-9 && (left.dx*right.dx+left.dy*right.dy)/d < .35) {
        anchors[i]=true;
      }
    }
    final left = List<int>.filled(n,0), right=List<int>.filled(n,n-1);
    var start=0;
    for(var i=0;i<n;i++) {if(anchors[i])start=i;left[i]=start;}
    var end=n-1;
    for(var i=n-1;i>=0;i--) {if(anchors[i])end=i;right[i]=end;}
    var current=List.of(original);
    final passes=power>.6?4:3;
    for(var pass=0;pass<passes;pass++) {
      final next=List.of(current);
      for(var i=1;i<n-1;i++) {
        if(anchors[i])continue;
        var a=i-1,b=i+1;
        while(a>left[i] && i-a<48 && arc[i]-arc[a]<radius){a--;}
        while(b<right[i] && b-i<48 && arc[b]-arc[i]<radius){b++;}
        // Não extrapolar nas extremidades e junto a vértices protegidos.
        final span=math.min(arc[i]-arc[left[i]],arc[right[i]]-arc[i]);
        if(span<=1e-8)continue;
        final fit=_quadraticCenter(current,arc,i,a,b,radius);
        if(fit==null)continue;
        final amount=(.64+.30*power)*(span/4).clamp(0.0,1.0).toDouble();
        final candidate=current[i]+(fit-current[i])*amount;
        final delta=candidate-original[i];
        final distance=delta.distance;
        next[i]=distance>maxShift?original[i]+delta*(maxShift/distance):candidate;
      }
      current=next;
    }
    return [for(var i=0;i<n;i++) InkPoint(current[i].dx,current[i].dy,
      points[i].p,points[i].tilt,points[i].angle)];
  }

  /// Resolve os momentos da regressão quadrática por eliminação gaussiana
  /// com pivoteamento. Calcula x/y juntos e usa origem local (quadro infinito).
  static Offset? _quadraticCenter(List<Offset> values,List<double> arc,
      int center,int a,int b,double radius) {
    final matrix=List.generate(3,(_)=>List<double>.filled(5,0));
    final origin=values[center];
    for(var j=a;j<=b;j++) {
      final t=(arc[j]-arc[center])/radius;
      if(t.abs()>1.25)continue;
      final spacing=(arc[math.min(b,j+1)]-arc[math.max(a,j-1)])/2;
      final w=math.exp(-2*t*t)*spacing.clamp(.05, radius).toDouble();
      final basis=[1.0,t,t*t];
      final point=values[j]-origin;
      for(var r=0;r<3;r++) {
        for(var c=0;c<3;c++) {matrix[r][c]+=w*basis[r]*basis[c];}
        matrix[r][3]+=w*basis[r]*point.dx;
        matrix[r][4]+=w*basis[r]*point.dy;
      }
    }
    for(var k=0;k<3;k++) {
      var pivot=k;
      for(var r=k+1;r<3;r++) {if(matrix[r][k].abs()>matrix[pivot][k].abs())pivot=r;}
      if(matrix[pivot][k].abs()<1e-9)return null;
      final row=matrix[k];matrix[k]=matrix[pivot];matrix[pivot]=row;
      final scale=matrix[k][k];
      for(var c=k;c<5;c++){matrix[k][c]/=scale;}
      for(var r=0;r<3;r++) {
        if(r==k)continue;
        final factor=matrix[r][k];
        for(var c=k;c<5;c++){matrix[r][c]-=factor*matrix[k][c];}
      }
    }
    final fit=origin+Offset(matrix[0][3],matrix[0][4]);
    return fit.dx.isFinite && fit.dy.isFinite ? fit : null;
  }
}
