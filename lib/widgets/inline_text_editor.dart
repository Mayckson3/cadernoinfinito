import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/rich_text.dart';

/// Only this overlay rebuilds while the user types. The rest of the canvas
/// remains unchanged until the edit is committed.
class InlineTextEditor extends StatelessWidget {
  final RichTextController controller;
  final FocusNode focusNode;
  final Offset anchor;
  final double width, fontSize, zoom, rotation;
  final Color color, boardColor;
  final List<int> palette;
  final VoidCallback onAccept, onCancel, onSize, onRangeSize;
  const InlineTextEditor({super.key, required this.controller,
    required this.focusNode, required this.anchor, required this.width,
    required this.fontSize, required this.zoom, required this.rotation,
    required this.color, required this.boardColor, required this.palette,
    required this.onAccept, required this.onCancel, required this.onSize,
    required this.onRangeSize});

  void _apply(VoidCallback action) {
    action();
    focusNode.requestFocus();
  }

  Widget _formatButton(String label, IconData icon, int flag) => IconButton(
    tooltip: label, isSelected: controller.active(flag),
    onPressed: () => _apply(() => controller.toggle(flag)),
    icon: Icon(icon), selectedIcon: Icon(icon));

  Widget _colorMenu({required bool highlight}) {
    final colors = <int>{if(highlight) ...[0xffffeb3b,0xffa7f3d0,0xfff9a8d4,0xff93c5fd,0xffffcc80]
      else ...[color.toARGB32(),0xff17202c,0xffffffff,...palette,0xffef4444,0xff3b82f6]};
    return PopupMenuButton<int>(tooltip: highlight ? 'Cor do destaque' : 'Cor do texto selecionado',
      icon: Icon(highlight ? Icons.format_color_fill : Icons.format_color_text),
      onSelected: (value) => _apply(() {
        final chosen = value == -1 ? null : value;
        if(highlight) { controller.setHighlight(chosen); }
        else { controller.setColor(chosen); }
      }),
      itemBuilder: (_) => [
        const PopupMenuItem(value: -1, child: Text('Remover cor especial')),
        for(final value in colors) PopupMenuItem(value: value, child: Row(children:[
          Container(width:24,height:24,decoration:BoxDecoration(color:Color(value),
            shape:BoxShape.circle,border:Border.all(color:Colors.grey))),
          const SizedBox(width:12),
          Text('#${(value & 0xffffff).toRadixString(16).padLeft(6,'0').toUpperCase()}'),
        ])),
      ]);
  }

  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contrast = boardColor.computeLuminance() > .5 ? Colors.black87 : Colors.white;
    return LayoutBuilder(builder: (context, constraints) {
      final fieldHeight = math.max(24.0, constraints.maxHeight - math.max(0.0,anchor.dy) - 56);
      return Stack(clipBehavior: Clip.hardEdge, children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onAccept)),
        Positioned(left: anchor.dx, top: anchor.dy,
          width: math.max(1.0, width * zoom),
          child: Transform.rotate(angle: rotation, alignment: Alignment.topLeft,
            child: ConstrainedBox(constraints: BoxConstraints(maxHeight: fieldHeight),
              child: MediaQuery.withNoTextScaling(child: TextField(
                key: const ValueKey('inline-rich-text-field'),
                controller: controller, focusNode: focusNode, autofocus: true,
                minLines: 1, maxLines: null, keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textDirection: TextDirection.ltr,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: contrast, scrollPadding: EdgeInsets.zero,
                style: TextStyle(inherit: false, fontSize: fontSize * zoom,
                  textBaseline: TextBaseline.alphabetic, height: 1.25,
                  fontWeight: FontWeight.w400, letterSpacing: 0, wordSpacing: 0, color: color),
                decoration: null, onTapOutside: (_) {},
              )),
            ),
          ),
        ),
        Positioned(left: 6, right: 6, bottom: 4,
          child: TextFieldTapRegion(child: Material(
            elevation: 3, borderRadius: BorderRadius.circular(14),
            color: theme.colorScheme.surfaceContainerHigh,
            child: SizedBox(height: 48, child: Row(children: [
              Expanded(child: ListenableBuilder(listenable: controller,
                builder: (context, _) => ListView(scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 2), children: [
                    TextButton(onPressed: onSize, child: Text('${fontSize.toStringAsFixed(fontSize % 1 == 0 ? 0 : 1)} px')),
                    _formatButton('Negrito', Icons.format_bold, RichTextFormat.bold),
                    _formatButton('Itálico', Icons.format_italic, RichTextFormat.italic),
                    _formatButton('Sublinhado', Icons.format_underlined, RichTextFormat.underline),
                    _formatButton('Tachado', Icons.format_strikethrough, RichTextFormat.strike),
                    IconButton(tooltip: 'Destacar texto', icon: const Icon(Icons.border_color_outlined),
                      isSelected: controller.current.highlight != null,
                      onPressed: () => _apply(() => controller.setHighlight(
                        controller.current.highlight == null ? 0xffffeb3b : null))),
                    _colorMenu(highlight: true), _colorMenu(highlight: false),
                    IconButton(tooltip:'Tamanho do trecho selecionado', onPressed:onRangeSize,
                      icon:const Icon(Icons.format_size)),
                    IconButton(tooltip:'Limpar formatação', onPressed:()=>_apply(controller.clearFormatting),
                      icon:const Icon(Icons.format_clear)),
                  ]))),
              IconButton(tooltip:'Cancelar edição de texto',onPressed:onCancel,icon:const Icon(Icons.close)),
              IconButton(tooltip:'Concluir edição de texto',onPressed:onAccept,
                icon:Icon(Icons.check_circle,color:theme.colorScheme.primary)),
            ])),
          )),
        ),
      ]);
    });
  }
}
