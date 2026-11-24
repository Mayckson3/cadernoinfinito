import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/rich_text.dart';
import 'package:caderno_infinito/services/text_geometry.dart';
import 'package:caderno_infinito/widgets/inline_text_editor.dart';
import 'package:caderno_infinito/services/import_export.dart';

void main() {
  test('Formatação por trecho combina estilos sem alterar texto simples', () {
    final controller=RichTextController(text:'abc def');
    controller.selection=const TextSelection(baseOffset:0,extentOffset:3);
    controller.toggle(RichTextFormat.bold);
    controller.toggle(RichTextFormat.italic);
    controller.setHighlight(0xffffeb3b);
    controller.setColor(0xffef4444);
    controller.setRelativeSize(1.5);
    final marks=RichTextFormat.decode(controller.text,controller.runs);
    expect(marks[0].flags,RichTextFormat.bold|RichTextFormat.italic);
    expect(marks[2].scale,1.5);
    expect(marks[1].highlight,0xffffeb3b);
    expect(marks[1].color,0xffef4444);
    expect(marks[3],RichTextFormat.plain);
    expect(controller.text,'abc def');
    controller.dispose();
  });
  test('Inserção e exclusão remapeiam corretamente os estilos', () {
    final controller=RichTextController(text:'abc def');
    controller.selection=const TextSelection(baseOffset:4,extentOffset:7);
    controller.toggle(RichTextFormat.underline);
    controller.selection=const TextSelection.collapsed(offset:0);
    controller.value=const TextEditingValue(text:'Xabc def',selection:TextSelection.collapsed(offset:1));
    var marks=RichTextFormat.decode(controller.text,controller.runs);
    expect(marks[0],RichTextFormat.plain);
    expect(marks[5].flags,RichTextFormat.underline);
    controller.selection=const TextSelection(baseOffset:1,extentOffset:5);
    controller.value=const TextEditingValue(text:'Xdef',selection:TextSelection.collapsed(offset:1));
    marks=RichTextFormat.decode(controller.text,controller.runs);
    expect(marks[1].flags,RichTextFormat.underline);
    controller.dispose();
  });
  test('Formatação ativada antes de digitar e persistência no documento', () {
    final controller=RichTextController();
    controller.toggle(RichTextFormat.strike);
    controller.value=const TextEditingValue(text:'texto',selection:TextSelection.collapsed(offset:5));
    final document=Sketch();
    document.elements.add(InkElement(layerId:document.layers.first.id,type:'text',text:controller.text,
      size:32,x:20,y:30,meta:{'richRuns':controller.runs}));
    final copy=document.clone().elements.single;
    expect(copy.x,20);expect(copy.y,30);expect(copy.size,32);
    expect(RichTextFormat.decode(copy.text,copy.meta['richRuns']).first.flags,RichTextFormat.strike);
    controller.dispose();
  });
  testWidgets('Métricas e SVG consideram estilos de texto', (tester) async {
    final doc=Sketch();
    final runs=[{'start':0,'end':4,'flags':RichTextFormat.bold|RichTextFormat.underline,
      'scale':2.0,'highlight':0xffffeb3b}];
    final plain=TextGeometry.measure('Teste',18);
    final rich=TextGeometry.measure('Teste',18,runs:runs);
    expect(rich.height,greaterThan(plain.height));
    doc.elements.add(InkElement(layerId:doc.layers.first.id,type:'text',text:'Teste',
      w:rich.width,h:rich.height,size:18,meta:{'richRuns':runs}));
    final svg=SketchExchange.exportSvg(doc);
    expect(svg,contains('font-weight="bold"'));
    expect(svg,contains('text-decoration="underline"'));
    expect(svg,contains('#ffeb3b'));
  });
  testWidgets('Editor embutido mostra texto com tamanho do quadro e controles', (tester) async {
    final controller=RichTextController();
    final node=FocusNode();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:InlineTextEditor(
      controller:controller,focusNode:node,anchor:const Offset(70,80),width:300,
      fontSize:24,zoom:1.5,rotation:0,color:Colors.black,boardColor:Colors.white,
      palette:const [],onAccept:(){},onCancel:(){},onSize:(){},onRangeSize:(){},
    ))));
    final field=find.byKey(const ValueKey('inline-rich-text-field'));
    expect(tester.widget<TextField>(field).style!.fontSize,36);
    expect(tester.widget<TextField>(field).style!.textBaseline, TextBaseline.alphabetic);
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(field),const Offset(70,80));
    await tester.enterText(field,'Teste');
    controller.selection=const TextSelection(baseOffset:0,extentOffset:5);
    await tester.pump();
    await tester.tap(find.byTooltip('Negrito'));
    await tester.pump();
    expect(controller.runs.single['flags'],RichTextFormat.bold);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    node.dispose();controller.dispose();
  });
}
