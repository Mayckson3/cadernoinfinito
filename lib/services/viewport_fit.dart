import 'dart:math' as math;
import 'dart:ui';
import '../models/sketch.dart';

class ViewportPlacement {
  final double zoom;
  final Offset pan;
  const ViewportPlacement(this.zoom,this.pan);
}

class ViewportFit {
  const ViewportFit._();

  static Rect? elementBounds(Iterable<InkElement> objects) {
    final it=objects.iterator;
    if(!it.moveNext()) return null;
    var rect=it.current.bounds;
    while(it.moveNext()) {rect=rect.expandToInclude(it.current.bounds);}
    return rect;
  }

  /// Ajusta objetos ao visor sem modificar o documento; reseta a câmera
  /// girada no controlador. As margens são expressas em pixels de tela.
  static ViewportPlacement? compute(Rect bounds,Size viewport,
      {double margin=36, double minZoom=.12,double maxZoom=12}) {
    if(viewport.width<=0 || viewport.height<=0) return null;
    final availableWidth=math.max(1.0,viewport.width-2*margin);
    final availableHeight=math.max(1.0,viewport.height-2*margin);
    final width=math.max(bounds.width,1.0);
    final height=math.max(bounds.height,1.0);
    final zoom=math.min(availableWidth/width,availableHeight/height)
      .clamp(minZoom,maxZoom).toDouble();
    return ViewportPlacement(zoom,
      Offset(viewport.width/2-bounds.center.dx*zoom,
             viewport.height/2-bounds.center.dy*zoom));
  }
}
