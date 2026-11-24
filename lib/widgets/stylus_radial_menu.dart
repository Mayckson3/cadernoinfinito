import 'package:flutter/material.dart';
import '../services/radial_menu_geometry.dart';

/// Ações principais: nomes objetivos e ícones reconhecíveis.
/// Ações de configuração abrem controles existentes em vez de criar cópias.
class RadialQuickAction {
  final String key;
  final String label;
  final IconData icon;
  const RadialQuickAction(this.key, this.label, this.icon);
}

const radialQuickActions = <RadialQuickAction>[
  RadialQuickAction('pen', 'Caneta', Icons.edit_outlined),
  RadialQuickAction('marker', 'Marcador', Icons.border_color_outlined),
  RadialQuickAction('eraser', 'Borracha', Icons.auto_fix_off),
  RadialQuickAction('select', 'Selecionar', Icons.select_all),
  RadialQuickAction('lasso', 'Laço', Icons.gesture),
  RadialQuickAction('pan', 'Mover quadro', Icons.pan_tool_outlined),
  RadialQuickAction('undo', 'Desfazer', Icons.undo),
  RadialQuickAction('redo', 'Refazer', Icons.redo),
  RadialQuickAction('colors', 'Escolher cor', Icons.palette_outlined),
  RadialQuickAction('stroke', 'Espessura', Icons.line_weight),
  RadialQuickAction('text', 'Texto', Icons.text_fields),
  RadialQuickAction('line', 'Linha reta', Icons.show_chart),
  RadialQuickAction('rectangle', 'Retângulo', Icons.crop_square),
  RadialQuickAction('ellipse', 'Elipse', Icons.circle_outlined),
  RadialQuickAction('eyedropper', 'Conta-gotas', Icons.colorize_outlined),
];

/// Preserva ordem, rejeita itens inválidos e mantém de quatro a dez atalhos.
List<RadialQuickAction> selectedRadialActions(Object? setting) {
  if (setting is! List) return radialQuickActions.take(10).toList();
  final allowed={for(final action in radialQuickActions) action.key:action};
  final used=<String>{};
  final result=<RadialQuickAction>[];
  for(final key in setting) {
    if(key is String && allowed.containsKey(key) && used.add(key)) {
      result.add(allowed[key]!);
      if(result.length==10)break;
    }
  }
  return result.length>=4 ? result : radialQuickActions.take(10).toList();
}


/// Interface visual pura: a detecção do arraste acontece no Listener do quadro.
/// IgnorePointer impede que o overlay capture toques destinados à caneta.
class StylusRadialMenu extends StatelessWidget {
  final Offset center;
  final double radius;
  final int? highlighted;
  final String activeTool;
  final bool canUndo;
  final bool canRedo;
  final List<RadialQuickAction> actions;
  final String? previousAction;

  const StylusRadialMenu({super.key,required this.center,required this.radius,
    required this.highlighted,required this.activeTool,
    required this.canUndo,required this.canRedo,
    required this.actions,this.previousAction});

  @override Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final buttonSize = (radius * .45).clamp(24.0,42.0).toDouble();
    final halfSize = radius + buttonSize/2 + 8;
    final diameter = 2 * halfSize;
    final localCenter = Offset(halfSize, halfSize);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color:scheme.onSurface, fontWeight:FontWeight.w600);
    final current = highlighted==null || highlighted!>=actions.length
      ? null : actions[highlighted!];
    final last = actions.where((a)=>a.key==previousAction).firstOrNull;
    return IgnorePointer(child:Stack(children:[
      Positioned(left:center.dx-halfSize,top:center.dy-halfSize,
        width:diameter,height:diameter,child:RepaintBoundary(
          child:DecoratedBox(decoration:BoxDecoration(
            color:scheme.surface.withValues(alpha:.96),
            shape:BoxShape.circle,
            border:Border.all(color:scheme.outlineVariant.withValues(alpha:.5)),
            boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.17),
              blurRadius:18,offset:const Offset(0,5))]),
            child:Stack(children:[
              Center(child:Container(
                key: const Key('radial-menu-center'),
                width:radius*.91,height:radius*.91,
                padding:const EdgeInsets.all(8),
                alignment:Alignment.center,
                decoration:BoxDecoration(shape:BoxShape.circle,
                  color:current==null ? scheme.surfaceContainerHigh
                    :scheme.primaryContainer),
                child:Text(
                  current?.label??(last==null?'Arraste': 'Última: ${last.label}'),
                  maxLines:2,textAlign:TextAlign.center,
                  overflow:TextOverflow.ellipsis,
                  style:textStyle?.copyWith(fontSize:(radius*.12).clamp(9.0,11.0).toDouble(),
                    color:current==null?scheme.onSurfaceVariant:scheme.onPrimaryContainer)),
                )),
              for(var i=0;i<actions.length;i++)
                _item(context,i,localCenter,buttonSize,scheme),
            ])))),
    ]));
  }

  Widget _item(BuildContext context,int index,Offset center,
      double size,ColorScheme scheme) {
    final action=actions[index];
    final point=RadialMenuGeometry.actionCenter(index,center,radius,
      count:actions.length);
    final selected=highlighted==index;
    final disabled=(action.key=='undo'&&!canUndo) ||
      (action.key=='redo'&&!canRedo);
    final active=activeTool==action.key;
    final recent=previousAction==action.key;
    return Positioned(left:point.dx-size/2,top:point.dy-size/2,
      width:size,height:size,
      child:Semantics(label:action.label,selected:selected,enabled:!disabled,
        child:AnimatedContainer(duration:const Duration(milliseconds:90),
          decoration:BoxDecoration(shape:BoxShape.circle,
            color:selected ? scheme.primary :
              (active?scheme.secondaryContainer:scheme.surfaceContainerHighest),
            border:Border.all(color:selected?scheme.primary:
              recent?scheme.tertiary:scheme.outlineVariant.withValues(alpha:.55),
              width:selected?2:(recent?1.8:1))),
          child:Stack(alignment:Alignment.center,children:[
            Icon(action.icon,size:size*.54,
              color:disabled?scheme.onSurface.withValues(alpha:.32):
                selected?scheme.onPrimary:
                  active?scheme.onSecondaryContainer:scheme.onSurface),
            if(recent && !selected) Positioned(right:2,bottom:2,
              child:Icon(Icons.circle,size:5,color:scheme.tertiary)),
          ])),
      ));
  }
}
