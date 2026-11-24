import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/models/sketch.dart';
import 'package:caderno_infinito/services/advanced_tools.dart';
import 'package:caderno_infinito/services/local_store.dart';

void main() {
  test('Novos campos não alteram compatibilidade com arquivos anteriores',(){
    final source=Sketch(title:'Aula de cartografia');
    source.palette=[0xff332211];
    source.quickTools=['pen','pan'];
    source.layerMode='automatico';
    source.objectPacks['Exemplo']=[{'type':'text','text':'Ola'}];
    source.presets['pen']={'size':5.0,'opacity':.8};
    source.gestures['threeUndo']=true;
    final back=Sketch.fromJson(jsonDecode(source.serialize()) as Map<String,dynamic>);
    expect(back.palette,[0xff332211]);
    expect(back.quickTools,['pen','pan']);
    expect(back.layerMode,'automatico');
    expect(back.objectPacks.containsKey('Exemplo'),true);
    expect(back.gestures['threeUndo'],true);
    final old=source.toJson();
    for(final key in ['palette','quickTools','layerMode','presets','objectPacks','gestures'])old.remove(key);
    final legacy=Sketch.fromJson(old);
    expect(legacy.quickTools,isNotEmpty);
    expect(legacy.layerMode,'manual');
  });

  test('Área, distância e ângulo respeitam coordenadas',(){
    final tri=[InkPoint(0,0),InkPoint(6,0),InkPoint(6,4)];
    expect(AdvancedTools.area(tri),12);
    expect(AdvancedTools.length([InkPoint(0,0),InkPoint(3,4)]),5);
    expect(AdvancedTools.angleDegrees(Offset.zero,const Offset(0,10)),90);
  });

  test('Reconhecimento de reta e elipse mantém limites',(){
    final straight=[for(var i=0;i<20;i++)InkPoint(i*8.0,0)];
    expect(AdvancedTools.recognizeShape(straight),'line');
    final oval=[for(var i=0;i<=50;i++)InkPoint(
      100+80*math.cos(2*math.pi*i/50),100+45*math.sin(2*math.pi*i/50))];
    expect(AdvancedTools.recognizeShape(oval),'ellipse');
  });

  test('Esticamento independente e alinhamento por seleção',(){
    final e=InkElement(layerId:'layer1',points:[InkPoint(1,1),InkPoint(3,5)]);
    AdvancedTools.stretch(e,const Offset(1,1),2,1);
    expect(e.points.last.x,5);
    expect(e.points.last.y,5);
  });

  test('Pacotes de objetos mantêm formato editável e novos IDs',(){
    final element=InkElement(layerId:'old',tool:'rectangle',points:[InkPoint(0,0),InkPoint(100,40)]);
    final json=AdvancedTools.exportPack('Caixa',[element]);
    final imported=AdvancedTools.importPack(json);
    final copies=AdvancedTools.instantiateObject('new',imported,const Offset(50,70));
    expect(copies.length,1);
    expect(copies.first.id,isNot(element.id));
    expect(copies.first.layerId,'new');
    // A posição de inserção representa o limite VISUAL da figura. A caixa
    // inclui metade da espessura do contorno: seus pontos de controle ficam
    // ligeiramente para dentro, sem deslocar a figura no quadro.
    expect(copies.first.bounds.left,closeTo(50,1e-7));
    expect(copies.first.bounds.top,closeTo(70,1e-7));
    expect(copies.first.points.last.x - copies.first.points.first.x,100);
    expect(copies.first.points.last.y - copies.first.points.first.y,40);
    expect(element.points.first.x,0); // o pacote não move o original
    expect(element.points.first.y,0);
    expect(()=>AdvancedTools.importPack('{"schema":"outro","objects":[]}'),throwsFormatException);
  });

  test('Identificadores externos não podem atravessar pastas',(){
    final store=LocalStore();
    expect(()=>store.docFile('../documentos'),throwsFormatException);
  });
}
