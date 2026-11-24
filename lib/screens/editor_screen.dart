import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../models/sketch.dart';
import '../services/advanced_tools.dart';
import '../services/mind_map_vectors.dart';
import '../widgets/vector_handles_painter.dart';
import '../services/tool_catalog.dart';
import '../services/editor_keyboard.dart';
import '../theme/responsive_layout.dart';
import '../services/precision_geometry.dart';
import '../services/selection_transform.dart';
import '../services/viewport_fit.dart';
import '../services/smart_guides.dart';
import '../widgets/smart_guides_painter.dart';
import '../widgets/document_minimap.dart';
import '../services/text_geometry.dart';
import '../services/rich_text.dart';
import '../widgets/inline_text_editor.dart';
import '../services/selection_deletion.dart';
import '../widgets/layer_preview.dart';
import '../widgets/selection_handles_painter.dart';
import '../services/pexels.dart';
import '../services/import_export.dart';
import '../services/clipboard_image.dart';
import '../services/local_store.dart';
import '../services/stroke_optimizer.dart';
import '../services/stroke_stabilizer.dart';
import '../services/stylus_shortcuts.dart';
import '../services/radial_menu_geometry.dart';
import '../widgets/stylus_radial_menu.dart';
import '../services/pdf_page_tools.dart';
import '../widgets/board_painter.dart';

const tools = <String, IconData>{
  'cloud':Icons.cloud_outlined,'balloon':Icons.chat_bubble_outline,
  'rounded rectangle':Icons.crop_16_9,'capsule':Icons.horizontal_rule,'hexagon':Icons.hexagon_outlined,
  'dashed line':Icons.more_horiz,'vector curve':Icons.timeline,
  'connector':Icons.alt_route,'elbow connector':Icons.turn_right,'straight connector':Icons.arrow_right_alt,
  'pen':Icons.edit_outlined, 'fountain':Icons.draw_outlined,
  'dynamic':Icons.gesture_outlined, 'fixed':Icons.create_outlined,
  'wire':Icons.timeline_outlined, 'soft pencil':Icons.brush_outlined,
  'hard pencil':Icons.edit_note_outlined, 'marker':Icons.border_color_outlined,
  'airbrush':Icons.blur_on_outlined,'watercolor':Icons.water_drop_outlined,
  'fill':Icons.format_color_fill_outlined,'dotted':Icons.more_horiz,
  'line':Icons.remove, 'arrow':Icons.arrow_forward, 'rectangle':Icons.crop_square,
  'ellipse':Icons.circle_outlined,'triangle':Icons.change_history,
  'compass':Icons.radio_button_unchecked,'bezier':Icons.timeline_outlined,
  'area':Icons.square_foot,'angle':Icons.architecture,
  'text':Icons.title,'image':Icons.image_outlined,'measure':Icons.straighten,
  'eyedropper':Icons.colorize_outlined,'diamond':Icons.diamond_outlined,
  'select':Icons.select_all,'lasso':Icons.gesture,'pan':Icons.pan_tool_outlined,
  'eraser':Icons.auto_fix_off,'slice':Icons.content_cut,'nudge':Icons.swipe,
  'mask':Icons.layers_clear_outlined,'soft mask':Icons.blur_circular_outlined,
};
const popularTools = ['pen','marker','eraser','select','lasso','pan','text',
  'line','rectangle','ellipse','compass','bezier','arrow','slice','nudge'];

class EditorScreen extends StatefulWidget {
  final Sketch initial;
  final LocalStore store;
  const EditorScreen({super.key,required this.initial,required this.store});
  @override State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with WidgetsBindingObserver {
  late Sketch doc;
  late String activeLayer;
  String tool='pen';
  int color=0xff203047;
  double brush=3.5, opacity=1, smoothing=StrokeStabilizer.defaultStrength, zoom=1;
  int exportPpi=144;
  Offset pan=const Offset(70,70);
  double rotation=0;
  bool recognizeOnHold=true, cursorPreview=true, includeLockedSelection=false;
  String selectionType='todos', selectionLayer='';
  Timer? shapeTimer,holdTimer;
  int? stylusPointer;
  final MultiTouchQuickGestures _touchTaps = MultiTouchQuickGestures();
  int? _temporaryToolPointer;
  String? _toolBeforeStylusShortcut;
  double? _brushBeforeStylusShortcut;
  String _lastInkTool = 'pen';
  bool _quickStylusExpanded = false;

  // O menu radial só aparece quando a ponta da caneta permanece imóvel.
  // Usa o mesmo Listener do quadro, sem listeners adicionais de movimento.
  Timer? _radialTimer;
  int? _radialCandidatePointer, _radialPointer;
  Offset? _radialStart, _radialCenter;
  double _radialRadius = 88;
  int? _radialHover;
  bool _radialArmed = false;
  int _radialUndoDepth = 0;
  int _radialLayerDepth = 0;
  String? _radialLayerBefore;
  int? _deferredRadialTapPointer;
  String? _deferredRadialTapTool;
  Offset? _deferredRadialTapOrigin;

  List<RadialQuickAction> get _radialActions =>
      selectedRadialActions(doc.gestures['radialActions']);

  void _radialFeedback() {
    if(doc.gestures['radialHaptics']!=false) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  bool presenting=false;
  final ValueNotifier<Offset?> hoverPosition=ValueNotifier<Offset?>(null);
  int strokeFrame=0,imageFrame=0;
  int _imageLoadGeneration=0;
  bool _pastingClipboard=false;
  bool fingerPan=false, fullscreen=false, saving=false, focus=false, showArtboard=false;
  bool expandedInkControls=false;
  double? guideVertical,guideHorizontal;
  DateTime? lastVersionSnapshot;
  InkElement? pending;
  InkElement? _textDraft;
  String? _editingTextId;
  RichTextController? _richController;
  FocusNode? _richFocus;
  final FocusNode _editorKeyboardFocus=FocusNode(debugLabel:'Caderno: atalhos');
  double _textWrapWidth=400;
  double get _defaultTextSize {
    final saved=doc.presets['textFontSize'];
    return saved is num && saved.isFinite ? saved.toDouble().clamp(4.0,500.0).toDouble() : 18.0;
  }

  final Set<String> selected={};
  final Map<int,Offset> pointers={};
  final List<String> undoStack=[], redoStack=[];
  final Map<String,ui.Image> imageCache={};
  Timer? autosave;
  Offset? lastPoint, selectionStart;
  bool isMovingSelection=false;
  bool dragOverTrash=false;
  bool selectionDragMoved=false;
  bool shapeRecognized=false;
  String? _vectorDragId;
  int? _vectorDragIndex;
  InkElement? _vectorDragOriginal;
  SelectionHandle? dragHandle;
  Rect? dragInitialBounds;
  Offset? dragStartWorld, dragInitialHandleWorld;
  Map<String, InkElement> dragOriginal={};
  Offset? dragLastWorld;
  double dragTotalRotation=0;
  bool dragDirty=false;
  int? activePointer;
  Size viewport=Size.zero;
  bool needsSave=false;
  int editRevision=0;

  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    doc=widget.initial.clone();
    if(doc.layers.isEmpty) doc.layers.add(InkLayer(name:'Anotações'));
    activeLayer=doc.layers.last.id;
    fingerPan=doc.gestures['fingerPanOnly']==true;
    final saved=doc.presets[tool];
    if(saved is Map) {
      final level=saved['smoothing'];
      if(level is num && level.isFinite) smoothing=level.clamp(0,StrokeStabilizer.maxStrength).toDouble();
    }
    _normalizeLegacyTexts();
    _loadImages();
  }
  Future<void> _loadImages() async {
    final generation=++_imageLoadGeneration;
    final source=doc;
    final requested={for(final e in source.elements) if(e.type=='image') e.id:e.data};
    final decoded=await SketchExchange.decodeAll(source);
    if(!mounted || generation!=_imageLoadGeneration || !identical(doc,source)) {
      for(final image in decoded.values) image.dispose();
      return;
    }
    final current={for(final e in doc.elements) if(e.type=='image') e.id:e.data};
    setState(() {
      // Preserve imagens recém-coladas durante o carregamento assíncrono.
      for(final id in imageCache.keys.toList()) {
        if(!current.containsKey(id) || requested.containsKey(id)) {
          imageCache.remove(id)?.dispose();
        }
      }
      for(final entry in decoded.entries) {
        if(current.containsKey(entry.key) && current[entry.key]==requested[entry.key]) {
          imageCache[entry.key]=entry.value;
        } else {entry.value.dispose();}
      }
      imageFrame++;
    });
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    autosave?.cancel(); shapeTimer?.cancel();holdTimer?.cancel();
    _radialTimer?.cancel();
    for(final image in imageCache.values) image.dispose();
    hoverPosition.dispose();
    _richController?.dispose(); _richFocus?.dispose();
    _editorKeyboardFocus.dispose();
    _touchTaps.reset();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(state!=AppLifecycleState.paused &&
       state!=AppLifecycleState.inactive &&
       state!=AppLifecycleState.hidden) return;
    if(_textDraft!=null) _finishText();
    // Quando o aparelho bloqueia no meio de um traço, preserva a parte
    // já escrita antes que o processo possa ser suspenso pelo Android.
    shapeTimer?.cancel();
    holdTimer?.cancel();
    _cancelRadialMenu();
    if(pending!=null && MindMapVectors.newTools.contains(tool)) {
      pending=null;activePointer=null;pointers.clear();strokeFrame++;
    }
    if(pending!=null && pending!.points.isNotEmpty &&
       !const ['select','lasso','eraser','slice'].contains(tool) && !MindMapVectors.newTools.contains(tool)) {
      _remember();
      _stabilizePendingStroke();
      doc.elements.add(pending!);
      pending=null;
      _changed();
    }
    _endHandleDrag();
    autosave?.cancel();
    unawaited(_save());
  }

  void _remember() {
    final snapshot=doc.serialize();
    // Evita guardar dezenas de cópias de PDFs muito grandes na memória.
    if(snapshot.length<18*1024*1024){
      undoStack.add(snapshot);
      if(undoStack.length>(snapshot.length>4000000?8:40))undoStack.removeAt(0);
    }
    redoStack.clear();
  }
  void _changed() {
    MindMapVectors.refresh(doc);
    doc.touch(); needsSave=true;editRevision++;
    autosave?.cancel();
    autosave=Timer(const Duration(milliseconds:900),_save);
    setState(() {});
  }
  Future<void> _save() async {
    if(!needsSave || saving) return;
    saving=true;
    final revisionAtStart=editRevision;
    final snapshot=doc.clone();
    try {
      // Ponto de recuperação local da versão ANTERIOR; não altera o Drive.
      // Máximo 12 cópias por caderno e uma a cada 15 minutos de trabalho.
      if(lastVersionSnapshot==null ||
          DateTime.now().difference(lastVersionSnapshot!)>=const Duration(minutes:15)) {
        try {
          final previous=await widget.store.get(doc.id);
          if(previous!=null && previous.serialize()!=snapshot.serialize()) {
            if(await widget.store.saveSnapshot(previous))lastVersionSnapshot=DateTime.now();
          }
        } catch (_) { /* Uma falha no histórico não impede salvar o caderno. */ }
      }
      await widget.store.save(snapshot);
      if(editRevision==revisionAtStart) needsSave=false;
      if(mounted)setState(() {});
    } catch(e) {
      _message('Não foi possível salvar. Verifique o armazenamento: $e');
    } finally {
      saving=false;
      if(needsSave) {
        autosave?.cancel();
        autosave=Timer(const Duration(seconds:5),_save);
      }
    }
  }
  Future<void> _leave() async {
    if(_textDraft!=null) {_finishText();return;}
    autosave?.cancel();
    await _save();
    if(needsSave){_message('O desenho ainda não foi salvo; mantenha o editor aberto.');return;}
    if(mounted) Navigator.pop(context,true);
  }
  void _undo() {
    if(_textDraft!=null)return;
    if(undoStack.isEmpty) return;
    redoStack.add(doc.serialize());
    setState(() {
      doc=Sketch.fromJson(jsonDecode(undoStack.removeLast()) as Map<String,dynamic>);
      fingerPan=doc.gestures['fingerPanOnly']==true;
      selected.clear();_endHandleDrag();
      if(doc.layers.isEmpty) doc.layers.add(InkLayer(name:'Anotações'));
      if(doc.layerById(activeLayer)==null) activeLayer=doc.layers.last.id;
      pending=null;
    });
    _loadImages(); _changed();
  }
  void _redo() {
    if(_textDraft!=null)return;
    if(redoStack.isEmpty) return;
    undoStack.add(doc.serialize());
    setState(() {
      doc=Sketch.fromJson(jsonDecode(redoStack.removeLast()) as Map<String,dynamic>);
      fingerPan=doc.gestures['fingerPanOnly']==true;
      selected.clear();_endHandleDrag();
      if(doc.layers.isEmpty) doc.layers.add(InkLayer(name:'Anotações'));
      if(doc.layerById(activeLayer)==null) activeLayer=doc.layers.last.id;
      pending=null;
    });
    _loadImages(); _changed();
  }
  Offset _rotate(Offset v,double radians) => Offset(
    v.dx*math.cos(radians)-v.dy*math.sin(radians),
    v.dx*math.sin(radians)+v.dy*math.cos(radians));
  Offset _world(Offset local) => _rotate(local-pan,-rotation)/zoom;
  Rect get _visibleWorldBounds {
    if(viewport.isEmpty)return Rect.fromLTWH(0,0,doc.artboardW,doc.artboardH);
    final corners=[_world(Offset.zero),_world(Offset(viewport.width,0)),
      _world(Offset(0,viewport.height)),_world(Offset(viewport.width,viewport.height))];
    return Rect.fromLTRB(
      corners.map((p)=>p.dx).reduce(math.min),
      corners.map((p)=>p.dy).reduce(math.min),
      corners.map((p)=>p.dx).reduce(math.max),
      corners.map((p)=>p.dy).reduce(math.max));
  }
  void _centerAt(Offset world,{double? newZoom}) {
    setState(() {
      zoom=(newZoom??zoom).clamp(.12,12).toDouble();rotation=0;
      pan=Offset(viewport.width/2-world.dx*zoom,viewport.height/2-world.dy*zoom);
    });
  }
  void _jumpToBounds(Rect bounds) {
    final fit=ViewportFit.compute(bounds,viewport,maxZoom:3.2,margin:70);
    if(fit==null)return;
    setState(() {zoom=fit.zoom;pan=fit.pan;rotation=0;});
  }
  Rect _miniMapScreenRect()=>Rect.fromLTWH(math.max(0,viewport.width-188),12,176,126);
  Iterable<Rect> _otherVisibleBounds() => doc.elements.where((e)=>
    !selected.contains(e.id) && doc.layerById(e.layerId)?.visible==true)
      .map((e)=>e.bounds);
  void _clearSmartGuides(){guideVertical=null;guideHorizontal=null;}


  /// A área visível passa a conter apenas o conteúdo desenhado, com margem.
  /// Não altera nem a posição nem o tamanho dos objetos do caderno.
  void _fitDrawing() {
    final visible=doc.elements.where((e)=>doc.layerById(e.layerId)?.visible == true);
    final area=ViewportFit.elementBounds(visible);
    if(area==null) {_message('Desenhe algo antes de enquadrar o conteúdo.');return;}
    final fit=ViewportFit.compute(area,viewport);
    if(fit==null) return;
    setState(() {zoom=fit.zoom;pan=fit.pan;rotation=0;});
  }

  /// Mostra contagem de pontos sem serializar o caderno inteiro.
  void _showCanvasStatistics() {
    final strokes=doc.elements.where((e)=>e.type=='stroke').toList();
    final totalPoints=strokes.fold<int>(0,(sum,e)=>sum+e.points.length);
    final images=doc.elements.where((e)=>e.type=='image').length;
    final texts=doc.elements.where((e)=>e.type=='text').length;
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Diagnóstico do caderno'),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Text('Objetos: ${doc.elements.length}'),
          Text('Traços: ${strokes.length}'),
          Text('Pontos nos traços: $totalPoints'),
          Text('Textos: $texts · imagens: $images'),
          Text('Camadas: ${doc.layers.length}'),
          const SizedBox(height:12),
          const Text('Em cadernos com muitos pontos, Otimizar traços pode '
            'reduzir o tamanho do arquivo e acelerar o desenho.'),
        ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Fechar'))],
    ));
  }

  Future<void> _optimizeExistingStrokes() async {
    final candidates=doc.elements.where((e)=>e.type=='stroke' &&
      e.points.length>=3 && !e.locked &&
      !(doc.layerById(e.layerId)?.locked??true) &&
      StrokeOptimizer.canSimplify(e.tool)).toList();
    if(candidates.isEmpty) {_message('Não há traços desbloqueados para otimizar.');return;}
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Otimizar traços?'),
      content:Text('Esta ação reduz pontos redundantes em ${candidates.length} '
        'traços. Pode suavizar detalhes muito pequenos. O Desfazer só funciona '
        'se o caderno couber na memória do histórico. Faça um backup antes '
        'de otimizar um desenho importante.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),
          child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),
          child:const Text('Otimizar'))],
    ));
    if(confirmed!=true || !mounted)return;
    final undoBefore=undoStack.length;
    _remember();
    final undoAvailable=undoStack.length>undoBefore;
    var before=0,after=0;
    for(final item in candidates) {
      before+=item.points.length;
      // Limite conservador para preservar letras e cantos do desenho.
      item.points=StrokeOptimizer.simplify(item.points,tolerance:.60);
      after+=item.points.length;
    }
    _changed();
    _message('Otimização: ${before-after} pontos removidos. '
      '${undoAvailable?'Use Desfazer para voltar.':'Caderno grande: só recupere por backup.'}');
  }

  // O alvo fica acima dos comandos de zoom, sem disputar os gestos do quadro.
  Rect _trashTarget() => Rect.fromLTWH(
    math.max(0,viewport.width-116),math.max(0,viewport.height-162),100,76);
  bool _canTrashSelection() => selected.isNotEmpty &&
    (isMovingSelection || dragHandle==SelectionHandle.move);
  void _dropSelectionInTrash() {
    if(selected.isEmpty) return;
    // O histórico já foi iniciado no início do arrasto; a remoção pode ser desfeita.
    final removed=SelectionDeletion.removeEditable(doc,selected);
    if(removed==0) {_message('A seleção está bloqueada.');return;}
    selected.clear();
    _endHandleDrag();
    isMovingSelection=false;
    dragOverTrash=false;
    selectionDragMoved=false;
    _changed();
    _message('Objetos removidos. Use Desfazer para recuperar.');
  }

  Future<void> _createManualVersion() async {
    await _save();
    if(needsSave)return;
    try {
      final ok=await widget.store.saveSnapshot(doc);
      if(mounted)_message(ok?'Versão de segurança salva neste aparelho.':
        'Caderno muito grande: use Exportar → arquivo editável para fazer backup.');
    } catch(e) {if(mounted)_message('Não foi possível criar o histórico: $e');}
  }
  Future<void> _openVersionHistory() async {
    final dates=await widget.store.snapshotDates(doc.id);
    if(!mounted)return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,builder:(sheet)=>SafeArea(child:ConstrainedBox(
        constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(sheet).height*.73),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Padding(padding:const EdgeInsets.fromLTRB(18,6,18,12),child:Row(children:[
            const Expanded(child:Text('Histórico local',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold))),
            TextButton.icon(onPressed:(){Navigator.pop(sheet);_createManualVersion();},
              icon:const Icon(Icons.add),label:const Text('Criar versão')),
          ])),
          const Padding(padding:EdgeInsets.symmetric(horizontal:18),child:Text(
            'Até 12 versões ficam apenas neste aparelho; não são enviadas pelo Drive. '
            'Restaurar uma versão substitui o estado atual do desenho.')),
          Expanded(child:dates.isEmpty
            ? const Center(child:Text('Nenhuma versão salva ainda.'))
            : ListView.builder(itemCount:dates.length,itemBuilder:(ctx,i){
              final date=dates[i];
              String two(int n)=>n.toString().padLeft(2,'0');
              return ListTile(leading:const Icon(Icons.history),
                title:Text('${two(date.day)}/${two(date.month)}/${date.year} '
                  '${two(date.hour)}:${two(date.minute)}'),
                trailing:const Icon(Icons.restore_outlined),
                onTap:() async {
                  final previous=await widget.store.readSnapshot(doc.id,date);
                  if(!mounted || !sheet.mounted)return;
                  if(previous==null){_message('Esta versão não pôde ser lida.');return;}
                  final yes=await showDialog<bool>(context:sheet,builder:(d)=>AlertDialog(
                    title:const Text('Restaurar esta versão?'),
                    content:const Text('O conteúdo atual será substituído. '
                      'O estado atual pode ser recuperado pelo histórico.'),
                    actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancelar')),
                      FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Restaurar'))]));
                  if(yes!=true || !mounted || !sheet.mounted)return;
                  try {await widget.store.saveSnapshot(doc);}catch(_){}
                  if(!mounted || !sheet.mounted)return;
                  _remember();setState(() {
                    doc=previous;doc.touch();selected.clear();_endHandleDrag();
                    activeLayer=doc.layers.isEmpty?'':doc.layers.last.id;
                  });
                  _loadImages();_changed();Navigator.pop(sheet);
                  _message('Versão restaurada.');
                });
            })),
        ]))));
  }
  Future<void> _addBookmark() async {
    final controller=TextEditingController(text:'Marco ${doc.bookmarks.length+1}');
    final label=await showDialog<String>(context:context,builder:(d)=>AlertDialog(
      title:const Text('Marcar esta região'),
      content:TextField(controller:controller,autofocus:true,
        decoration:const InputDecoration(labelText:'Nome do marcador')),
      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(d,controller.text.trim()),child:const Text('Salvar'))]));
    controller.dispose();
    if(label==null ||label.isEmpty || !mounted)return;
    final center=_world(Offset(viewport.width/2,viewport.height/2));
    _remember();doc.bookmarks.add({'id':newId(),'label':label,'x':center.dx,
      'y':center.dy,'zoom':zoom});_changed();
  }
  void _visitBookmark(Map<String,dynamic> b) {
    final x=(b['x'] as num?)?.toDouble(),y=(b['y'] as num?)?.toDouble();
    if(x==null || y==null)return;
    _centerAt(Offset(x,y),newZoom:(b['zoom'] as num?)?.toDouble());
  }
  Future<void> _openBookmarks() async {
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh)=>SafeArea(
        child:ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*.70),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
            const Expanded(child:Text('Índice do quadro',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold))),
            TextButton.icon(onPressed:() async {Navigator.pop(sheet);await _addBookmark();
              if(mounted)_openBookmarks();},icon:const Icon(Icons.add_location_alt_outlined),
              label:const Text('Marcar área')),
          ])),
          Expanded(child:doc.bookmarks.isEmpty?
            const Center(child:Text('Marque regiões para navegar pela tela infinita.')):
            ListView.builder(itemCount:doc.bookmarks.length,itemBuilder:(_,i){
              final item=doc.bookmarks[i];
              return ListTile(leading:const Icon(Icons.bookmark_outline),
                title:Text((item['label']??'Região').toString()),
                subtitle:Text('Abrir a área salva no quadro'),
                onTap:(){Navigator.pop(sheet);_visitBookmark(item);},
                trailing:IconButton(tooltip:'Excluir marcador',icon:const Icon(Icons.close),
                  onPressed:(){_remember();setState(()=>doc.bookmarks.removeAt(i));
                    _changed();refresh((){});}),
              );
            })),
        ])))));
  }
  Future<void> _linkSelectionToBookmark() async {
    if(selected.isEmpty){_message('Selecione um objeto primeiro.');return;}
    if(!doc.elements.any((e)=>selected.contains(e.id) && !e.locked &&
        !(doc.layerById(e.layerId)?.locked ?? true))) {
      _message('Desbloqueie os objetos antes de alterar vínculos.');return;
    }
    if(doc.bookmarks.isEmpty){_message('Crie primeiro um marcador em Índice do quadro.');return;}
    final value=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(
      title:const Text('Vincular seleção a uma região'),children:[
        for(final b in doc.bookmarks) SimpleDialogOption(
          onPressed:()=>Navigator.pop(c,b['id'].toString()),
          child:Text(b['label'].toString())),
        SimpleDialogOption(onPressed:()=>Navigator.pop(c,''),
          child:const Text('Remover vínculo')),
      ]));
    if(value==null)return;
    _remember();
    for(final item in doc.elements.where((e)=>selected.contains(e.id) &&
        !e.locked && !(doc.layerById(e.layerId)?.locked ?? true))) {
      if(value.isEmpty)item.meta.remove('targetBookmark');
      else item.meta['targetBookmark']=value;
    }
    _changed();
  }
  void _openSelectedLink() {
    for(final item in doc.elements.where((e)=>selected.contains(e.id))) {
      final target=item.meta['targetBookmark'];
      for(final bookmark in doc.bookmarks) {
        if(bookmark['id']==target){_visitBookmark(bookmark);return;}
      }
    }
    _message('Seleção sem vínculo válido. Use Vincular a marcador.');
  }
  Future<void> _searchText() async {
    final controller=TextEditingController();
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh){
      final query=controller.text.trim().toLowerCase();
      final found=query.isEmpty?<InkElement>[]:doc.elements.where((e)=>
        e.type=='text' && e.text.toLowerCase().contains(query)).toList();
      return SafeArea(child:Padding(padding:EdgeInsets.only(
        bottom:MediaQuery.viewInsetsOf(ctx).bottom),child:ConstrainedBox(
        constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*.75),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(
            controller:controller,autofocus:true,onChanged:(_)=>refresh((){}),
            decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
              labelText:'Buscar texto digitado neste caderno',
              helperText:'Busca em caixas de texto; manuscritos requerem OCR.',
              border:OutlineInputBorder()))),
          const SizedBox(height:8),
          Expanded(child:query.isEmpty?const Center(child:Text('Digite uma palavra para buscar.')):
            found.isEmpty?const Center(child:Text('Nenhum texto encontrado.')):
            ListView.builder(itemCount:found.length,itemBuilder:(_,i){
              final e=found[i];
              return ListTile(leading:const Icon(Icons.text_fields),
                title:Text(e.text,maxLines:2,overflow:TextOverflow.ellipsis),
                subtitle:Text(doc.layerById(e.layerId)?.name??'Camada'),
                onTap:(){Navigator.pop(sheet);
                  final layer=doc.layerById(e.layerId);
                  if(layer!=null && !layer.visible){layer.visible=true;_changed();}
                  setState(() {tool='select';selected..clear()..add(e.id);});
                  _jumpToBounds(e.bounds.inflate(25));
                });
            })),
        ]))));
    }));
    controller.dispose();
  }
  void _fitTextBounds(InkElement item, {bool preserveWrap=false}) {
    if(item.type!='text') return;
    final bounds=TextGeometry.measure(item.text,item.size,
      maxWidth:preserveWrap && item.w>0?item.w:null,runs:item.meta['richRuns']);
    item.w=bounds.width;
    item.h=bounds.height;
    item.meta['tightTextBounds']=true;
  }
  void _normalizeLegacyTexts() {
    // O editor anterior criava toda anotação com caixa de largura 500px.
    // Corrigimos só esse caso, sem mudar caixas que o usuário redimensionou.
    var fixed=false;
    for(final item in doc.elements.where((e)=>e.type=='text')) {
      if(item.meta['tightTextBounds']==true) continue;
      if((item.w-500).abs()<.01) {
        _fitTextBounds(item,preserveWrap:true);
        fixed=true;
      }
    }
    if(fixed) {
      doc.touch();needsSave=true;editRevision++;
      autosave=Timer(const Duration(seconds:2),_save);
    }
  }

  void _activateTool(String name) {
    if(_textDraft!=null)_finishText();
    if(_brushBeforeStylusShortcut!=null)brush=_brushBeforeStylusShortcut!;
    _brushBeforeStylusShortcut=null;
    _temporaryToolPointer=null;
    _toolBeforeStylusShortcut=null;
    _endHandleDrag();
    if (const {'pen','fountain','dynamic','fixed','wire','soft pencil',
      'hard pencil','marker','airbrush','watercolor','dotted'}.contains(name)) {
      _lastInkTool=name;
    }
    setState(() {tool=name;pending=null;selected.clear();});
    final saved=doc.presets[name];
    if(saved is Map) setState(() {
      brush=(saved['size'] as num?)?.toDouble()??brush;
      opacity=(saved['opacity'] as num?)?.toDouble()??opacity;
      final level=saved['smoothing'];
      if(level is num && level.isFinite) smoothing=level.clamp(0,StrokeStabilizer.maxStrength).toDouble();
      color=(saved['color'] as num?)?.toInt()??color;
    });
    if(name=='image') _importFile();
  }
  void _autoLayerFor(String toolName) {
    if(doc.layerMode!='automatico')return;
    final category= const {'marker':'Marcadores','watercolor':'Pintura',
      'image':'Imagens','text':'Textos','measure':'Medidas'}[toolName]??'Traços';
    final name='Auto • $category';
    for(final l in doc.layers){if(l.name==name && !l.locked){activeLayer=l.id;return;}}
    final layer=InkLayer(name:name); doc.layers.add(layer); activeLayer=layer.id;
  }
  bool _selectionAllowed(InkElement e) => AdvancedTools.matchesFilter(e,doc,
    includeLocked:includeLockedSelection,layerId:selectionLayer,type:selectionType);
  Offset _snap(Offset v) => doc.snap && doc.gridSpacing.isFinite && doc.gridSpacing > 0
      ? Offset((v.dx/doc.gridSpacing).round()*doc.gridSpacing,
          (v.dy/doc.gridSpacing).round()*doc.gridSpacing)
      : v;
  bool get _canEdit => !(doc.layerById(activeLayer)?.locked ?? false);
  bool _shapeTool(String s) => MindMapVectors.newTools.contains(s) ||
      const ['line','arrow','rectangle','ellipse','triangle','diamond','compass','measure','angle'].contains(s);
  InkElement? get _singleVector {
    if(selected.length!=1 || (tool!='select' && tool!='lasso'))return null;
    for(final item in doc.elements) {
      if(selected.contains(item.id) && MindMapVectors.isVector(item) && !item.locked &&
          doc.layerById(item.layerId)?.locked==false && doc.layerById(item.layerId)?.visible==true)return item;
    }
    return null;
  }
  Map<int,Offset> _curveHandlePositions(InkElement item) => {
    for(var i=0;i<item.points.length;i++)i:SelectionTransform.toScreen(item.points[i].offset,pan,zoom,rotation)};
  Map<int,Offset> _nodePorts(InkElement item) {
    final center=SelectionTransform.toScreen(item.bounds.center,pan,zoom,rotation);
    final result=<int,Offset>{};
    final directions=[const Offset(1,0),const Offset(0,1),const Offset(-1,0)];
    for(var i=0;i<directions.length;i++) {
      final at=MindMapVectors.anchor(item,item.bounds.center+directions[i]*1000);
      final screen=SelectionTransform.toScreen(at,pan,zoom,rotation);
      final delta=screen-center;
      if(delta.distance>.1) result[i]=screen+delta/delta.distance*30;
    }
    return result;
  }
  InkElement? _nodeAt(Offset at,{String? exclude})=>MindMapVectors.nodeAt(doc,at,
    tolerance:14/zoom,exclude:exclude,layerId:focus?activeLayer:null);
  void _vectorStyle(InkElement e) {
    final pattern=doc.presets['mindPattern'];
    if(e.tool=='dashed line')e.meta['vectorPattern']='dash';
    else if(pattern is String)e.meta['vectorPattern']=pattern;
    if(MindMapVectors.nodeTools.contains(e.tool)) {
      final fill=doc.presets['mindFill'];if(fill is num)e.meta['vectorFill']=fill;
    } else {
      final arrow=doc.presets['mindArrow'];if(arrow is String)e.meta['vectorArrow']=arrow;
    }
  }
  void _updateVectorDraft(Offset at) {
    final e=pending;if(e==null)return;
    final rawStart=e.meta['draftStart'];
    final start=rawStart is List && rawStart.length==2 ?
      Offset((rawStart[0] as num).toDouble(),(rawStart[1] as num).toDouble()):e.points.first.offset;
    var a=_snap(start),b=_snap(at);
    if(MindMapVectors.connectorTools.contains(e.tool)) {
      InkElement? source;
      for(final n in doc.elements) {if(n.id==e.meta['sourceNode']){source=n;break;}}
      final target=_nodeAt(at,exclude:source?.id);
      if(source!=null)a=MindMapVectors.anchor(source,target?.bounds.center??at);
      if(target!=null) {
        b=MindMapVectors.anchor(target,source?.bounds.center??start);
        e.meta['targetNode']=target.id;
      } else {e.meta.remove('targetNode');}
    }
    e.points=MindMapVectors.initialPoints(e.tool,a,b);
  }
  void _startPortConnector(InkElement source,Offset at,int pointer) {
    tool='connector';selected.clear();activePointer=pointer;
    pending=InkElement(layerId:activeLayer,tool:tool,color:color,size:brush,opacity:opacity,
      points:[MindMapVectors.point(at)],meta:{'sourceNode':source.id,'draftStart':[at.dx,at.dy]});
    _vectorStyle(pending!);_updateVectorDraft(at);strokeFrame++;
    setState((){});
  }

  double _pressure(PointerEvent e) {
    if (e.kind == ui.PointerDeviceKind.stylus ||
        e.kind == ui.PointerDeviceKind.invertedStylus) {
      return e.pressure.clamp(.1,1.5).toDouble();
    }
    return 1;
  }
  InkPoint _point(Offset at,PointerEvent e)=> InkPoint(at.dx,at.dy,_pressure(e),
    e.kind==ui.PointerDeviceKind.stylus || e.kind==ui.PointerDeviceKind.invertedStylus ? e.tilt : 0,
    e.kind==ui.PointerDeviceKind.stylus || e.kind==ui.PointerDeviceKind.invertedStylus ? e.orientation : 0);
  void _scheduleRecognition() {
    shapeTimer?.cancel();
    if(!recognizeOnHold || !const ['pen','fixed','hard pencil'].contains(tool))return;
    shapeTimer=Timer(const Duration(milliseconds:620),(){
      if(!mounted || pending==null || pending!.points.length<8)return;
      final newTool=AdvancedTools.recognizeShape(pending!.points);
      if(newTool==null)return;
      final original=List<InkPoint>.from(pending!.points);
      setState(() {
        strokeFrame++;
        pending!.tool=newTool;
        pending!.points=AdvancedTools.regularizeShape(original,newTool);
        shapeRecognized=true;
      });
    });
  }
  bool _canOpenRadial(PointerDownEvent e) {
    if(_vectorDragId!=null || MindMapVectors.newTools.contains(tool))return false;
    if(presenting || doc.gestures['radialMenu']==false) return false;
    final isPen=e.kind==ui.PointerDeviceKind.stylus ||
        e.kind==ui.PointerDeviceKind.invertedStylus;
    if(!isPen && !(e.kind==ui.PointerDeviceKind.touch &&
        doc.gestures['radialMenuFinger']==true)) return false;
    if(_temporaryToolPointer!=null || pointers.length!=1 ||
        activePointer!=e.pointer || dragHandle!=null) return false;
    // Ferramentas que disparam diálogos ou mudanças instantâneas não entram
    // em espera de toque prolongado. Desenho permanece sem latência.
    if(const {'nudge'}.contains(tool))return false;
    return true;
  }

  void _cancelRadialCandidate() {
    _radialTimer?.cancel();
    _radialTimer=null;
    _radialCandidatePointer=null;
    _radialStart=null;
  }

  void _cancelRadialMenu() {
    _cancelRadialCandidate();
    _radialPointer=null;
    _radialCenter=null;
    _radialHover=null;
    _radialArmed=false;
    _deferredRadialTapPointer=null;
    _deferredRadialTapTool=null;
    _deferredRadialTapOrigin=null;
  }

  void _scheduleRadial(PointerDownEvent e) {
    if(!_canOpenRadial(e))return;
    _cancelRadialCandidate();
    _radialCandidatePointer=e.pointer;
    _radialStart=e.localPosition;
    final pointer=e.pointer;
    final anchor=e.localPosition;
    _radialTimer=Timer(RadialMenuGeometry.holdDelay,(){
      if(!mounted || _radialCandidatePointer!=pointer ||
          activePointer!=pointer || pointers.length!=1 ||
          !pointers.containsKey(pointer) ||
          (pointers[pointer]!-anchor).distance>RadialMenuGeometry.holdSlop ||
          dragHandle!=null || _temporaryToolPointer!=null || presenting)return;
      _cancelRadialCandidate();
      shapeTimer?.cancel();holdTimer?.cancel();
      // O único ponto provisório nunca foi salvo, portanto pode ser removido.
      // Um toque prolongado não deve criar uma marca no caderno.
      pending=null;shapeRecognized=false;
      // Pressionar sobre um objeto selecionado pode registrar um snapshot de
      // movimento. Se não houve movimento, remova somente esse snapshot vazio.
      if(tool=='select' && isMovingSelection &&
          undoStack.length>_radialUndoDepth)undoStack.removeLast();
      // A criação automática de camadas só deveria acontecer ao efetivamente
      // desenhar; ao abrir o menu sem traço, desfaz a camada vazia provisória.
      if(doc.layers.length>_radialLayerDepth &&
          !doc.elements.any((item)=>item.layerId==activeLayer)) {
        doc.layers.removeWhere((layer)=>layer.id==activeLayer);
        if(_radialLayerBefore!=null &&
            doc.layerById(_radialLayerBefore!)!=null)activeLayer=_radialLayerBefore!;
      }
      isMovingSelection=false;
      activePointer=null;
      pointers.remove(pointer);
      if(pointer==stylusPointer)stylusPointer=null;
      _radialRadius=RadialMenuGeometry.radiusFor(viewport);
      _radialCenter=RadialMenuGeometry.safeCenter(anchor,viewport,_radialRadius);
      _radialPointer=pointer;
      _deferredRadialTapPointer=null;
      _deferredRadialTapTool=null;
      _deferredRadialTapOrigin=null;
      _radialStart=anchor;
      _radialHover=null;
      _radialArmed=false;
      setState((){});
      _radialFeedback();
    });
  }

  void _openRadialImmediately(int pointer, Offset anchor) {
    _cancelRadialCandidate();
    _radialPointer=pointer;
    _radialStart=anchor;
    _radialRadius=RadialMenuGeometry.radiusFor(viewport);
    _radialCenter=RadialMenuGeometry.safeCenter(anchor,viewport,_radialRadius);
    _radialHover=null;
    _radialArmed=false;
    setState((){});
  }

  void _moveRadial(PointerMoveEvent e) {
    if(_radialPointer!=e.pointer || _radialCenter==null)return;
    if(!_radialArmed && _radialStart!=null &&
        (e.localPosition-_radialStart!).distance>RadialMenuGeometry.selectionSlop) {
      _radialArmed=true;
    }
    final index=_radialArmed ? RadialMenuGeometry.hit(
        e.localPosition,_radialCenter!,_radialRadius,
        count:_radialActions.length) : null;
    if(index!=_radialHover) {
      setState(()=>_radialHover=index);
      if(index!=null)_radialFeedback();
    }
  }

  void _finishRadial(PointerEvent e) {
    final action= e is PointerCancelEvent || !_radialArmed ||
        _radialCenter==null ? null : RadialMenuGeometry.hit(
            e.localPosition,_radialCenter!,_radialRadius,
            count:_radialActions.length);
    _cancelRadialMenu();
    if(mounted)setState((){});
    if(action!=null && action<_radialActions.length) {
      _performRadialAction(_radialActions[action].key);
    }
  }

  void _performRadialAction(String action) {
    if(doc.gestures['radialLastAction']!=action) {
      doc.gestures['radialLastAction']=action;
      _changed();
    }
    switch(action) {
      case 'pen': _activateTool('pen');break;
      case 'marker': case 'eraser':case 'select':case 'lasso':case 'pan':
        _activateTool(action);break;
      case 'undo': if(undoStack.isNotEmpty)_undo();break;
      case 'redo': if(redoStack.isNotEmpty)_redo();break;
      case 'colors': _chooseColor();break;
      case 'stroke': _showBrushOptions();break;
      case 'text': case 'line': case 'rectangle': case 'ellipse':
      case 'eyedropper': _activateTool(action);break;
    }
  }

  Rect _quickStylusHitRect() {
    final width=_quickStylusExpanded
        ? math.min(360.0, math.max(48.0,viewport.width-24)) : 48.0;
    final top=doc.gestures['showMiniMap']==true?146.0:12.0;
    return Rect.fromLTWH(12,top,width,48);
  }

  /// A ferramenta do botão lateral é usada apenas durante o contato da caneta.
  /// O botão principal vira borracha; o secundário vira laço.
  void _pointerDown(PointerDownEvent e) {
    if(_textDraft!=null)return;
    if(!_editorKeyboardFocus.hasPrimaryFocus)_editorKeyboardFocus.requestFocus();
    // Um segundo contato cancela o menu, impedindo conflito com zoom ou pan.
    if(_radialPointer!=null) {
      _cancelRadialMenu();
      setState((){});
      return;
    }
    _cancelRadialCandidate();
    _deferredRadialTapPointer=null;
    _deferredRadialTapTool=null;
    _deferredRadialTapOrigin=null;
    // No Windows, botão direito funciona como alternativa para canetas que
    // são identificadas pelo sistema como mouse, sem atrasar a escrita normal.
    if(e.kind==ui.PointerDeviceKind.mouse &&
        (e.buttons & kSecondaryMouseButton)!=0 &&
        doc.gestures['radialMenu']!=false &&
        doc.gestures['radialMouseButton']!=false &&
        pointers.isEmpty && !presenting &&
        !(doc.gestures['quickInkBar']!=false &&
          _quickStylusHitRect().contains(e.localPosition)) &&
        !(doc.gestures['showMiniMap']==true &&
          _miniMapScreenRect().contains(e.localPosition))) {
      _openRadialImmediately(e.pointer,e.localPosition);
      return;
    }
    // Os botões estão dentro do Listener do quadro. Não desenhar sob o painel.
    if(doc.gestures['quickInkBar']!=false &&
       _quickStylusHitRect().contains(e.localPosition))return;
    if(e.kind==ui.PointerDeviceKind.touch && stylusPointer==null) {
      _touchTaps.down(e.pointer,e.localPosition);
    }
    final shortcut=StylusShortcuts.temporaryTool(e.kind,e.buttons,
      useEraser:doc.gestures['stylusQuickEraser']!=false,
      useLasso:doc.gestures['stylusQuickLasso']!=false);
    if(shortcut!=null && _temporaryToolPointer==null && pointers.isEmpty &&
        !(doc.gestures['showMiniMap']==true &&
          _miniMapScreenRect().contains(e.localPosition))) {
      _temporaryToolPointer=e.pointer;
      _toolBeforeStylusShortcut=tool;
      _brushBeforeStylusShortcut=brush;
      if(shortcut=='eraser') brush=math.max(brush,13);
      tool=shortcut;
    }
    final undoDepth=undoStack.length;
    final layerDepth=doc.layers.length;
    // Texto, imagem e conta-gotas executam uma ação no toque. Adiar apenas
    // até soltar a ponta permite abrir o menu radial sem abrir um diálogo.
    final eligibleStylus=e.kind==ui.PointerDeviceKind.stylus ||
        e.kind==ui.PointerDeviceKind.invertedStylus;
    final eligibleFinger=e.kind==ui.PointerDeviceKind.touch &&
        doc.gestures['radialMenuFinger']==true;
    if((tool=='text' && (e.kind!=ui.PointerDeviceKind.mouse || e.buttons==kPrimaryMouseButton) ||
        (doc.gestures['radialMenu']!=false && (eligibleStylus || eligibleFinger) &&
        const {'image','eyedropper'}.contains(tool))) &&
        !(e.kind==ui.PointerDeviceKind.touch && fingerPan) &&
        pointers.isEmpty && _temporaryToolPointer==null &&
        !(doc.gestures['showMiniMap']==true &&
          _miniMapScreenRect().contains(e.localPosition))) {
      pointers[e.pointer]=e.localPosition;
      activePointer=e.pointer;
      if(eligibleStylus)stylusPointer=e.pointer;
      _deferredRadialTapPointer=e.pointer;
      _deferredRadialTapTool=tool;
      _deferredRadialTapOrigin=e.localPosition;
      _radialUndoDepth=undoDepth;
      _radialLayerDepth=layerDepth;
      _radialLayerBefore=activeLayer;
      _scheduleRadial(e);
      return;
    }
    final previousLayer=activeLayer;
    _pointerDownCore(e);
    _radialUndoDepth=undoDepth;
    _radialLayerDepth=layerDepth;
    _radialLayerBefore=previousLayer;
    _scheduleRadial(e);
  }

  void _pointerDownCore(PointerDownEvent e) {
    final point=e.localPosition;
    // Minimap tem gesto próprio e não deve iniciar um novo traço.
    if(doc.gestures['showMiniMap']==true && _miniMapScreenRect().contains(point))return;
    if(e.kind==ui.PointerDeviceKind.touch && stylusPointer!=null)return;
    if(e.kind==ui.PointerDeviceKind.stylus || e.kind==ui.PointerDeviceKind.invertedStylus)stylusPointer=e.pointer;
    pointers[e.pointer]=point;
    shapeTimer?.cancel();holdTimer?.cancel();
    shapeRecognized=false;
    if(pointers.length>1) {
      // Um segundo dedo inicia zoom/pan. Preserva o traço já escrito, em vez
      // de descartá-lo silenciosamente ao trocar de gesto.
      if(pending!=null && pending!.points.length>1 &&
          !const ['select','lasso','eraser','slice'].contains(tool) && !MindMapVectors.newTools.contains(tool)) {
        _remember();
        doc.elements.add(pending!);
        _changed();
      }
      _endHandleDrag();
      pending=null;activePointer=null;
      setState((){});return;}
    if(e.kind==ui.PointerDeviceKind.mouse && e.buttons == kMiddleMouseButton) {
      activePointer=e.pointer;lastPoint=point;return;
    }
    if(e.kind==ui.PointerDeviceKind.touch && fingerPan) {
      activePointer=e.pointer;lastPoint=point;return;
    }
    if(tool=='pan') {activePointer=e.pointer;lastPoint=point;return;}
    final vector=_singleVector;
    if(vector!=null) {
      final tolerance=e.kind==ui.PointerDeviceKind.mouse?12.0:18.0;
      if((MindMapVectors.isCurve(vector) || MindMapVectors.isConnector(vector))) {
        final entries=_curveHandlePositions(vector).entries.toList()
          ..sort((a,b)=>(a.value-point).distance.compareTo((b.value-point).distance));
        for(final entry in entries) {
          if((entry.value-point).distance>tolerance)continue;
          _remember();_vectorDragOriginal=InkElement.fromJson(vector.toJson());
          _vectorDragId=vector.id;_vectorDragIndex=entry.key;
          activePointer=e.pointer;lastPoint=point;setState((){});return;
        }
      } else if(MindMapVectors.isNode(vector) && _canEdit) {
        for(final port in _nodePorts(vector).values) {
          if((port-point).distance>tolerance)continue;
          _startPortConnector(vector,_world(point),e.pointer);return;
        }
      }
    }
    // Antes de iniciar laço ou mover um traço, verifica as alças exibidas
    // ao redor da seleção. A detecção ocorre em pixels de tela e funciona
    // igualmente com mouse, dedo e caneta, inclusive com zoom/rotação.
    if((tool=='select' || tool=='lasso') && selected.isNotEmpty) {
      final editable=doc.elements.where((item)=>selected.contains(item.id) &&
          !item.locked && !(doc.layerById(item.layerId)?.locked ?? true)).toList();
      final bounds=SelectionTransform.selectedBounds(editable,
          minWidth:math.max(10.0,16/zoom),minHeight:math.max(10.0,16/zoom));
      if(bounds!=null) {
        final handle=SelectionTransform.hitTest(point,bounds,
            pan:pan,zoom:zoom,viewRotation:rotation,
            radius:e.kind==ui.PointerDeviceKind.mouse?11.0:19.0);
        if(handle!=null) {
          dragHandle=handle;
          dragInitialBounds=bounds;
          dragStartWorld=_world(point);
          dragLastWorld=dragStartWorld;
          dragTotalRotation=0;
          dragInitialHandleWorld=SelectionTransform.handleWorldPosition(handle,bounds);
          dragOriginal={for(final item in editable)
            item.id: InkElement.fromJson(item.toJson())};
          dragDirty=false;
          selectionDragMoved=false;
          dragOverTrash=false;
          activePointer=e.pointer;
          lastPoint=point;
          setState(() {});
          return;
        }
      }
    }
    if(tool=='eyedropper') {
      _pickCanvasColor(_world(point));
      return;
    }
    if(tool!='select' && tool!='lasso' && tool!='eraser' && tool!='slice' && tool!='nudge') _autoLayerFor(tool);
    if(!_canEdit && tool!='select' && tool!='lasso') {
      _message('A camada está bloqueada.'); return;
    }
    activePointer=e.pointer;
    final at=_world(point);
    lastPoint=point;
    if(tool=='select' || tool=='lasso') {
      final hit=_hitTest(at);
      if(hit != null && tool=='select') {
        if(!selected.contains(hit.id)) {selected..clear()..add(hit.id);}
        if(hit.group != null) {
          selected.addAll(doc.elements.where((it)=>it.group==hit.group).map((it)=>it.id));
        }
        isMovingSelection=true;
        selectionDragMoved=false;
        dragOverTrash=false;
        _remember();
      } else {
        selected.clear();
        selectionStart=at;
        pending=InkElement(layerId:activeLayer,tool:tool,points:[InkPoint(at.dx,at.dy)]);
        isMovingSelection=false;
      }
      setState((){}); return;
    }
    if(tool=='text') return;
    if(tool=='image') { _importFile(); return; }
    if(tool=='nudge') { _remember(); return; }
    // Não serializa o caderno inteiro no instante em que a caneta toca a tela.
    // O snapshot é capturado antes de confirmar o traço no pointerUp.
    pending=InkElement(layerId:activeLayer,tool:tool,color:color,
      size:brush,opacity:opacity,points:[_point(at,e)],
      meta:{'pressureInk':doc.gestures['pressureInk']!=false});
    if(MindMapVectors.newTools.contains(tool) || MindMapVectors.lineTools.contains(tool) || MindMapVectors.nodeTools.contains(tool)) {
      _vectorStyle(pending!);
      if(MindMapVectors.newTools.contains(tool)) {
        pending!.meta['draftStart']=[at.dx,at.dy];
        if(MindMapVectors.connectorTools.contains(tool)) {
          final source=_nodeAt(at);if(source!=null)pending!.meta['sourceNode']=source.id;
        }
      }
    }
    _scheduleRecognition();
    if(doc.gestures['holdSelect']==true && const ['pen','fixed','hard pencil'].contains(tool)) {
      holdTimer=Timer(const Duration(milliseconds:700),(){
        if(!mounted || pending==null || pending!.points.length!=1)return;
        final hit=_hitTest(_world(point));
        if(hit!=null)setState((){selected..clear()..add(hit.id);pending=null;tool='select';});
      });
    }
    setState((){});
  }
  void _pointerMove(PointerMoveEvent e) {
    if(_textDraft!=null)return;
    if(_radialPointer==e.pointer) {
      _moveRadial(e);
      return;
    }
    if(_radialCandidatePointer==e.pointer && _radialStart!=null &&
        (e.localPosition-_radialStart!).distance>RadialMenuGeometry.holdSlop) {
      _cancelRadialCandidate();
    }
    if(e.pointer==_deferredRadialTapPointer) {
      if(_deferredRadialTapOrigin!=null &&
          (e.localPosition-_deferredRadialTapOrigin!).distance>
              RadialMenuGeometry.holdSlop)_cancelRadialCandidate();
      pointers[e.pointer]=e.localPosition;
      return;
    }
    if(e.kind==ui.PointerDeviceKind.touch) {
      _touchTaps.move(e.pointer,e.localPosition);
    }
    _pointerMoveCore(e);
  }

  void _pointerMoveCore(PointerMoveEvent e) {
    final current=e.localPosition;
    final previous=pointers[e.pointer];
    if(previous == null) return;
    if((current-previous).distance>3)holdTimer?.cancel();
    if(pointers.length>1) {
      final before=pointers.values.toList();
      pointers[e.pointer]=current;
      final after=pointers.values.toList();
      if(before.length>=2 && after.length>=2) {
        final oldCenter=(before[0]+before[1])/2;
        final newCenter=(after[0]+after[1])/2;
        final oldDistance=(before[0]-before[1]).distance;
        final newDistance=(after[0]-after[1]).distance;
        final next=(zoom * (oldDistance<2?1:newDistance/oldDistance)).clamp(.12,12.0).toDouble();
        final worldAtCenter=_world(oldCenter);
        final oldVector=before[1]-before[0],newVector=after[1]-after[0];
        final deltaAngle=math.atan2(newVector.dy,newVector.dx)-math.atan2(oldVector.dy,oldVector.dx);
        setState(() {zoom=next;rotation+=deltaAngle;
          pan=newCenter-_rotate(worldAtCenter*zoom,rotation);});
      }
      return;
    }
    pointers[e.pointer]=current;
    if(activePointer!=e.pointer) return;
    final delta=current-previous;
    if(tool=='pan' || (e.kind==ui.PointerDeviceKind.touch && fingerPan) ||
        (e.kind==ui.PointerDeviceKind.mouse && e.buttons==kMiddleMouseButton)) {
      setState(() {pan+=delta;}); return;
    }
    if(_vectorDragId!=null && _vectorDragIndex!=null) {
      final position=doc.elements.indexWhere((e)=>e.id==_vectorDragId);
      if(position<0){_endHandleDrag();return;}
      final item=doc.elements[position];
      final index=_vectorDragIndex!;
      if(index==0)item.meta.remove('sourceNode');
      if(index==item.points.length-1)item.meta.remove('targetNode');
      MindMapVectors.endpoint(item,index,_world(current));_changed();return;
    }
    if(dragHandle!=null && dragInitialBounds!=null && dragStartWorld!=null &&
       dragOriginal.isNotEmpty) {
      final currentWorld=_world(current);
      final originalBounds=dragInitialBounds!;
      final originals=dragOriginal.values.toList();
      List<InkElement> changed;
      if(dragHandle==SelectionHandle.move) {
        var movement=currentWorld-dragStartWorld!;
        if(doc.gestures['magneticSnap']!=false) {
          final snapped=SmartGuides.translate(originalBounds,movement,
              _otherVisibleBounds(),zoom:zoom);
          movement=snapped.delta;
          guideVertical=snapped.vertical;guideHorizontal=snapped.horizontal;
        }
        changed=SelectionTransform.translate(originals,movement);
        selectionDragMoved=selectionDragMoved || (current-previous).distance>2;
        dragOverTrash=selectionDragMoved && _trashTarget().contains(current);
      } else if(dragHandle==SelectionHandle.rotate) {
        _clearSmartGuides();
        final step=SelectionTransform.angleBetween(
            dragLastWorld ?? dragStartWorld!,currentWorld,originalBounds.center);
        dragTotalRotation += step;
        dragLastWorld=currentWorld;
        // Shift + alça de rotação: encaixe em múltiplos de 15 graus.
        final radians=HardwareKeyboard.instance.isShiftPressed
            ? (dragTotalRotation/(math.pi/12)).round()*(math.pi/12)
            : dragTotalRotation;
        changed=SelectionTransform.rotate(originals,originalBounds.center,radians);
      } else {
        _clearSmartGuides();
        // Impede o salto inicial ao agarrar a borda do botão em vez do centro.
        final adjusted=currentWorld+(dragInitialHandleWorld!-dragStartWorld!);
        final rawTarget=SelectionTransform.resizedBounds(originalBounds,
            dragHandle!,adjusted,minDimension:math.max(3.0,5/zoom));
        final target=HardwareKeyboard.instance.isShiftPressed
          ? SelectionTransform.keepAspect(originalBounds,rawTarget,dragHandle!)
          : rawTarget;
        changed=SelectionTransform.resize(originals,originalBounds,target);
      }
      if(!dragDirty) {_remember();dragDirty=true;}
      final byId={for(final item in changed) item.id:item};
      for(var i=0;i<doc.elements.length;i++) {
        final replacement=byId[doc.elements[i].id];
        if(replacement!=null)doc.elements[i]=replacement;
      }
      _changed();
      return;
    }
    if(tool=='select' && isMovingSelection && selected.isNotEmpty) {
      selectionDragMoved=selectionDragMoved || delta.distance>2;
      dragOverTrash=selectionDragMoved && _trashTarget().contains(current);
      final editable=doc.elements.where((item)=>selected.contains(item.id) &&
        !item.locked && !(doc.layerById(item.layerId)?.locked ?? true)).toList();
      var movement=_rotate(delta,-rotation)/zoom;
      if(doc.gestures['magneticSnap']!=false && editable.isNotEmpty) {
        final bounds=SelectionTransform.selectedBounds(editable);
        if(bounds!=null) {
          final matched=SmartGuides.translate(bounds,movement,
              _otherVisibleBounds(),zoom:zoom);
          movement=matched.delta;
          guideVertical=matched.vertical;guideHorizontal=matched.horizontal;
        }
      }
      for(final item in editable) {item.translate(movement.dx,movement.dy);}
      _changed();return;
    }
    if(tool=='lasso' || tool=='select') {
      final at=_world(current);
      if(pending!=null) {
        if(tool=='select') {
          if(pending!.points.length == 1) pending!.points.add(InkPoint(at.dx,at.dy));
          else pending!.points.last=InkPoint(at.dx,at.dy);
        } else {pending!.points.add(InkPoint(at.dx,at.dy));}
      }
      strokeFrame++;setState((){});return;
    }
    if(tool=='nudge') {
      final at=_world(current);
      for(final item in doc.elements.where((e)=>e.layerId==activeLayer && !e.locked && e.type=='stroke')) {
        for(final p in item.points) {
          final d=(p.offset-at).distance;
          if(d < brush*8) {final movement=_rotate(delta,-rotation)/zoom;
          p.x+=movement.dx*(1-d/(brush*8));p.y+=movement.dy*(1-d/(brush*8));}
        }
      }
      _changed();return;
    }
    if(pending!=null) {
      if(shapeRecognized) return; // Não corromper a figura ao levantar a caneta.
      final at=_world(current);
      var shouldDraw=false;
      if(MindMapVectors.newTools.contains(tool)) {
        _updateVectorDraft(at);shouldDraw=true;
      } else if(_shapeTool(tool)) {
        if(pending!.points.length==1) pending!.points.add(InkPoint(at.dx,at.dy));
        else pending!.points.last=InkPoint(at.dx,at.dy);
        shouldDraw=true;
      } else {
        final next=_point(at,e);
        final previous=pending!.points.last;
        if(StrokeOptimizer.shouldSample(previous,next,zoom:zoom,
          fastMode:doc.gestures['smoothPerformance']!=false &&
            !(smoothing>.75 && StrokeStabilizer.supports(tool)))) {
          pending!.points.add(next);
          shouldDraw=true;
        }
      }
      _scheduleRecognition();
      if(shouldDraw){strokeFrame++;setState((){});}
    }
  }
  void _pointerUp(PointerEvent e) {
    if(_textDraft!=null)return;
    if(_radialPointer==e.pointer) {
      _touchTaps.reset();
      _finishRadial(e);
      return;
    }
    if(_radialCandidatePointer==e.pointer)_cancelRadialCandidate();
    if(e.pointer==_deferredRadialTapPointer) {
      final action=_deferredRadialTapTool;
      final origin=_deferredRadialTapOrigin;
      _deferredRadialTapPointer=null;
      _deferredRadialTapTool=null;
      _deferredRadialTapOrigin=null;
      pointers.remove(e.pointer);
      if(activePointer==e.pointer)activePointer=null;
      if(stylusPointer==e.pointer)stylusPointer=null;
      if(e is! PointerCancelEvent && origin!=null &&
          (e.localPosition-origin).distance<=RadialMenuGeometry.selectionSlop) {
        if(action=='text') {_touchTaps.reset();_insertText(_world(origin));}
        if(action=='image') _importFile();
        if(action=='eyedropper') _pickCanvasColor(_world(e.localPosition));
      }
      return;
    }
    final fingers=e.kind==ui.PointerDeviceKind.touch
      ? _touchTaps.up(e.pointer,e.localPosition,
        cancelled:e is PointerCancelEvent)
      : null;
    _pointerUpCore(e);
    if(e.pointer==_temporaryToolPointer) {
      _temporaryToolPointer=null;
      final old=_toolBeforeStylusShortcut;
      final previousBrush=_brushBeforeStylusShortcut;
      _toolBeforeStylusShortcut=null;
      _brushBeforeStylusShortcut=null;
      // Depois do laço, continua em Selecionar para mover a seleção obtida.
      if(mounted) setState(() {
        tool=tool=='lasso' && selected.isNotEmpty ? 'select' : (old??'pen');
        if(previousBrush!=null)brush=previousBrush;
      });
    }
    if(fingers!=null && mounted &&
      ((fingers==2 && doc.gestures['twoFingerUndo']!=false) ||
       (fingers==3 && doc.gestures['threeUndo']==true))) {
      _undo();
    } else if(fingers!=null && mounted &&
      ((fingers==3 && doc.gestures['threeFingerRedo']==true) ||
       (fingers==4 && doc.gestures['fourRedo']==true))) {
      _redo();
    }
  }

  void _pointerUpCore(PointerEvent e) {
    shapeTimer?.cancel();holdTimer?.cancel();
    if(guideVertical!=null || guideHorizontal!=null) {
      _clearSmartGuides();if(mounted)setState((){});
    }
    if(e.pointer==stylusPointer)stylusPointer=null;
    pointers.remove(e.pointer);
    if(e.pointer!=activePointer) return;
    activePointer=null;
    if(pointers.isNotEmpty) return;
    if(_vectorDragId!=null && _vectorDragIndex!=null) {
      final id=_vectorDragId,index=_vectorDragIndex!;
      final i=doc.elements.indexWhere((item)=>item.id==id);
      if(i>=0) {
        if(e is PointerCancelEvent && _vectorDragOriginal!=null)doc.elements[i]=_vectorDragOriginal!;
        else {
          final item=doc.elements[i];
          if(MindMapVectors.isConnector(item) && (index==0 || index==item.points.length-1)) {
            final key=index==0?'sourceNode':'targetNode';
            final other=index==0?'targetNode':'sourceNode';
            final node=_nodeAt(_world(e.localPosition),exclude:item.meta[other] as String?);
            if(node!=null)item.meta[key]=node.id;
          }
        }
      }
      _vectorDragId=null;_vectorDragIndex=null;_vectorDragOriginal=null;_changed();return;
    }
    if(dragHandle!=null) {
      if(dragHandle==SelectionHandle.move && selectionDragMoved &&
          _trashTarget().contains(e.localPosition)) {
        _dropSelectionInTrash();return;
      }
      if(dragDirty && dragHandle!=SelectionHandle.move && dragHandle!=SelectionHandle.rotate) {
        for(final item in doc.elements.where((e)=>dragOriginal.containsKey(e.id) && e.type=='text')) {
          _fitTextBounds(item,preserveWrap:true);
        }
        _changed();
      }
      _endHandleDrag();
      selectionDragMoved=false;
      dragOverTrash=false;
      setState(() {});
      return;
    }
    if(tool=='select' && isMovingSelection && selectionDragMoved &&
        _trashTarget().contains(e.localPosition)) {
      _dropSelectionInTrash();return;
    }
    if(tool=='pan' || (e.kind==ui.PointerDeviceKind.touch && fingerPan)) return;
    if(tool=='select' || tool=='lasso') {
      if(pending!=null && pending!.points.length>1) {
        if(tool=='select') {
          final region=Rect.fromPoints(pending!.points.first.offset,pending!.points.last.offset);
          selected.addAll(doc.elements.where((it)=>_selectionAllowed(it) && it.bounds.overlaps(region)).map((it)=>it.id));
        } else {
          final polygon=pending!.points.map((p)=>p.offset).toList();
          for(final item in doc.elements) {
            if(_selectionAllowed(item) &&
                PrecisionGeometry.polygonTouchesElement(polygon,item)) selected.add(item.id);
          }
        }
      }
      pending=null;selectionStart=null;isMovingSelection=false;
      selectionDragMoved=false;dragOverTrash=false;
      setState((){});return;
    }
    if(tool=='nudge') {_changed();return;}
    if(pending == null) return;
    if(e is! PointerCancelEvent && !shapeRecognized && !_shapeTool(tool) &&
      tool!='eraser' && tool!='slice' && pending!.points.isNotEmpty) {
      // Amostragem durante o arraste nunca pode cortar a ponta da letra.
      final end=_world(e.localPosition);
      final last=pending!.points.last;
      if((end-last.offset).distance>.05/zoom) {
        pending!.points.add(InkPoint(end.dx,end.dy,last.p,last.tilt,last.angle));
      }
    }
    if(MindMapVectors.newTools.contains(tool)) {
      if(e is PointerCancelEvent){pending=null;strokeFrame++;setState((){});return;}
      final start=pending!.meta['draftStart'];
      if(start is List && start.length==2 &&
          (_world(e.localPosition)-Offset((start[0] as num).toDouble(),(start[1] as num).toDouble())).distance<3/zoom) {
        pending=null;strokeFrame++;setState((){});return;
      }
      _updateVectorDraft(_world(e.localPosition));
      final item=pending!;item.meta.remove('draftStart');
      if((item.points.first.offset-item.points.last.offset).distance<3/zoom ||
          (MindMapVectors.isNode(item) && (MindMapVectors.localBounds(item).shortestSide<3/zoom))) {
        pending=null;strokeFrame++;setState((){});return;
      }
      _remember();doc.elements.add(item);pending=null;shapeRecognized=false;
      if(MindMapVectors.isCurve(item) || MindMapVectors.isConnector(item)) {
        tool='select';selected..clear()..add(item.id);
      }
      _changed();return;
    }
    _remember();
    if(tool=='eraser' || tool=='slice') {
      _applyErase(pending!,slice:tool=='slice');
    } else {
      if(_shapeTool(tool)) {
        pending!.points=[InkPoint(_snap(pending!.points.first.offset).dx,
          _snap(pending!.points.first.offset).dy),
          InkPoint(_snap(pending!.points.last.offset).dx,
          _snap(pending!.points.last.offset).dy)];
      }
      _stabilizePendingStroke();
      doc.elements.add(pending!);
    }
    pending=null;
    shapeRecognized=false;
    _changed();
  }
  void _stabilizePendingStroke() {
    final stroke=pending;
    if(stroke==null || shapeRecognized || stroke.type!='stroke' ||
        !StrokeStabilizer.supports(stroke.tool) || smoothing<=0) return;
    final original=stroke.points;
    stroke.points=StrokeStabilizer.finish(original,zoom:zoom,strength:smoothing);
    if(original.isNotEmpty && !identical(original.first,stroke.points.first)) {
      stroke.meta['stabilizedInk']=true;
    }
    if(smoothing>.75 && stroke.points.length>=2) {
      stroke.meta['stabilizedInk']=true;
      stroke.meta['polishedInk']=true;
    }
  }
  void _endHandleDrag() {
    _vectorDragId=null;_vectorDragIndex=null;_vectorDragOriginal=null;
    dragHandle=null;
    dragInitialBounds=null;
    dragStartWorld=null;
    dragInitialHandleWorld=null;
    dragOriginal.clear();
    dragLastWorld=null;
    dragTotalRotation=0;
    dragDirty=false;
    dragOverTrash=false;
    _clearSmartGuides();
  }

  void _mouseScroll(PointerScrollEvent e) {
    if(_textDraft!=null)return;
    if (e.scrollDelta.dy == 0) return;
    final next=(zoom*(e.scrollDelta.dy > 0 ? 0.9 : 1.1)).clamp(.12,12.0).toDouble();
    final worldAtMouse=_world(e.localPosition);
    setState(() {zoom=next;pan=e.localPosition-_rotate(worldAtMouse*zoom,rotation);});
  }
  InkElement? _hitTest(Offset at) {
    for(final item in doc.elements.reversed) {
      if(!_selectionAllowed(item)) continue;
      final tolerance=math.max(item.size / 2, 6 / zoom);
      if(item.type!='stroke' || const ['fill','area'].contains(item.tool)) {
        if(item.bounds.inflate(tolerance).contains(at)) return item;
      } else if (MindMapVectors.isNode(item) || item.tool=='arrow') {
        // Geometrias de dois pontos: a caixa determina a área editável.
        if(item.bounds.inflate(tolerance).contains(at)) return item;
      } else if(PrecisionGeometry.strokeNear(at,item,tolerance)) {
        return item;
      }
    }
    return null;
  }

  /// Conta-gotas: lê RGBA do bitmap importado somente quando necessário.
  /// O arquivo original permanece intacto. Em imagens rotacionadas, usamos
  /// a transformação inversa da rotação para localizar o pixel.
  Future<void> _pickCanvasColor(Offset world) async {
    final hit=_hitTest(world);
    if(hit==null) return;
    if(hit.type!='image') {
      if(mounted)setState(()=>color=hit.color);
      return;
    }
    final image=imageCache[hit.id];
    if(image==null || hit.w==0 || hit.h==0) return;
    final center=Offset(hit.x+hit.w/2,hit.y+hit.h/2);
    final sample=center+_rotate(world-center,-hit.rotation);
    final relativeX=(sample.dx-hit.x)/hit.w;
    final relativeY=(sample.dy-hit.y)/hit.h;
    if(relativeX<0||relativeX>1||relativeY<0||relativeY>1) return;
    // Restringe bitmaps enormes para não reservar grandes buffers RGBA.
    if(image.width*image.height>16000000) {
      _message('Imagem muito grande para o conta-gotas; escolha um bitmap menor.');
      return;
    }
    final bytes=await image.toByteData(format:ui.ImageByteFormat.rawRgba);
    if(bytes==null||!mounted) return;
    final x=(relativeX*(image.width-1)).round();
    final y=(relativeY*(image.height-1)).round();
    final offset=(y*image.width+x)*4;
    final a=bytes.getUint8(offset+3);
    if(a<16) return; // Pixel transparente não altera a cor de escrita.
    final r=bytes.getUint8(offset),g=bytes.getUint8(offset+1),b=bytes.getUint8(offset+2);
    setState(()=>color=0xff000000|(r<<16)|(g<<8)|b);
  }

  void _applyErase(InkElement eraser,{required bool slice}) {
    final radius=math.max(3.0,brush*1.6);
    final revised=<InkElement>[];
    for(final e in doc.elements) {
      final layer=doc.layerById(e.layerId);
      if(e.type!='stroke' || e.layerId!=activeLayer ||
          layer?.locked == true || e.locked ||
          !e.bounds.overlaps(eraser.bounds.inflate(radius))) {
        revised.add(e);
        continue;
      }
      final pieces=PrecisionGeometry.sliceStroke(e,eraser.points,radius);
      if(slice) {
        revised.addAll(pieces);
      } else if(pieces.length==1 && identical(pieces.first,e)) {
        revised.add(e);
      }
    }
    doc.elements=revised;
  }
  void _insertText(Offset at) {
    if(!mounted || presenting || _textDraft!=null)return;
    for(final element in doc.elements.reversed) {
      final layer=doc.layerById(element.layerId);
      if(element.type=='text' && !element.locked && layer!=null && layer.visible && !layer.locked &&
          (!focus || activeLayer==element.layerId) && element.bounds.contains(at)) {
        _beginText(element,existing:true);return;
      }
    }
    if(doc.layerMode!='automatico' && !_canEdit) {_message('A camada está bloqueada.');return;}
    final screen=SelectionTransform.toScreen(at,pan,zoom,rotation);
    _textWrapWidth=math.max(80.0/zoom,(viewport.width-screen.dx-12)/zoom);
    _beginText(InkElement(layerId:activeLayer,type:'text',text:'',color:color,
      opacity:opacity,size:_defaultTextSize,x:at.dx,y:at.dy),existing:false);
  }
  void _beginText(InkElement item,{required bool existing}) {
    if(_textDraft!=null)return;
    shapeTimer?.cancel();holdTimer?.cancel();_cancelRadialMenu();
    pointers.clear();activePointer=null;stylusPointer=null;_touchTaps.reset();
    if(existing) {
      final natural=TextGeometry.measure(item.text,item.size,runs:item.meta['richRuns']);
      final screen=SelectionTransform.toScreen(Offset(item.x,item.y),pan,zoom,rotation);
      final available=math.max(80.0/zoom,(viewport.width-screen.dx-12)/zoom);
      _textWrapWidth=item.w>0 && natural.width>item.w+2 && natural.height<item.h-1
        ? item.w : math.max(item.w,available);
    }
    final draft=InkElement.fromJson(item.toJson());
    final controller=RichTextController(text:item.text,runs:item.meta['richRuns']);
    final focusNode=FocusNode();
    setState(() {
      selected.clear();pending=null;_textDraft=draft;
      _editingTextId=existing?item.id:null;
      _richController=controller;_richFocus=focusNode;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted && identical(_richFocus,focusNode)) focusNode.requestFocus();
    });
  }
  void _finishText({bool cancel=false}) {
    final draft=_textDraft, controller=_richController, node=_richFocus;
    if(draft==null || controller==null)return;
    final previousId=_editingTextId;
    node?.unfocus();
    setState(() {_textDraft=null;_editingTextId=null;_richController=null;_richFocus=null;});
    if(!cancel && controller.text.trim().isNotEmpty) {
      final previous=doc.elements.indexWhere((e)=>e.id==previousId);
      final allowed=previousId==null ? (doc.layerMode=='automatico'||_canEdit) :
        previous>=0 && !doc.elements[previous].locked && !(doc.layerById(draft.layerId)?.locked??true);
      final unchanged=previous>=0 && doc.elements[previous].text==controller.text &&
        doc.elements[previous].size==draft.size &&
        jsonEncode(doc.elements[previous].meta['richRuns']??[])==jsonEncode(controller.runs);
      if(allowed && !unchanged) {
        _remember();
        if(previousId==null) {_autoLayerFor('text');draft.layerId=activeLayer;}
        draft.text=controller.text;
        draft.meta['richRuns']=controller.runs;
        final measured=TextGeometry.measure(draft.text,draft.size,maxWidth:_textWrapWidth,
          runs:draft.meta['richRuns']);
        draft.w=math.min(_textWrapWidth,measured.width);draft.h=measured.height;
        draft.meta['tightTextBounds']=true;
        if(previous>=0)doc.elements[previous]=draft;else doc.elements.add(draft);
        _changed();
      } else if(!allowed) {_message('A camada ou texto não está mais editável.');}
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {controller.dispose();node?.dispose();
      if(mounted && _textDraft==null && ModalRoute.of(context)?.isCurrent==true)_editorKeyboardFocus.requestFocus();
    });
  }
  Future<void> _chooseDefaultTextSize() async {
    final value=await _askNumber(title:'Tamanho padrão do texto',label:'Fonte em px do quadro',
      value:_defaultTextSize,min:4,max:500);
    if(value==null||!mounted)return;
    _remember();doc.presets['textFontSize']=value;_changed();
  }
  Future<void> _changeDraftSize({bool range=false}) async {
    final draft=_textDraft, controller=_richController;
    if(draft==null || controller==null)return;
    final selection=controller.selection;
    final value=await _askNumber(title:range?'Tamanho do trecho':'Tamanho da caixa de texto',
      label:'Fonte em px do quadro',value:range?draft.size*controller.current.scale:draft.size,min:4,max:500);
    if(!mounted || value==null || !identical(_textDraft,draft))return;
    if(range) {
      if(selection.isValid && selection.end<=controller.text.length)controller.selection=selection;
      controller.setRelativeSize(value/draft.size);
    } else {setState(()=>draft.size=value);}
    _richFocus?.requestFocus();
  }
  Widget _inlineTextOverlay() {
    final draft=_textDraft!;
    var world=Offset(draft.x,draft.y);
    if(_editingTextId!=null && draft.rotation!=0) {
      final center=draft.bounds.center;
      world=center+_rotate(world-center,draft.rotation);
    }
    final anchor=SelectionTransform.toScreen(world,pan,zoom,rotation);
    // On keyboard resize pan the canvas, not the text object, so its world
    // position stays exact. Avoid a loop on extremely small windows.
    if(viewport.height>100 && (anchor.dy<0 || anchor.dy>viewport.height-85 ||
        anchor.dx<0 || anchor.dx>viewport.width-80)) {
      final target=Offset(anchor.dx.clamp(0.0,math.max(0.0,viewport.width-80)).toDouble(),
        anchor.dy.clamp(0.0,math.max(0.0,viewport.height-85)).toDouble());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted && identical(_textDraft,draft))setState(()=>pan+=target-anchor);
      });
    }
    return Positioned.fill(child:InlineTextEditor(controller:_richController!,focusNode:_richFocus!,
      anchor:anchor,width:_textWrapWidth,fontSize:draft.size,zoom:zoom,rotation:rotation+draft.rotation,
      color:Color(draft.color).withValues(alpha:draft.opacity.clamp(0,1).toDouble()),
      boardColor:colorFromHex(doc.background),palette:doc.palette,
      onAccept:_finishText,onCancel:()=>_finishText(cancel:true),
      onSize:()=>_changeDraftSize(),onRangeSize:()=>_changeDraftSize(range:true)));
  }
  Future<void> _importFile() async {
    try {
      final bytes=await SketchExchange.pickFile(['png','jpg','jpeg','pdf','psd']);
      if(bytes==null) return;
      final isPdf=bytes.length>4 && String.fromCharCodes(bytes.take(4))=='%PDF';
      final imported = isPdf
        ? await SketchExchange.importPdf(doc,bytes)
        : await SketchExchange.importImage(doc,bytes,at:_world(const Offset(110,120)));
      _remember();
      // PDF inserido no fundo, anotações continuam na camada ativa.
      if(isPdf) {
        final backgrounds=InkLayer(name:'Base PDF ${DateTime.now().day}/${DateTime.now().month}',locked:true);
        doc.layers.insert(0,backgrounds);
        for(final e in imported) {e.layerId=backgrounds.id; e.locked=true;}
        doc.elements.insertAll(0,imported);
      } else {for(final e in imported){e.layerId=activeLayer;}doc.elements.addAll(imported);}
      await _loadImages();
      _changed();
      _message(isPdf?'PDF importado (${imported.length} páginas, máximo 40).':'Imagem adicionada.');
    } catch(e) {_message('Falha na importação: $e');}
  }
  Future<double?> _askNumber({required String title,required String label,
      required double value,double min=.1,double max=50000}) async {
    final controller=TextEditingController(text:value.toStringAsFixed(1));
    final result=await showDialog<double>(context:context,builder:(dialog)=>AlertDialog(
      title:Text(title),
      content:TextField(controller:controller,autofocus:true,
        keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),
        decoration:InputDecoration(labelText:label,suffixText:'unidades'),
        onSubmitted:(raw) {
          final number=double.tryParse(raw.trim().replaceAll(',','.'));
          if(number!=null && number>=min && number<=max)Navigator.pop(dialog,number);
        }),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialog),child:const Text('Cancelar')),
        FilledButton(onPressed:(){
          final number=double.tryParse(controller.text.trim().replaceAll(',','.'));
          if(number==null || number<min || number>max){
            ScaffoldMessenger.of(dialog).showSnackBar(SnackBar(content:
              Text('Informe um valor de $min a $max.')));return;
          }
          Navigator.pop(dialog,number);
        },child:const Text('Aplicar'))]));
    controller.dispose();
    return result;
  }

  Future<void> _setExactSelectionSize() async {
    final editable=doc.elements.where((e)=>selected.contains(e.id) &&
      !e.locked && !(doc.layerById(e.layerId)?.locked ?? true)).toList();
    final bounds=SelectionTransform.selectedBounds(editable,minWidth:1,minHeight:1);
    if(bounds==null)return;
    final width=await _askNumber(title:'Largura exata',label:'Largura em px do desenho',
      value:bounds.width,max:200000);
    if(width==null||!mounted)return;
    final height=await _askNumber(title:'Altura exata',label:'Altura em px do desenho',
      value:bounds.height,max:200000);
    if(height==null||!mounted)return;
    _remember();
    final next=SelectionTransform.resize(editable,bounds,
      Rect.fromLTWH(bounds.left,bounds.top,width,height));
    final lookup={for(final item in next)item.id:item};
    for(var i=0;i<doc.elements.length;i++){
      final item=lookup[doc.elements[i].id];
      if(item!=null)doc.elements[i]=item;
    }
    _changed();
  }

  Future<void> _rotateSelectionNumerically() async {
    final editable=doc.elements.where((e)=>selected.contains(e.id) &&
      !e.locked && !(doc.layerById(e.layerId)?.locked ?? true)).toList();
    final bounds=SelectionTransform.selectedBounds(editable);
    if(bounds==null)return;
    final degrees=await _askNumber(title:'Rotação precisa',label:'Ângulo em graus (+ ou −)',
      value:15,min:-360,max:360);
    if(degrees==null||!mounted)return;
    _remember();
    final rotated=SelectionTransform.rotate(editable,bounds.center,degrees*math.pi/180);
    final lookup={for(final item in rotated)item.id:item};
    for(var i=0;i<doc.elements.length;i++){
      final item=lookup[doc.elements[i].id];
      if(item!=null)doc.elements[i]=item;
    }
    _changed();
  }

  Future<void> _setTextSizeNumerically() async {
    final editable=doc.elements.where((e)=>selected.contains(e.id) &&
      e.type=='text' && !e.locked && !(doc.layerById(e.layerId)?.locked ?? true)).toList();
    if(editable.isEmpty){_message('Selecione um ou mais textos editáveis.');return;}
    final size=await _askNumber(title:'Tamanho exato do texto',
      label:'Tamanho da fonte em px',value:editable.first.size,min:4,max:500);
    if(size==null||!mounted)return;
    _remember();
    for(final item in editable){item.size=size;_fitTextBounds(item);}
    _changed();
  }

  Future<void> _pasteClipboard({bool imageOnly=false}) async {
    if(_pastingClipboard || _textDraft!=null || presenting) return;
    if(activePointer!=null || pending!=null || _radialPointer!=null) {
      _message('Conclua o gesto antes de colar.');return;
    }
    final source=doc;
    final layer=activeLayer;
    final target=doc.layerById(layer);
    if(target==null || target.locked) {
      _message('Desbloqueie a camada antes de colar.');return;
    }
    bool ready() => mounted && identical(doc,source) && activeLayer==layer &&
      doc.layerById(layer)?.locked==false && _textDraft==null && !presenting &&
      activePointer==null && pending==null && _radialPointer==null;
    _pastingClipboard=true;
    ui.Image? uncommitted;
    try {
      final bytes=await ClipboardImage.read();
      if(!ready())return;
      if(bytes!=null) {
        if(doc.layerById(layer)?.visible!=true) {
          _message('Mostre a camada antes de colar uma imagem.');return;
        }
        final image=await SketchExchange.decode(bytes);
        uncommitted=image;
        if(!ready())return;
        if(doc.layerById(layer)?.visible!=true) {
          _message('Mostre a camada antes de colar uma imagem.');return;
        }
        final center=_world(Offset(viewport.width/2,viewport.height/2));
        final limit=math.min(920.0,math.max(1.0,
          math.min(viewport.width,viewport.height)*.75/zoom));
        final item=ClipboardImage.element(bytes,layerId:layer,center:center,
          width:image.width,height:image.height,maximumSide:limit);
        _remember();
        _activateTool('select');
        doc.elements.add(item);selected.add(item.id);
        imageCache[item.id]=image;uncommitted=null;imageFrame++;
        _changed();
        _message('Imagem colada. Arraste as alças para ajustar.');
        return;
      }
      if(imageOnly) {
        _message('Copie uma imagem ou captura de tela no Windows primeiro.');return;
      }
      final data=await Clipboard.getData('text/plain');
      if(!ready())return;
      final text=data?.text ?? '';
      if(text.length>8*1024*1024) {
        throw const FormatException('Seleção maior que 8 MB.');
      }
      List<InkElement> items;
      try {
        final decoded=jsonDecode(text);
        if(decoded is! List || decoded.isEmpty || decoded.length>500) {
          throw const FormatException('Seleção vazia ou incompatível.');
        }
        items=decoded.map((e)=>InkElement.fromJson(
          Map<String,dynamic>.from(e as Map))).toList();
      } catch(_) {
        _message('Copie uma imagem do Windows ou objetos do Caderno Infinito.');return;
      }
      final groupIds=<String,String>{};
      for(final item in items) {
        if(item.group!=null) groupIds.putIfAbsent(item.group!,newId);
      }
      _remember();selected.clear();
      final newIds={for(final item in items)item.id:newId()};
      for(final e in items) {
        MindMapVectors.remapLinks(e,newIds);
        e.id=newIds[e.id]!;e.layerId=layer;e.locked=false;
        if(e.group!=null) e.group=groupIds[e.group];
        e.translate(30,30);doc.elements.add(e);selected.add(e.id);
      }
      _loadImages();_changed();
    } on FormatException catch(e) {
      _message(e.message);
    } catch(_) {
      _message('Não foi possível colar. Copie a imagem novamente e tente outra vez.');
    } finally {
      uncommitted?.dispose();
      _pastingClipboard=false;
    }
  }

  Future<void> _selectionAction(String action) async {
    if(action=='advanced') { _showTransformSheet(); return; }
    if(action=='exact-size') { await _setExactSelectionSize(); return; }
    if(action=='exact-rotate') { await _rotateSelectionNumerically(); return; }
    if(action=='text-size') { await _setTextSizeNumerically(); return; }
    if(action=='link-bookmark') {await _linkSelectionToBookmark();return;}
    if(action=='go-link') {_openSelectedLink();return;}
    if(action=='paste' || action=='paste-image') {
      await _pasteClipboard(imageOnly:action=='paste-image');
      return;
    }
    if(selected.isEmpty) {_message('Selecione um ou mais objetos primeiro.');return;}
    final allSelected=doc.elements.where((e)=>selected.contains(e.id)).toList();
    final editable=allSelected.where((e)=>
        !(doc.layerById(e.layerId)?.locked ?? true)).toList();
    final mutable=editable.where((e)=>!e.locked).toList();
    final canToggleLock=action=='lock';
    final readOnly=const ['copy','copy-text','go-link'].contains(action);
    if(!readOnly && (canToggleLock ? editable.isEmpty : mutable.isEmpty)) {
      _message('Não há objetos editáveis. Desbloqueie a camada ou os objetos.');
      return;
    }
    final elements = readOnly ? allSelected : (canToggleLock ? editable : mutable);
    if(action=='copy' || action=='cut') {
      await Clipboard.setData(ClipboardData(text:jsonEncode(elements.map((e)=>e.toJson()).toList())));
      if(action=='copy') {_message('Objetos copiados.');return;}
    }
    if(action=='copy-text' && elements.length==1 && elements.first.type=='text') {
      await Clipboard.setData(ClipboardData(text:elements.first.text));
      _message('Texto copiado para outros aplicativos.');
      return;
    }
    if(action=='edit-text') {
      if(elements.length!=1 || elements.first.type!='text') {
        _message('Selecione apenas uma caixa de texto.');
        return;
      }
      _beginText(elements.first,existing:true);
      return;
    }
    // Ações não reconhecidas não podem registrar alterações fictícias.
    const mutations={'delete','cut','duplicate','use-color','text-bigger',
      'text-smaller','group','ungroup','lock','flip-h','flip-v',
      'stretch-x','stretch-y','shear-x','shear-y','perspective',
      'grow','shrink','rotate-left','rotate-right'};
    if (!mutations.contains(action)) return;
    _remember();
    final bounds=elements.map((e)=>e.bounds).reduce((a,b)=>a.expandToInclude(b));
    switch(action) {
      case 'delete':case 'cut':
        final ids=elements.map((e)=>e.id).toSet();
        doc.elements.removeWhere((e)=>ids.contains(e.id));
        selected.removeAll(ids);break;
      case 'duplicate':
        final newGroups=<String,String>{};
        final newIds={for(final item in elements)item.id:newId()};
        selected.clear();
        for(final item in elements) {
          final copy=InkElement.fromJson(item.toJson())..id=newIds[item.id]!;
          MindMapVectors.remapLinks(copy,newIds);
          if(copy.group!=null)copy.group=newGroups.putIfAbsent(copy.group!,newId);
          copy.translate(24,24);doc.elements.add(copy);selected.add(copy.id);
        }
        _loadImages();break;
      case 'use-color':
        for(final e in elements){e.color=color;}
        break;
      case 'text-bigger':
        for(final e in elements.where((e)=>e.type=='text')){e.size+=2;_fitTextBounds(e);}
        break;
      case 'text-smaller':
        for(final e in elements.where((e)=>e.type=='text')){
          e.size=math.max(8,e.size-2);_fitTextBounds(e);}
        break;
      case 'group':
        final group=newId();for(final e in elements){e.group=group;}break;
      case 'ungroup':
        for(final e in elements){e.group=null;}break;
      case 'lock':for(final e in elements){e.locked=!e.locked;}selected.clear();break;
      case 'flip-h':for(final e in elements){e.flip(horizontal:true,center:bounds.center);}break;
      case 'flip-v':for(final e in elements){e.flip(horizontal:false,center:bounds.center);}break;
      case 'stretch-x':for(final e in elements){AdvancedTools.stretch(e,bounds.center,1.2,1);}break;
      case 'stretch-y':for(final e in elements){AdvancedTools.stretch(e,bounds.center,1,1.2);}break;
      case 'shear-x':for(final e in elements){AdvancedTools.shear(e,bounds.center,.16,0);}break;
      case 'shear-y':for(final e in elements){AdvancedTools.shear(e,bounds.center,0,.16);}break;
      case 'perspective':for(final e in elements){AdvancedTools.perspective(e,bounds.center,.35);}break;
      case 'grow':for(final e in elements){e.scaleAround(bounds.center,1.15);}break;
      case 'shrink':for(final e in elements){e.scaleAround(bounds.center,.87);}break;
      case 'rotate-left':case 'rotate-right':
        final radians=action=='rotate-left' ? -math.pi/12 : math.pi/12;
        final transformed=SelectionTransform.rotate(elements,bounds.center,radians);
        final lookup={for(final item in transformed)item.id:item};
        for(var i=0;i<doc.elements.length;i++) {
          final replacement=lookup[doc.elements[i].id];
          if(replacement!=null)doc.elements[i]=replacement;
        }
    }
    _changed();
  }
  Future<void> _renameDocument() async {
    final ctrl=TextEditingController(text:doc.title);
    final newTitle=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Nome do desenho'),content:TextField(controller:ctrl,autofocus:true),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text.trim()),child:const Text('Salvar'))]));
    ctrl.dispose();
    if(newTitle==null || newTitle.isEmpty)return;
    _remember();doc.title=newTitle;_changed();
  }
  Future<void> _editNotes() async {
    final ctrl=TextEditingController(text:doc.notes);
    final notes=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Notas deste projeto'),
      content:SizedBox(width:450,child:TextField(controller:ctrl,maxLines:7,autofocus:true,
        decoration:const InputDecoration(hintText:'Objetivos, capítulo, versão...'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text),child:const Text('Salvar'))]));
    ctrl.dispose();
    if(notes==null)return;
    _remember();doc.notes=notes;_changed();
  }
  void _message(String msg) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg),duration:const Duration(seconds:4)));
  }
  Future<void> _export(String ext) async {
    try {
      final onlySelected=ext.endsWith('-selection');
      if(onlySelected)ext=ext.replaceAll('-selection','');
      if(onlySelected&&selected.isEmpty){_message('Selecione objetos para exportar.');return;}
      final result=onlySelected ? (doc.clone()..elements.removeWhere((e)=>!selected.contains(e.id))) : doc;
      final area=onlySelected?false:showArtboard;
      if(ext=='print') {await SketchExchange.printDocument(result,imageCache);return;}
      if(ext=='native') {await SketchExchange.saveBytes('${doc.title}.ci.json',Uint8List.fromList(utf8.encode(doc.serialize())));return;}
      Uint8List bytes;
      switch(ext) {
        case 'png':bytes=await SketchExchange.exportImage(result,imageCache,artboard:area,ppi:exportPpi);break;
        case 'png-transparent':bytes=await SketchExchange.exportImage(result,imageCache,transparent:true,artboard:area,ppi:exportPpi);ext='png';break;
        case 'jpg':bytes=await SketchExchange.exportImage(result,imageCache,jpeg:true,artboard:area,ppi:exportPpi);break;
        case 'pdf':bytes=await SketchExchange.exportPdf(result,imageCache,artboard:area);break;
        case 'pdf-vector':bytes=await SketchExchange.exportVectorPdf(result,artboard:area);ext='pdf';break;
        case 'pdf-pages':bytes=await SketchExchange.exportPdf(result,imageCache,multiPage:true);
          ext='pdf';break;
        case 'svg':bytes=Uint8List.fromList(utf8.encode(SketchExchange.exportSvg(result,artboard:area)));break;
        case 'dxf':bytes=Uint8List.fromList(utf8.encode(SketchExchange.exportDxf(result)));break;
        case 'psd':bytes=await SketchExchange.exportPsd(result,imageCache,artboard:area,ppi:exportPpi);break;
        default:return;
      }
      final name='${doc.title}${onlySelected?'_selecao':''}.$ext';
      await SketchExchange.saveBytes(name,bytes);
    } catch(e) {_message('Falha na exportação: $e');}
  }
  Future<void> _chooseColor() async {
    var chosen=Color(color);
    final hex=TextEditingController(text:'#${(color & 0xffffff).toRadixString(16).padLeft(6,'0')}');
    final result=await showDialog<int>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update){
      final hsl=HSLColor.fromColor(chosen);
      return AlertDialog(title:const Text('Cor do pincel'),content:SizedBox(width:350,child:Column(
        mainAxisSize:MainAxisSize.min,children:[
        Wrap(spacing:7,runSpacing:7,children:[Colors.black,Colors.white,Colors.red,Colors.orange,
          Colors.amber,Colors.green,Colors.teal,Colors.blue,Colors.indigo,Colors.purple,
          Colors.pink,Colors.brown,Colors.grey].map((c)=>InkWell(
          onTap:()=>update((){chosen=c;hex.text='#${(c.toARGB32() & 0xffffff).toRadixString(16).padLeft(6,'0')}';}),
          child:CircleAvatar(radius:16,backgroundColor:c,
            child:c==chosen?Icon(Icons.check,color:c.computeLuminance()>.5?Colors.black:Colors.white,size:18):null))).toList()),
        const SizedBox(height:18),
        const Align(alignment:Alignment.centerLeft,child:Text('HSL — matiz, saturação e luminosidade')),
        Slider(value:hsl.hue,min:0,max:360,onChanged:(v)=>update((){
          chosen=hsl.withHue(v).toColor();hex.text='#${(chosen.toARGB32() & 0xffffff).toRadixString(16).padLeft(6,'0')}';})),
        Slider(value:hsl.saturation,min:0,max:1,onChanged:(v)=>update((){
          chosen=hsl.withSaturation(v).toColor();hex.text='#${(chosen.toARGB32() & 0xffffff).toRadixString(16).padLeft(6,'0')}';})),
        Slider(value:hsl.lightness,min:0,max:1,onChanged:(v)=>update((){
          chosen=hsl.withLightness(v).toColor();hex.text='#${(chosen.toARGB32() & 0xffffff).toRadixString(16).padLeft(6,'0')}';})),
        TextField(controller:hex,decoration:const InputDecoration(labelText:'RGB hexadecimal, ex.: #186dd8'),
          onChanged:(text) {final v=int.tryParse(text.replaceAll('#',''),radix:16);if(v!=null)update(()=>chosen=Color(0xff000000|v));}),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(c,chosen.toARGB32()),child:const Text('Aplicar'))]);
    }));
    hex.dispose();
    if(result!=null)setState(()=>color=result);
  }
  void _showLayers() {
    showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(c,refresh){
      void update(void Function() f) {
        _remember();setState(f);refresh((){});_changed();
      }
      return SafeArea(child:ConstrainedBox(constraints:const BoxConstraints(maxHeight:570),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:Row(children:[
          const Expanded(child:Text('Camadas',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
          TextButton.icon(onPressed:()=>update((){
            final layer=InkLayer(name:'Camada ${doc.layers.length+1}');
            doc.layers.add(layer);activeLayer=layer.id;
          }),icon:const Icon(Icons.add),label:const Text('Adicionar')),
        ])),
        Expanded(child:ListView.builder(itemCount:doc.layers.length,itemBuilder:(c,i){
          final layer=doc.layers[i];
          return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:3),child:Column(children:[
            ListTile(dense:true,selected:layer.id==activeLayer,
              leading:SizedBox(width:91,height:48,child:Row(mainAxisSize:MainAxisSize.min,children:[
                IconButton(tooltip:'Mostrar/ocultar',onPressed:()=>update(()=>layer.visible=!layer.visible),
                  icon:Icon(layer.visible?Icons.visibility_outlined:Icons.visibility_off_outlined,size:19),
                  constraints:const BoxConstraints(minWidth:36,minHeight:36),padding:EdgeInsets.zero),
                SizedBox(width:53,height:42,child:LayerPreview(doc:doc,layerId:layer.id,
                  images:imageCache)),
              ])),
              title:Text(layer.name,style:TextStyle(fontWeight:layer.id==activeLayer?FontWeight.w700:FontWeight.w400)),
              subtitle:Text('${doc.elements.where((e)=>e.layerId==layer.id).length} objetos'),
              onTap:()=>update(()=>activeLayer=layer.id),
              trailing:Wrap(spacing:0,children:[
                IconButton(tooltip:'Bloquear',icon:Icon(layer.locked?Icons.lock:Icons.lock_open),
                  onPressed:()=>update(()=>layer.locked=!layer.locked)),
                PopupMenuButton<String>(tooltip:'Ações da camada',onSelected:(action) async {
                  if(action=='rename') {
                    final ctrl=TextEditingController(text:layer.name);
                    final name=await showDialog<String>(context:context,builder:(d)=>AlertDialog(
                      title:const Text('Renomear camada'),content:TextField(controller:ctrl,autofocus:true),
                      actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Cancelar')),
                        FilledButton(onPressed:()=>Navigator.pop(d,ctrl.text),child:const Text('Salvar'))]));
                    ctrl.dispose();if(name!=null && name.trim().isNotEmpty)update(()=>layer.name=name);
                  } else if(action=='up' && i<doc.layers.length-1)update(() {
                    doc.layers.removeAt(i);doc.layers.insert(i+1,layer);
                  });
                  else if(action=='down' && i>0)update(() {
                    doc.layers.removeAt(i);doc.layers.insert(i-1,layer);
                  });
                  else if(action=='duplicate')update(() {
                    final clone=InkLayer(name:'${layer.name} (cópia)',
                        visible:layer.visible, locked:layer.locked,
                        opacity:layer.opacity);
                    doc.layers.add(clone);activeLayer=clone.id;
                    final groups=<String,String>{};
                    for(final element in doc.elements.where((e)=>e.layerId==layer.id).toList()) {
                      final copy=InkElement.fromJson(element.toJson())
                        ..id=newId()..layerId=clone.id;
                      if(copy.group!=null) {
                        copy.group=groups.putIfAbsent(copy.group!,newId);
                      }
                      doc.elements.add(copy);
                    }
                  });
                  else if(action=='merge' && i>0)update(() {
                    final below=doc.layers[i-1];
                    for(final e in doc.elements.where((e)=>e.layerId==layer.id)){e.layerId=below.id;}
                    doc.layers.removeAt(i);activeLayer=below.id;
                  });
                  else if(action=='delete' && doc.layers.length>1) {
                    final count=doc.elements.where((e)=>e.layerId==layer.id).length;
                    final approved=await showDialog<bool>(context:context,
                      builder:(dialog)=>AlertDialog(
                        title:const Text('Excluir camada?'),
                        content:Text('A camada "${layer.name}" e seus $count objetos serão removidos. '
                          'Você poderá usar Desfazer antes de fechar o desenho.'),
                        actions:[
                          TextButton(onPressed:()=>Navigator.pop(dialog,false),
                            child:const Text('Cancelar')),
                          FilledButton(onPressed:()=>Navigator.pop(dialog,true),
                            child:const Text('Excluir camada')),
                        ]));
                    if(approved==true && mounted && sheet.mounted) update(() {
                      doc.elements.removeWhere((e)=>e.layerId==layer.id);
                      doc.layers.remove(layer);
                      activeLayer=doc.layers.last.id;
                    });
                  }
                },itemBuilder:(_)=>const [
                  PopupMenuItem(value:'rename',child:Text('Renomear')),
                  PopupMenuItem(value:'up',child:Text('Subir')),
                  PopupMenuItem(value:'down',child:Text('Descer')),
                  PopupMenuItem(value:'duplicate',child:ListTile(leading:Icon(Icons.control_point_duplicate_outlined),title:Text('Duplicar seleção'))),
                  PopupMenuItem(value:'merge',child:Text('Mesclar com a camada abaixo')),
                  PopupMenuItem(value:'delete',child:Text('Excluir')),
                ]),
              ])),
            Padding(padding:const EdgeInsets.fromLTRB(16,0,16,7),child:Row(children:[
              const Text('Opacidade',style:TextStyle(fontSize:12)),
              Expanded(child:Slider(value:layer.opacity,min:.05,max:1,
                onChanged:(value)=>update(()=>layer.opacity=value))),
              Text('${(layer.opacity*100).round()}%'),
            ])),
          ]));
        })),
        ])));
      }));
  }
  /// Personalização do menu radial. Configurações salvas no próprio caderno.
  void _configureRadialActions() {
    final active=_radialActions.map((a)=>a.key).toList();
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
      void store() {
        doc.gestures['radialActions']=List<String>.from(active);
        setState((){});
        refresh((){});
        _changed();
      }
      final options=radialQuickActions.where((a)=>!active.contains(a.key)).toList();
      return SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,8,16,
          MediaQuery.viewInsetsOf(ctx).bottom+16),child:SizedBox(
        height:math.min(MediaQuery.sizeOf(ctx).height*.76,640.0),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Personalizar menu da caneta',
            style:TextStyle(fontSize:19,fontWeight:FontWeight.w700)),
          const SizedBox(height:4),
          Text('Escolha de 4 a 10 ações. Use as setas para organizar a posição dos ícones.',
            style:Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height:8),
          Expanded(child:ListView(children:[
            for(var i=0;i<active.length;i++)
              ListTile(dense:true,visualDensity:VisualDensity.compact,
                leading:Icon(radialQuickActions.firstWhere((a)=>a.key==active[i]).icon),
                title:Text(radialQuickActions.firstWhere((a)=>a.key==active[i]).label),
                trailing:Row(mainAxisSize:MainAxisSize.min,children:[
                  IconButton(tooltip:'Mover para antes',icon:const Icon(Icons.arrow_upward,size:19),
                    onPressed:i==0?null:(){
                      final item=active.removeAt(i);active.insert(i-1,item);store();}),
                  IconButton(tooltip:'Mover para depois',icon:const Icon(Icons.arrow_downward,size:19),
                    onPressed:i==active.length-1?null:(){
                      final item=active.removeAt(i);active.insert(i+1,item);store();}),
                  IconButton(tooltip:'Retirar do menu',icon:const Icon(Icons.remove_circle_outline,size:19),
                    onPressed:active.length<=4?null:(){active.removeAt(i);store();}),
                ])),
            if(options.isNotEmpty && active.length<10) ...[
              const Divider(),
              const Padding(padding:EdgeInsets.symmetric(vertical:5),
                child:Text('Adicionar ação',style:TextStyle(fontWeight:FontWeight.w600))),
              for(final item in options)
                ListTile(dense:true,leading:Icon(item.icon),title:Text(item.label),
                  trailing:const Icon(Icons.add_circle_outline),
                  onTap:(){if(active.length<10){active.add(item.key);store();}}),
            ],
          ])),
          Row(children:[
            TextButton.icon(onPressed:(){
              active..clear()..addAll(radialQuickActions.take(10).map((a)=>a.key));
              store();
            },icon:const Icon(Icons.restart_alt),label:const Text('Restaurar padrão')),
            const Spacer(),
            FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Concluir')),
          ]),
        ]))));
    }));
  }

  void _showPrecision() {
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,
      builder:(sheet)=>StatefulBuilder(builder:(c,refresh){
      void update(void Function() f){setState(f);refresh((){});_changed();}
      return SafeArea(child:Padding(padding:const EdgeInsets.all(20),child:SingleChildScrollView(
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Grade, precisão e página',style:TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(initialValue:doc.grid,decoration:const InputDecoration(labelText:'Tipo de papel'),
            items:const ['nenhum','pautado','quadriculado','pontilhado','isometrico','triangular',
              'perspectiva1','perspectiva2','perspectiva3'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
            onChanged:(v){if(v!=null)update(()=>doc.grid=v);}),
          const Divider(),
          const Text('Atalhos da caneta digital',style:TextStyle(fontWeight:FontWeight.bold)),
          SwitchListTile(title:const Text('Botão lateral: borracha temporária'),
            subtitle:const Text('Segure o botão da caneta para apagar; solte para voltar à ferramenta anterior.'),
            value:doc.gestures['stylusQuickEraser']!=false,
            onChanged:(v)=>update(()=>doc.gestures['stylusQuickEraser']=v)),
          SwitchListTile(title:const Text('Segundo botão: selecionar com laço'),
            subtitle:const Text('Em canetas que enviam o segundo botão. A ponta invertida usa a borracha.'),
            value:doc.gestures['stylusQuickLasso']!=false,
            onChanged:(v)=>update(()=>doc.gestures['stylusQuickLasso']=v)),
          SwitchListTile(title:const Text('Menu radial ao segurar a caneta'),
            subtitle:const Text('Segure a ponta parada por meio segundo, arraste até um ícone e solte. Soltar no centro cancela.'),
            value:doc.gestures['radialMenu']!=false,
            onChanged:(v)=>update(()=>doc.gestures['radialMenu']=v)),
          SwitchListTile(title:const Text('Vibração discreta no menu radial'),
            subtitle:const Text('Vibra ao abrir e ao destacar um ícone, quando o aparelho suporta.'),
            value:doc.gestures['radialHaptics']!=false,
            onChanged:(v)=>update(()=>doc.gestures['radialHaptics']=v)),
          ListTile(leading:const Icon(Icons.tune),
            title:const Text('Personalizar ícones do menu radial'),
            subtitle:Text('${_radialActions.length} ações em ordem personalizável'),
            trailing:const Icon(Icons.chevron_right),
            onTap:(){Navigator.pop(sheet);_configureRadialActions();}),
          SwitchListTile(title:const Text('Permitir menu radial também com o dedo'),
            subtitle:const Text('Desativado por padrão para evitar menus acidentais ao apoiar a mão.'),
            value:doc.gestures['radialMenuFinger']==true,
            onChanged:(v)=>update(()=>doc.gestures['radialMenuFinger']=v)),
          SwitchListTile(title:const Text('Botão direito abre o menu radial no PC'),
            subtitle:const Text('Alternativa para mouse ou caneta reconhecida pelo Windows como mouse.'),
            value:doc.gestures['radialMouseButton']!=false,
            onChanged:(v)=>update(()=>doc.gestures['radialMouseButton']=v)),
          SwitchListTile(title:const Text('Mostrar atalhos de escrita no quadro'),
            subtitle:const Text('Painel retrátil para caneta, borracha, desfazer, seleção e espessura.'),
            value:doc.gestures['quickInkBar']!=false,
            onChanged:(v)=>update(()=>doc.gestures['quickInkBar']=v)),
          SwitchListTile(title:const Text('Mover quadro com o dedo; escrever com a caneta'),
            subtitle:const Text('Evita rabiscos acidentais com os dedos. Dois dedos continuam controlando o zoom.'),
            value:fingerPan,
            onChanged:(v)=>update((){fingerPan=v;doc.gestures['fingerPanOnly']=v;})),
          const Divider(),
          const Text('Gestos personalizados',style:TextStyle(fontWeight:FontWeight.bold)),
          SwitchListTile(title:const Text('Dois dedos: tocar para desfazer'),
            subtitle:const Text('Só desfaz quando os dois dedos tocam e saem rapidamente sem arrastar.'),
            value:doc.gestures['twoFingerUndo']!=false,
            onChanged:(v)=>update(()=>doc.gestures['twoFingerUndo']=v)),
          SwitchListTile(title:const Text('Toque prolongado para selecionar objeto'),
            value:doc.gestures['holdSelect']==true,
            onChanged:(v)=>update(()=>doc.gestures['holdSelect']=v)),
          SwitchListTile(title:const Text('Três dedos para desfazer'),
            value:doc.gestures['threeUndo']==true,
            onChanged:(v)=>update((){
              doc.gestures['threeUndo']=v;
              if(v)doc.gestures['threeFingerRedo']=false;
            })),
          SwitchListTile(title:const Text('Três dedos: tocar para refazer'),
            value:doc.gestures['threeFingerRedo']==true,
            onChanged:(v)=>update((){
              doc.gestures['threeFingerRedo']=v;
              if(v)doc.gestures['threeUndo']=false;
            })),
          SwitchListTile(title:const Text('Quatro dedos para refazer'),
            value:doc.gestures['fourRedo']==true,
            onChanged:(v)=>update(()=>doc.gestures['fourRedo']=v)),
          SwitchListTile(title:const Text('Camadas automáticas por tipo de ferramenta'),
            subtitle:const Text('Separa textos, marcadores, imagens e traços.'),
            value:doc.layerMode=='automatico',
            onChanged:(v)=>update(()=>doc.layerMode=v?'automatico':'manual')),
          SwitchListTile(title:const Text('Encaixe magnético em objetos'),
            subtitle:const Text('Alinha bordas e centros e mostra linhas-guia.'),
            value:doc.gestures['magneticSnap']!=false,
            onChanged:(v)=>update(()=>doc.gestures['magneticSnap']=v)),
          SwitchListTile(title:const Text('Espessura sensível à pressão da caneta'),
            subtitle:const Text('Quando a caneta digital informa pressão ao Android ou Windows.'),
            value:doc.gestures['pressureInk']!=false,
            onChanged:(v)=>update(()=>doc.gestures['pressureInk']=v)),
          SwitchListTile(title:const Text('Captura fluida e econômica'),
            subtitle:const Text('Ignora micro movimentos abaixo de um pixel, '
              'reduzindo pontos e melhorando a fluidez da caneta.'),
            value:doc.gestures['smoothPerformance']!=false,
            onChanged:(v)=>update(()=>doc.gestures['smoothPerformance']=v)),
          SwitchListTile(title:const Text('Mostrar minimapa de navegação'),
            value:doc.gestures['showMiniMap']==true,
            onChanged:(v)=>update(()=>doc.gestures['showMiniMap']=v)),
          SwitchListTile(title:const Text('Encaixe na grade (Snap)'),value:doc.snap,
            onChanged:(v)=>update(()=>doc.snap=v)),
          SwitchListTile(title:const Text('Exibir artboard A4'),value:showArtboard,
            onChanged:(v)=>update(()=>showArtboard=v)),
          const Text('Espaçamento da grade'),
          Slider(value:doc.gridSpacing.clamp(12,120).toDouble(),min:12,max:120,
            onChanged:(v)=>update(()=>doc.gridSpacing=v)),
          Text('Escala de referência: 1 unidade do desenho = ${doc.scale.toStringAsFixed(2)} ${doc.unit} (medições aproximadas)'),
          DropdownButtonFormField<String>(initialValue:doc.unit,
            decoration:const InputDecoration(labelText:'Unidade de medida'),
            items:['mm','cm','m','in'].map((u)=>DropdownMenuItem(value:u,child:Text(u))).toList(),
            onChanged:(v){if(v!=null)update(()=>doc.unit=v);}),
          Slider(value:doc.scale.clamp(.1,10).toDouble(),min:.1,max:10,
            onChanged:(v)=>update(()=>doc.scale=v)),
          const Text('Tamanho do artboard (pixels de desenho)'),
          Wrap(spacing:8,children:[
            OutlinedButton(onPressed:()=>update((){doc.artboardW=794;doc.artboardH=1123;}),child:const Text('A4 retrato')),
            OutlinedButton(onPressed:()=>update((){doc.artboardW=1123;doc.artboardH=794;}),child:const Text('A4 paisagem')),
            OutlinedButton(onPressed:()=>update((){doc.artboardW=1920;doc.artboardH=1080;}),child:const Text('16:9')),
          ]),
          const SizedBox(height:8),
          Wrap(spacing:8,children:['#ffffff','#faf5eb','#111827','#fff7cc'].map((s)=>
            ActionChip(backgroundColor:colorFromHex(s),label:Text('   $s   ',style:TextStyle(
              color:colorFromHex(s).computeLuminance()<.5?Colors.white:Colors.black)),
              onPressed:()=>update(()=>doc.background=s))).toList()),
          const SizedBox(height:10),
        ]))));
      }));
  }
  void _showMeasurements() {
    if(selected.isEmpty){_message('Selecione uma forma para consultar suas medidas.');return;}
    final elements=doc.elements.where((e)=>selected.contains(e.id)).toList();
    final bounds=elements.map((e)=>e.bounds).reduce((a,b)=>a.expandToInclude(b));
    final area=bounds.width*bounds.height*doc.scale*doc.scale;
    final lengths=elements.where((e)=>e.type=='stroke')
      .map((e)=>AdvancedTools.length(e.points)*doc.scale).fold<double>(0,(a,b)=>a+b);
    final angle=elements.length==1 && elements.first.points.length>=2
      ? AdvancedTools.angleDegrees(elements.first.points.first.offset,elements.first.points.last.offset) : null;
    final inclination = angle == null ? '' : 'Inclinação: ${angle.toStringAsFixed(1)}°';
    showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Dimensões da seleção'),
      content:SelectableText('Largura: ${(bounds.width*doc.scale).toStringAsFixed(2)} ${doc.unit}\n'
        'Altura: ${(bounds.height*doc.scale).toStringAsFixed(2)} ${doc.unit}\n'
        'Área do retângulo envolvente: ${area.toStringAsFixed(2)} ${doc.unit}²\n'
        'Comprimento total dos caminhos: ${lengths.toStringAsFixed(2)} ${doc.unit}\n'
        '$inclination'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Fechar'))]));
  }

  Future<void> _showPexels() async {
    final service=PexelsService();
    final apiKey=await service.key;
    if(!mounted)return;
    if(apiKey==null || apiKey.isEmpty){
      final field=TextEditingController();
      final entered=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
        title:const Text('Chave gratuita da API Pexels'),
        content:TextField(controller:field,obscureText:true,
          decoration:const InputDecoration(labelText:'API Key',helperText:'Solicite em pexels.com/api')),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(ctx,field.text.trim()),child:const Text('Salvar'))]));
      field.dispose();if(entered==null || entered.isEmpty)return;
      await service.setKey(entered);
    }
    final searchController=TextEditingController();
    List<PexelsPhoto> photos=[];
    var loading=false;
    String? error;
    if(!mounted)return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(context,refresh){
      Future<void> runSearch() async {
        refresh(()=>loading=true);
        try {final result=await service.search(searchController.text);
          if(context.mounted)refresh((){photos=result;error=null;});
        }catch(e){if(context.mounted)refresh(()=>error='$e');}
        finally{if(context.mounted)refresh(()=>loading=false);}
      }
      return SafeArea(child:FractionallySizedBox(heightFactor:.82,child:Column(children:[
        const Padding(padding:EdgeInsets.all(12),child:Text('Fotos do Pexels',
          style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        Padding(padding:const EdgeInsets.all(12),child:Row(children:[
          Expanded(child:TextField(controller:searchController,
            onSubmitted:(_)=>runSearch(),decoration:const InputDecoration(
            prefixIcon:Icon(Icons.search),hintText:'Ex.: natureza, mapas, escola'))),
          IconButton(tooltip:'Buscar',onPressed:runSearch,icon:const Icon(Icons.search)),
        ])),
        if(loading)const LinearProgressIndicator(),
        if(error!=null)Padding(padding:const EdgeInsets.all(10),child:Text(error!)),
        Expanded(child:GridView.builder(padding:const EdgeInsets.all(10),
          gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent:180,crossAxisSpacing:8,mainAxisSpacing:8,childAspectRatio:.85),
          itemCount:photos.length,itemBuilder:(ctx,index){
          final photo=photos[index];return InkWell(
            onTap:() async {
              try {
                final bytes=await service.download(photo);
                final imported=await SketchExchange.importImage(doc,bytes,at:_world(
                  Offset(viewport.width/2,viewport.height/2)));
                _remember();doc.elements.addAll(imported);
                await _loadImages();_changed();
                if(sheet.mounted)Navigator.pop(sheet);
                _message('Foto de ${photo.photographer} adicionada. Verifique as condições do Pexels.');
              }catch(e){_message('Não foi possível inserir a foto: $e');}
            },child:Card(clipBehavior:Clip.antiAlias,child:Column(children:[
              Expanded(child:Image.network(photo.preview,fit:BoxFit.cover,errorBuilder:(_,__,___)=>
                const Icon(Icons.broken_image_outlined))),
              Padding(padding:const EdgeInsets.all(5),child:Text(photo.photographer,
                maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))),
            ])));
        })),
      ])));
    }));
    searchController.dispose();
  }

  Future<void> _saveToolPreset() async {
    _remember();
    doc.presets[tool]={'size':brush,'opacity':opacity,'smoothing':smoothing,'color':color};
    _changed();
    _message('Predefinição da ferramenta ${_toolLabel(tool)} salva neste caderno.');
  }

  Future<void> _newNamedBrush() async {
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Criar pincel personalizado'),
      content:TextField(controller:controller,autofocus:true,
        decoration:const InputDecoration(labelText:'Nome da predefinição')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Criar'))]));
    controller.dispose();if(name==null||name.isEmpty)return;
    _remember();
    doc.presets['named:${name.substring(0,name.length>50?50:name.length)}']={
      'tool':tool,'size':brush,'opacity':opacity,'smoothing':smoothing,'color':color};
    _changed();_message('Pincel "$name" adicionado à biblioteca deste caderno.');
  }

  void _showStudio() {
    showModalBottomSheet<void>(context:context,isScrollControlled:true,showDragHandle:true,
      builder:(sheet)=>StatefulBuilder(builder:(context,refresh){
      void update(void Function() fn){setState(fn);refresh((){});_changed();}
      return SafeArea(child:FractionallySizedBox(heightFactor:.78,child:ListView(
        padding:const EdgeInsets.fromLTRB(18,4,18,22),children:[
        const Text('Estúdio de pincéis e cores',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
        const SizedBox(height:10),
        ListTile(leading:const Icon(Icons.brush_outlined),
          title:const Text('Criar pincel com nome e ajustes próprios'),
          subtitle:const Text('Salva tipo, cor, tamanho, opacidade e suavização.'),
          onTap:(){Navigator.pop(sheet);_newNamedBrush();}),
        if(doc.presets.keys.any((k)=>k.startsWith('named:')))
          Wrap(spacing:6,children:[for(final item in doc.presets.entries.where((e)=>e.key.startsWith('named:')))
            ActionChip(label:Text(item.key.substring(6)),onPressed:(){
              final cfg=item.value as Map;
              final savedTool=cfg['tool'] as String? ?? 'pen';
              _activateTool(savedTool);
              setState((){brush=(cfg['size'] as num?)?.toDouble()??brush;
                opacity=(cfg['opacity'] as num?)?.toDouble()??opacity;
                final level=cfg['smoothing'];
                if(level is num && level.isFinite) smoothing=level.clamp(0,StrokeStabilizer.maxStrength).toDouble();
                color=(cfg['color'] as num?)?.toInt()??color;});
              Navigator.pop(sheet);
            })]),
        ListTile(leading:const Icon(Icons.bookmark_add_outlined),
          title:const Text('Salvar predefinição da ferramenta atual'),
          subtitle:Text('${_toolLabel(tool)} • ${brush.toStringAsFixed(1)} px • ${(opacity*100).round()}%'),
          onTap:(){_saveToolPreset();refresh((){});}),
        Text('Resolução de exportação: $exportPpi PPI'),
        Slider(value:exportPpi.toDouble(),min:72,max:600,divisions:22,
          label:'$exportPpi PPI',onChanged:(v)=>refresh(()=>exportPpi=v.round())),
        const Text('Estabilização ao soltar (0–200%)'),
        const Text('0%: original · 75%: natural · 125%: forte · 200%: máxima.'),
        Slider(value:smoothing,min:0,max:StrokeStabilizer.maxStrength,label:'${(smoothing*100).round()}%',
          onChanged:(v)=>update(()=>smoothing=v)),
        SwitchListTile(value:recognizeOnHold,onChanged:(v)=>refresh(()=>recognizeOnHold=v),
          title:const Text('Reconhecer formas ao manter a caneta parada'),
          subtitle:const Text('Após desenhar, segure por um instante para converter reta, elipse ou retângulo.')),
        SwitchListTile(value:cursorPreview,onChanged:(v)=>refresh(()=>cursorPreview=v),
          title:const Text('Prévia de posição e tamanho do pincel')),
        const Divider(),
        Row(children:[const Expanded(child:Text('Paleta pessoal',style:TextStyle(fontWeight:FontWeight.bold))),
          TextButton.icon(onPressed:()=>update(()=>doc.palette.add(color)),
            icon:const Icon(Icons.add),label:const Text('Adicionar cor atual'))]),
        Wrap(spacing:9,runSpacing:9,children:[
          for(final c in doc.palette) InkWell(onTap:()=>setState(()=>color=c),
            onLongPress:()=>update(()=>doc.palette.remove(c)),
            child:CircleAvatar(radius:21,backgroundColor:Color(c),
              child:c==color?Icon(Icons.check,color:Color(c).computeLuminance()>.5?Colors.black:Colors.white):null)),
        ]),
        const SizedBox(height:14),
        const Text('Cores inspiradas em marcadores profissionais',style:TextStyle(fontWeight:FontWeight.bold)),
        Wrap(spacing:6,runSpacing:6,children:[for(final c in AdvancedTools.copic) InkWell(
          onTap:()=>setState(()=>color=c),child:Container(width:30,height:30,decoration:BoxDecoration(
            color:Color(c),borderRadius:BorderRadius.circular(6),border:Border.all(color:Colors.black26))))]),
        const SizedBox(height:15),
        const Text('Ferramentas rápidas',style:TextStyle(fontWeight:FontWeight.bold)),
        const Text('Selecione as ferramentas que aparecerão diretamente na barra. O restante fica no menu Todas.'),
        Wrap(spacing:6,runSpacing:4,children:[for(final name in tools.keys) FilterChip(
          selected:doc.quickTools.contains(name),label:Text(_toolLabel(name)),
          onSelected:(yes)=>update(() {if(yes){
            if(!doc.quickTools.contains(name))doc.quickTools.add(name);
          }else if(doc.quickTools.length>1)doc.quickTools.remove(name);})),]),
        const SizedBox(height:14),
        FilledButton.icon(onPressed:(){Navigator.pop(sheet);_chooseColor();},
          icon:const Icon(Icons.color_lens_outlined),label:const Text('Abrir controles RGB, matiz e saturação')),
      ])));
    }));
  }

  Future<void> _saveSelectedObject() async {
    if(selected.isEmpty){_message('Selecione os objetos que deseja salvar como modelo.');return;}
    final controller=TextEditingController();
    final name=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Salvar objeto reutilizável'),
      content:TextField(controller:controller,autofocus:true,decoration:const InputDecoration(labelText:'Nome do objeto')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Salvar'))]));
    controller.dispose();
    if(name==null||name.isEmpty)return;
    _remember();
    doc.objectPacks[name]=doc.elements.where((e)=>selected.contains(e.id)).map((e)=>e.toJson()).toList();
    _changed();_message('Modelo "$name" salvo no arquivo editável.');
  }

  Future<void> _importObjectPack() async {
    try {
      final bytes=await SketchExchange.pickFile(['json','ciobj']);
      if(bytes==null)return;
      final text=utf8.decode(bytes);
      final root=jsonDecode(text) as Map<String,dynamic>;
      final name=root['name'] as String? ?? 'Modelo importado';
      final list=AdvancedTools.importPack(text);
      _remember();doc.objectPacks[name]=list;_changed();
      _message('Pacote importado: $name.');
    }catch(e){_message('Erro ao importar objeto: $e');}
  }

  Future<void> _exportObjectPack() async {
    if(doc.objectPacks.isEmpty){_message('Não há objetos personalizados para exportar.');return;}
    final key=doc.objectPacks.keys.first;
    final list=(doc.objectPacks[key] as List).map((e)=>InkElement.fromJson(Map<String,dynamic>.from(e as Map))).toList();
    final data=AdvancedTools.exportPack(key,list);
    await SketchExchange.saveBytes('$key.ciobj.json',Uint8List.fromList(utf8.encode(data)));
  }

  void _showLibrary() {
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,
      builder:(ctx)=>SafeArea(child:FractionallySizedBox(heightFactor:.74,child:ListView(
        padding:const EdgeInsets.all(18),children:[
        const Text('Biblioteca de objetos',style:TextStyle(fontWeight:FontWeight.bold,fontSize:21)),
        const Text('Toque num modelo para inseri-lo no centro da área visível. Os objetos são vetoriais e editáveis.'),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(onPressed:(){Navigator.pop(ctx);_saveSelectedObject();},
            icon:const Icon(Icons.save_outlined),label:const Text('Salvar seleção')),
          OutlinedButton.icon(onPressed:(){Navigator.pop(ctx);_importObjectPack();},
            icon:const Icon(Icons.file_open),label:const Text('Importar pacote')),
          OutlinedButton.icon(onPressed:(){Navigator.pop(ctx);_exportObjectPack();},
            icon:const Icon(Icons.ios_share),label:const Text('Exportar pacote')),
        ]),
        for(final entry in AdvancedTools.builtInPacks.entries)...[
          const Divider(),Text(entry.key,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
          Wrap(spacing:7,runSpacing:7,children:[for(final shape in entry.value) ActionChip(
            avatar:const Icon(Icons.add_box_outlined,size:18),label:Text('${shape['name']}'),
            onPressed:(){
              final at=_world(Offset(viewport.width/2,viewport.height/2));
              final w=(shape['width'] as num).toDouble(),h=(shape['height'] as num).toDouble();
              _remember();
              doc.elements.add(InkElement(layerId:activeLayer,tool:shape['tool'] as String,
                color:color,size:brush,points:[InkPoint(at.dx-w/2,at.dy-h/2),InkPoint(at.dx+w/2,at.dy+h/2)]));
              _changed();Navigator.pop(ctx);
            })]),
        ],
        if(doc.objectPacks.isNotEmpty)...[
          const Divider(),const Text('Meus objetos',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
          Wrap(spacing:7,runSpacing:7,children:[for(final name in doc.objectPacks.keys) ActionChip(
            avatar:const Icon(Icons.collections_bookmark_outlined,size:18),label:Text(name),
            onPressed:(){
              try{
                final array=(doc.objectPacks[name] as List)
                    .map((e)=>Map<String,dynamic>.from(e as Map)).toList();
                final at=_world(Offset(viewport.width/2,viewport.height/2));
                _remember();
                doc.elements.addAll(AdvancedTools.instantiateObject(activeLayer,array,at));
                _loadImages();_changed();Navigator.pop(ctx);
              }catch(e){_message('Não foi possível inserir o modelo: $e');}
            })]),
        ],
      ]))));
  }

  void _showSelectionFilters() {
    showModalBottomSheet<void>(context:context,showDragHandle:true,builder:(ctx)=>
      StatefulBuilder(builder:(ctx,refresh)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
        const Text('Filtros de seleção',style:TextStyle(fontWeight:FontWeight.bold,fontSize:20)),
        SwitchListTile(title:const Text('Permitir selecionar elementos bloqueados'),
          value:includeLockedSelection,onChanged:(v)=>refresh(()=>includeLockedSelection=v)),
        DropdownButtonFormField<String>(initialValue:selectionType,
          decoration:const InputDecoration(labelText:'Tipos de objetos'),
          items:['todos','texto','imagem','traço'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
          onChanged:(v){if(v!=null)refresh(()=>selectionType=v);}),
        DropdownButtonFormField<String>(initialValue:selectionLayer,
          decoration:const InputDecoration(labelText:'Camada'),
          items:[const DropdownMenuItem(value:'',child:Text('Todas as camadas')),
            ...doc.layers.map((e)=>DropdownMenuItem(value:e.id,child:Text(e.name)))],
          onChanged:(v){if(v!=null)refresh(()=>selectionLayer=v);}),
        const SizedBox(height:12),
        FilledButton(onPressed:(){setState(()=>selected.clear());Navigator.pop(ctx);},
          child:const Text('Aplicar filtros')),
      ])))));
  }

  Future<void> _clearOptions() async {
    final chosen=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(
      title:const Text('O que deseja limpar?'),children:[
        for(final item in {'layer':'Camada atual','stroke':'Todos os traços','text':'Textos',
          'image':'Imagens/PDF','measure':'Medições','all':'Todos os objetos'}.entries)
          SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,item.key),child:Text(item.value)),
      ]));
    if(chosen==null || !mounted)return;
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Confirmar limpeza'),
      content:const Text('Os objetos serão removidos do arquivo. É possível desfazer no editor.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Remover'))]));
    if(confirmed!=true)return;
    _remember();doc.elements.removeWhere((e)=>switch(chosen){
      'layer'=>e.layerId==activeLayer,'stroke'=>e.type=='stroke',
      'text'=>e.type=='text','image'=>e.type=='image',
      'measure'=>e.tool=='measure',_=>true});
    selected.clear();_changed();_loadImages();
  }

  void _showPdfPages() {
    final pages=doc.elements.where((e)=>e.type=='image' && e.meta['pdfPage']!=null).toList();
    if(pages.isEmpty){_message('Não há páginas importadas de PDF neste desenho.');return;}
    pages.sort((a,b)=>a.y.compareTo(b.y));
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,
      builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh){
      void move(int index,int direction) {
        final target=index+direction;
        if(target<0||target>=pages.length)return;
        _remember();
        PdfPageTools.reorder(doc,pages,index,target);
        _changed();refresh((){});
      }
      return SafeArea(child:ConstrainedBox(constraints:const BoxConstraints(maxHeight:560),
        child:Column(children:[
        const Padding(padding:EdgeInsets.all(15),child:Text('Páginas do PDF • ordem e exclusão',
          style:TextStyle(fontSize:19,fontWeight:FontWeight.bold))),
        const Padding(padding:EdgeInsets.symmetric(horizontal:18),child:Text(
          'As anotações posicionadas sobre uma página acompanham sua movimentação. Confira elementos nas bordas após reorganizar.')),
        Expanded(child:ListView.builder(itemCount:pages.length,itemBuilder:(ctx,index){
          final page=pages[index];return ListTile(
            title:Text('Página ${page.meta['pdfPage']}'),
            subtitle:Text('Posição ${index+1} • ${page.w.round()} × ${page.h.round()}'),
            leading:const Icon(Icons.picture_as_pdf_outlined),
            trailing:Wrap(spacing:0,children:[
              IconButton(tooltip:'Subir',onPressed:index==0?null:()=>move(index,-1),icon:const Icon(Icons.arrow_upward)),
              IconButton(tooltip:'Descer',onPressed:index==pages.length-1?null:()=>move(index,1),icon:const Icon(Icons.arrow_downward)),
              IconButton(tooltip:'Remover página',onPressed:(){
                _remember();doc.elements.remove(page);pages.removeAt(index);_changed();refresh((){});_loadImages();
              },icon:const Icon(Icons.delete_outline)),
            ]));
        })),
      ])));
    }));
  }

  String _toolLabel(String value) => ToolCatalog.nameOf(value);
  String _toolTooltip(String value) => '${_toolLabel(value)} (${EditorKeyboard.label(value)})';
  Widget _toolIcon(String name) {
    final active=name==tool;
    final scheme=Theme.of(context).colorScheme;
    return Semantics(button:true,selected:active,label:'Ferramenta: ${_toolLabel(name)}',
      child:IconButton(tooltip:_toolTooltip(name),
      style:IconButton.styleFrom(
        backgroundColor:active?scheme.primaryContainer:Colors.transparent,
        foregroundColor:active?scheme.primary:scheme.onSurfaceVariant,
        minimumSize:const Size(46,46),
        padding:const EdgeInsets.all(10),
      ),
      onPressed:()=>_activateTool(name),icon:Icon(tools[name],size:21)));
  }

  Future<void> _openToolPicker() async {
    // Todas as ferramentas continuam disponíveis, mas não ocupam a tela de desenho.
    final filter=TextEditingController();
    await showModalBottomSheet<void>(context:context,showDragHandle:true,
      isScrollControlled:true,constraints:const BoxConstraints(maxWidth:820),
      builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh){
        final searchTerm=filter.text.trim().toLowerCase();
        return SafeArea(child:Padding(padding:EdgeInsets.only(
          bottom:MediaQuery.viewInsetsOf(ctx).bottom),
          child:FractionallySizedBox(heightFactor:.85,child:Column(children:[
            Padding(padding:const EdgeInsets.fromLTRB(18,4,18,10),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Escolher ferramenta',style:Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight:FontWeight.w700)),
              const SizedBox(height:4),
              Text('Toque no ícone para usar. Pesquise pelo nome da função.',
                style:Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height:14),
              TextField(controller:filter,autofocus:false,
                onChanged:(_)=>refresh((){}),
                decoration:InputDecoration(
                  prefixIcon:const Icon(Icons.search_outlined),
                  hintText:'Buscar ferramenta (ex.: medir, texto, laço)',
                  suffixIcon:searchTerm.isEmpty?null:IconButton(
                    tooltip:'Limpar pesquisa',icon:const Icon(Icons.close),
                    onPressed:(){filter.clear();refresh((){});}),
                )),
            ])),
            Expanded(child:ListView(padding:const EdgeInsets.fromLTRB(18,2,18,20),children:[
              for(final section in ToolCatalog.sections.entries)
                if(section.value.any((name)=>searchTerm.isEmpty ||
                  _toolLabel(name).toLowerCase().contains(searchTerm) ||
                  section.key.toLowerCase().contains(searchTerm))) ...[
                  Padding(padding:const EdgeInsets.fromLTRB(2,17,2,10),
                    child:Text(section.key,style:Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight:FontWeight.w700))),
                  LayoutBuilder(builder:(ctx,size){
                    final count=(size.maxWidth/148).floor().clamp(2,5);
                    final tileWidth=(size.maxWidth-(count-1)*9)/count;
                    return Wrap(spacing:9,runSpacing:9,children:[
                      for(final name in section.value.where((name)=>searchTerm.isEmpty ||
                        _toolLabel(name).toLowerCase().contains(searchTerm) ||
                        section.key.toLowerCase().contains(searchTerm)))
                        SizedBox(width:tileWidth,child:_pickerTile(ctx,name,(){
                          Navigator.pop(sheet);_activateTool(name);
                        })),
                    ]);
                  }),
                ],
              if(searchTerm.isNotEmpty && !ToolCatalog.sections.entries.any((section)=>
                section.value.any((name)=>_toolLabel(name).toLowerCase().contains(searchTerm) ||
                  section.key.toLowerCase().contains(searchTerm))))
                const Padding(padding:EdgeInsets.all(24),child:Center(
                  child:Text('Nenhuma ferramenta encontrada.'))),
              const SizedBox(height:16),
              OutlinedButton.icon(onPressed:(){Navigator.pop(sheet);_showStudio();},
                icon:const Icon(Icons.tune_outlined),
                label:const Text('Personalizar a barra de ferramentas')),
            ])),
          ]))));
      }));
    filter.dispose();
  }

  Widget _pickerTile(BuildContext ctx,String name,VoidCallback onTap) {
    final cs=Theme.of(ctx).colorScheme;
    final active=tool==name;
    return Semantics(button:true,selected:active,label:_toolLabel(name),child:Material(
      color:active?cs.primaryContainer:cs.surfaceContainerLow,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),
        side:BorderSide(color:active?cs.primary:cs.outlineVariant.withValues(alpha:.5))),
      child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(15),
        child:Padding(padding:const EdgeInsets.symmetric(horizontal:8,vertical:12),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
            Icon(tools[name],size:25,color:active?cs.primary:cs.onSurfaceVariant),
            const SizedBox(height:7),
            Text(_toolLabel(name),textAlign:TextAlign.center,maxLines:2,
              overflow:TextOverflow.ellipsis,style:Theme.of(ctx).textTheme.labelMedium?.copyWith(
                fontWeight:active?FontWeight.w700:FontWeight.w500)),
            const SizedBox(height:4),
            Text(EditorKeyboard.label(name) ?? '',style:Theme.of(ctx).textTheme.labelSmall?.copyWith(color:cs.onSurfaceVariant)),
          ])))));
  }

  void _mindMapAction(String action) {
    if(tools.containsKey(action)){_activateTool(action);return;}
    if(action=='radial-template') {
      if(!_canEdit){_message('Desbloqueie a camada para inserir um mapa.');return;}
      _remember();final objects=MindMapVectors.radialTemplate(activeLayer,
        _world(Offset(viewport.width/2,viewport.height/2)),color,brush);
      doc.elements.addAll(objects);tool='select';selected..clear()..add(objects.last.id);
      _changed();_fitDrawing();return;
    }
    final items=doc.elements.where((e)=>selected.contains(e.id) && MindMapVectors.isVector(e) &&
      !e.locked && doc.layerById(e.layerId)?.locked==false).toList();
    if(action=='detach') {
      if(items.isEmpty)return;_remember();
      for(final item in items){item.meta.remove('sourceNode');item.meta.remove('targetNode');}
      _changed();return;
    }
    final parts=action.split(':');if(parts.length!=2)return;
    final key=parts[0],value=parts[1];
    _remember();
    if(key=='pattern') {
      doc.presets['mindPattern']=value;
      for(final item in items){item.meta['vectorPattern']=value;}
    } else if(key=='fill') {
      final fill=double.tryParse(value)??0.0;doc.presets['mindFill']=fill;
      for(final item in items.where(MindMapVectors.isNode)){item.meta['vectorFill']=fill;}
    } else if(key=='arrow') {
      doc.presets['mindArrow']=value;
      for(final item in items.where((e)=>MindMapVectors.lineTools.contains(e.tool))) {item.meta['vectorArrow']=value;}
    }
    _changed();
  }
  Widget _mindMapMenu()=>PopupMenuButton<String>(tooltip:'Mapas mentais e vetores',
    icon:const Icon(Icons.account_tree_outlined),onSelected:_mindMapAction,itemBuilder:(_)=>[
      const PopupMenuItem<String>(enabled:false,child:Text('MAPAS MENTAIS')),
      const PopupMenuItem(value:'radial-template',child:Text('Inserir modelo radial com 4 ramos')),
      for(final name in ToolCatalog.sections['Mapas mentais']!)
        PopupMenuItem(value:name,child:Row(children:[Icon(tools[name],size:20),const SizedBox(width:12),
          Expanded(child:Text(_toolLabel(name))),Text(EditorKeyboard.label(name)??'',style:const TextStyle(fontSize:11))])),
      const PopupMenuDivider(),const PopupMenuItem<String>(enabled:false,child:Text('CONTORNO · padrão e seleção')),
      for(final item in const [('solid','Contínuo'),('dash','Tracejado'),('dot','Pontilhado'),('dashdot','Traço-ponto')])
        PopupMenuItem(value:'pattern:${item.$1}',child:Text(item.$2)),
      const PopupMenuDivider(),const PopupMenuItem<String>(enabled:false,child:Text('PREENCHIMENTO · formas')),
      for(final item in const [('0','Sem preenchimento'),('.15','Suave (15%)'),('.35','Médio (35%)'),('1','Sólido')])
        PopupMenuItem(value:'fill:${item.$1}',child:Text(item.$2)),
      const PopupMenuDivider(),const PopupMenuItem<String>(enabled:false,child:Text('PONTAS · linhas e setas')),
      for(final item in const [('none','Sem seta'),('end','Seta no final'),('start','Seta no início'),('both','Seta dupla')])
        PopupMenuItem(value:'arrow:${item.$1}',child:Text(item.$2)),
      if(selected.isNotEmpty)const PopupMenuItem(value:'detach',child:Text('Desvincular conectores selecionados')),
    ]);
  Widget _allTools()=>IconButton(tooltip:'Buscar e escolher ferramenta (Ctrl+K)',
    onPressed:_openToolPicker,icon:const Icon(Icons.apps_outlined));

  Future<void> _showBrushOptions() async {
    final thickness=TextEditingController(text:brush.toStringAsFixed(1));
    final alpha=TextEditingController(text:(opacity*100).round().toString());
    final smooth=TextEditingController(text:(smoothing*100).round().toString());
    await showModalBottomSheet<void>(context:context,showDragHandle:true,
      isScrollControlled:true,constraints:const BoxConstraints(maxWidth:530),
      builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh){
        void apply(void Function() update){setState(update);refresh((){});}
        double? parse(String s)=>double.tryParse(s.trim().replaceAll(',','.'));
        Widget field(TextEditingController ctrl,void Function(String) submit,String hint) =>
          SizedBox(width:89,child:TextField(controller:ctrl,
            keyboardType:const TextInputType.numberWithOptions(decimal:true),
            inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            textAlign:TextAlign.right,onSubmitted:submit,
            decoration:InputDecoration(isDense:true,labelText:hint,
              contentPadding:const EdgeInsets.symmetric(horizontal:9,vertical:9),
              border:const OutlineInputBorder())));
        return SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(22,12,22,
          math.max(22,MediaQuery.viewInsetsOf(ctx).bottom+16)),
          child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,
            crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Ajustes precisos do pincel',style:Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight:FontWeight.w700)),
            const SizedBox(height:9),
            const Text('Ajuste pela barra ou digite o valor e pressione Enter/Concluído.'),
            const SizedBox(height:16),
            Row(children:[const Expanded(child:Text('Espessura')),
              field(thickness,(text){final n=parse(text);if(n!=null){
                apply(()=>brush=n.clamp(.2,500).toDouble());
                thickness.text=brush.toStringAsFixed(1);}},'px')]),
            Slider(value:brush.clamp(.2,80).toDouble(),min:.2,max:80,
              onChanged:(v)=>apply((){brush=v;thickness.text=v.toStringAsFixed(1);})),
            Row(children:[const Expanded(child:Text('Opacidade')),
              field(alpha,(text){final n=parse(text);if(n!=null){
                apply(()=>opacity=(n/100).clamp(.01,1.0).toDouble());
                alpha.text=(opacity*100).round().toString();}},'%')]),
            Slider(value:opacity.clamp(.01,1).toDouble(),min:.01,max:1,
              onChanged:(v)=>apply((){opacity=v;alpha.text=(v*100).round().toString();})),
            Row(children:[const Expanded(child:Text('Estabilização ao soltar')),
              field(smooth,(text){final n=parse(text);if(n!=null){
                apply(()=>smoothing=(n/100).clamp(0,StrokeStabilizer.maxStrength).toDouble());
                smooth.text=(smoothing*100).round().toString();}},'%')]),
            Slider(value:smoothing.clamp(0,StrokeStabilizer.maxStrength).toDouble(),min:0,max:StrokeStabilizer.maxStrength,
              onChanged:(v)=>apply((){smoothing=v;smooth.text=(v*100).round().toString();})),
            const SizedBox(height:10),
            FilledButton.tonalIcon(onPressed:(){_saveToolPreset();Navigator.pop(sheet);},
              icon:const Icon(Icons.bookmark_add_outlined),
              label:const Text('Guardar ajustes desta ferramenta')),
          ]))));
      }));
    // Se a tela for descartada enquanto os controles estão focados,
    // libera os controladores só depois que a rota for fechada.
    thickness.dispose();alpha.dispose();smooth.dispose();
  }
  void _showTransformSheet() {
    const categories=<String,Map<String,String>>{
      'Organizar': {
        'cut':'Recortar', 'group':'Agrupar', 'ungroup':'Desagrupar',
        'lock':'Bloquear / desbloquear',
      },
      'Transformar': {
        'exact-size':'Digitar largura e altura',
        'exact-rotate':'Digitar rotação em graus',
        'grow':'Ampliar 15%', 'shrink':'Reduzir 13%',
        'stretch-x':'Esticar horizontalmente', 'stretch-y':'Esticar verticalmente',
        'rotate-left':'Girar −15°', 'rotate-right':'Girar +15°',
        'flip-h':'Espelhar horizontalmente', 'flip-v':'Espelhar verticalmente',
        'shear-x':'Inclinar horizontalmente', 'shear-y':'Inclinar verticalmente',
        'perspective':'Perspectiva simplificada',
      },
      'Texto': {
        'text-size':'Digitar tamanho da fonte',
        'text-bigger':'Aumentar fonte', 'text-smaller':'Reduzir fonte',
      },
    };
    showModalBottomSheet<void>(context:context,showDragHandle:true,
      isScrollControlled:true,builder:(sheet)=>SafeArea(child:
        ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(sheet).height*.75),
          child:ListView(shrinkWrap:true,padding:const EdgeInsets.fromLTRB(22,0,22,28),
            children:[
              Text('Editar seleção',style:Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height:8),
              Text('${selected.length} objetos selecionados',style:Theme.of(sheet).textTheme.bodySmall),
              const SizedBox(height:18),
              for(final category in categories.entries) ...[
                Text(category.key,style:Theme.of(sheet).textTheme.titleSmall),
                const SizedBox(height:9),
                Wrap(spacing:8,runSpacing:8,children:[
                  for(final item in category.value.entries)
                    ActionChip(label:Text(item.value),onPressed:(){
                      Navigator.pop(sheet);
                      _selectionAction(item.key);
                    }),
                ]),
                const SizedBox(height:20),
              ],
            ]))));
  }

  Widget _selectionMenu() => PopupMenuButton<String>(tooltip:'Editar seleção',
    icon:Badge(isLabelVisible:selected.isNotEmpty,label:Text('${selected.length}'),
      child:const Icon(Icons.filter_frames_outlined)),
    onSelected:_selectionAction,
    itemBuilder:(_)=>[
      const PopupMenuItem(value:'edit-text',child:ListTile(leading:Icon(Icons.edit_outlined),title:Text('Editar texto'))),
      const PopupMenuItem(value:'copy-text',child:Text('Copiar texto simples')),
      const PopupMenuItem(value:'copy',child:ListTile(leading:Icon(Icons.copy_outlined),title:Text('Copiar objetos'))),
      const PopupMenuItem(value:'paste',child:ListTile(leading:Icon(Icons.content_paste_outlined),title:Text('Colar imagem ou objetos'))),
      if(ClipboardImage.isSupported) const PopupMenuItem(value:'paste-image',child:ListTile(leading:Icon(Icons.image_outlined),title:Text('Colar imagem do Windows'))),
      const PopupMenuItem(value:'duplicate',child:ListTile(leading:Icon(Icons.control_point_duplicate_outlined),title:Text('Duplicar seleção'))),
      const PopupMenuItem(value:'use-color',child:Text('Aplicar cor atual')),
      const PopupMenuItem(value:'advanced',child:ListTile(leading:Icon(Icons.open_with_outlined),title:Text('Redimensionar, girar e alinhar…'))),
      const PopupMenuItem(value:'link-bookmark',child:Text('Vincular a região do índice')),
      const PopupMenuItem(value:'go-link',child:Text('Abrir vínculo da seleção')),
      const PopupMenuItem(value:'delete',child:ListTile(leading:Icon(Icons.delete_outline),title:Text('Excluir objetos selecionados'))),
    ]);
  Widget _exportMenu() => PopupMenuButton<String>(tooltip:'Exportar desenho',
    icon:const Icon(Icons.ios_share_outlined),onSelected:_export,
    itemBuilder:(_)=>const [
      PopupMenuItem(value:'native',child:Text('Arquivo editável (.ci.json)')),
      PopupMenuItem(value:'png',child:Text('PNG')),
      PopupMenuItem(value:'png-selection',child:Text('PNG da seleção')),
      PopupMenuItem(value:'svg-selection',child:Text('SVG da seleção')),
      PopupMenuItem(value:'png-transparent',child:Text('PNG transparente')),
      PopupMenuItem(value:'jpg',child:Text('JPG')),
      PopupMenuItem(value:'pdf',child:Text('PDF da tela ou do artboard')),
      PopupMenuItem(value:'pdf-vector',child:Text('PDF vetorial (linhas e formas opacas)')),
      PopupMenuItem(value:'pdf-pages',child:Text('PDF com páginas importadas e anotações')),
      PopupMenuItem(value:'svg',child:Text('SVG (vetor simplificado)')),
      PopupMenuItem(value:'dxf',child:Text('DXF (linhas)')),
      PopupMenuItem(value:'psd',child:Text('PSD (imagem achatada)')),
      PopupMenuItem(value:'print',child:Text('Imprimir (A4)')),
    ]);
  Future<void> _runMoreAction(String v) async {
      switch(v) {
        case 'keyboard':_showKeyboardHelp();break;
        case 'export':_showExportOptions();break;
        case 'search':_searchText();break;
        case 'bookmarks':_openBookmarks();break;
        case 'history':_openVersionHistory();break;
        case 'save-version':_createManualVersion();break;
        case 'minimap':setState((){doc.gestures['showMiniMap']=doc.gestures['showMiniMap']!=true;});_changed();break;
        case 'measurements':_showMeasurements();break;
        case 'notes':await _editNotes();break;
        case 'studio':_showStudio();break;
        case 'library':_showLibrary();break;
        case 'pexels':_showPexels();break;
        case 'pages':_showPdfPages();break;
        case 'filter':_showSelectionFilters();break;
        case 'clearOptions':_clearOptions();break;
        case 'presentation':setState((){fullscreen=true;presenting=true;});break;
        case 'precision':_showPrecision();break;
        case 'performance':_showCanvasStatistics();break;
        case 'optimize':await _optimizeExistingStrokes();break;
        case 'rotate-left':setState(()=>rotation-=math.pi/12);break;
        case 'rotate-right':setState(()=>rotation+=math.pi/12);break;
        case 'layers':_showLayers();break;
        case 'paste':await _selectionAction('paste');break;
        case 'paste-image':await _selectionAction('paste-image');break;
        case 'clear':
          final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
            title:const Text('Limpar camada?'),
            content:const Text('Os objetos da camada atual serão removidos. Esta ação pode ser desfeita.'),
            actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),
              FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Limpar'))]));
          if(yes==true){_remember();doc.elements.removeWhere((e)=>e.layerId==activeLayer);_changed();}break;
        case 'focus':setState(()=>focus=!focus);break;
        case 'finger':_toggleFingerNavigation();break;
        case 'artboard':setState(()=>showArtboard=!showArtboard);break;
        case 'fullscreen':setState((){fullscreen=!fullscreen;if(!fullscreen)presenting=false;});break;
      }
  }

  Future<void> _showExportOptions() async {
    const formats=<String,String>{
      'native':'Arquivo editável (.ci.json)','png':'Imagem PNG',
      'png-transparent':'PNG com fundo transparente','png-selection':'PNG da seleção',
      'jpg':'Imagem JPG','svg':'Desenho vetorial SVG','svg-selection':'SVG da seleção',
      'pdf':'Documento PDF','pdf-pages':'PDF com páginas e anotações',
      'pdf-vector':'PDF vetorial','print':'Imprimir em A4',
      'dxf':'Desenho CAD (DXF)','psd':'Imagem PSD achatada',
    };
    await showModalBottomSheet<void>(context:context,showDragHandle:true,
      constraints:const BoxConstraints(maxWidth:580),builder:(sheet)=>SafeArea(
        child:ListView(shrinkWrap:true,padding:const EdgeInsets.fromLTRB(18,0,18,22),children:[
          Text('Exportar desenho',style:Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height:8),
          for(final option in formats.entries)ListTile(
            leading:Icon(option.key=='print'?Icons.print_outlined:
              option.key.startsWith('pdf')?Icons.picture_as_pdf_outlined:
              option.key.startsWith('png') || option.key=='jpg'?Icons.image_outlined:
              Icons.file_present_outlined),
            title:Text(option.value),
            onTap:(){Navigator.pop(sheet);_export(option.key);}),
        ])));
  }

  void _openActionCenter() {
    final groups= <String,List<(String,IconData,String)>>{
      'Organizar e encontrar':[
        ('search',Icons.search_outlined,'Buscar textos'),
        ('layers',Icons.layers_outlined,'Gerenciar camadas'),
        ('bookmarks',Icons.bookmarks_outlined,'Índice de regiões'),
        ('library',Icons.widgets_outlined,'Biblioteca de objetos'),
        ('pages',Icons.picture_as_pdf_outlined,'Páginas importadas do PDF'),
        ('notes',Icons.notes_outlined,'Anotações do projeto'),
      ],
      'Visualização':[
        ('minimap',Icons.map_outlined,doc.gestures['showMiniMap']==true?'Ocultar minimapa':'Mostrar minimapa'),
        ('fullscreen',Icons.fullscreen_outlined,fullscreen?'Sair da tela cheia':'Entrar em tela cheia'),
        ('presentation',Icons.slideshow_outlined,'Iniciar apresentação'),
        ('rotate-left',Icons.rotate_left_outlined,'Girar quadro 15° à esquerda'),
        ('rotate-right',Icons.rotate_right_outlined,'Girar quadro 15° à direita'),
        ('focus',Icons.center_focus_strong_outlined,focus?'Mostrar todas as camadas':'Focar na camada ativa'),
        ('artboard',Icons.crop_free_outlined,showArtboard?'Ocultar área de impressão':'Mostrar área de impressão'),
      ],
      'Desenho e precisão':[
        ('keyboard',Icons.keyboard_outlined,'Atalhos do teclado (F2)'),
        ('precision',Icons.grid_on_outlined,'Grades e encaixe magnético'),
        ('studio',Icons.brush_outlined,'Pincéis, cores e atalhos'),
        ('measurements',Icons.straighten_outlined,'Medir distâncias e ângulos'),
        ('filter',Icons.filter_alt_outlined,'Filtrar objetos selecionados'),
        ('performance',Icons.speed_outlined,'Diagnóstico do caderno'),
        ('optimize',Icons.auto_fix_high_outlined,'Otimizar traços e reduzir pontos'),
        ('finger',Icons.pan_tool_outlined,fingerPan?'Desenhar com o dedo':'Mover a tela com o dedo'),
        ('pexels',Icons.photo_library_outlined,'Buscar fotos do Pexels'),
      ],
      'Arquivos e segurança':[
        ('export',Icons.ios_share_outlined,'Exportar ou imprimir'),
        ('history',Icons.history_outlined,'Restaurar versão anterior'),
        ('save-version',Icons.bookmark_add_outlined,'Criar ponto de recuperação'),
        ('paste',Icons.content_paste_outlined,'Colar imagem ou objetos'),
        if(ClipboardImage.isSupported) ('paste-image',Icons.image_outlined,'Colar imagem do Windows'),
        ('clearOptions',Icons.cleaning_services_outlined,'Limpar objetos por categoria'),
        ('clear',Icons.delete_sweep_outlined,'Limpar camada atual'),
      ],
    };
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,constraints:const BoxConstraints(maxWidth:690),
      builder:(sheet)=>SafeArea(child:FractionallySizedBox(heightFactor:.8,
        child:ListView(padding:const EdgeInsets.fromLTRB(18,0,18,24),children:[
          Text('Ações do caderno',style:Theme.of(sheet).textTheme.titleLarge?.copyWith(
            fontWeight:FontWeight.w700)),
          const SizedBox(height:4),
          Text('Funções organizadas por finalidade, sem ocupar o quadro.',
            style:Theme.of(sheet).textTheme.bodySmall),
          for(final group in groups.entries) ...[
            const SizedBox(height:17),
            Padding(padding:const EdgeInsets.symmetric(horizontal:8),
              child:Text(group.key,style:Theme.of(sheet).textTheme.titleSmall?.copyWith(
                fontWeight:FontWeight.w700))),
            const SizedBox(height:5),
            for(final item in group.value)ListTile(
              contentPadding:const EdgeInsets.symmetric(horizontal:10),
              minLeadingWidth:28,
              leading:Icon(item.$2,size:22),
              title:Text(item.$3),
              trailing:const Icon(Icons.chevron_right_outlined,size:19),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
              onTap:(){Navigator.pop(sheet);_runMoreAction(item.$1);},
            ),
          ],
        ]))));
  }

  Widget _moreMenu()=>IconButton(
    tooltip:'Todas as ações do caderno (F1)',
    onPressed:_openActionCenter,
    icon:const Icon(Icons.more_vert_outlined));


  void _toggleFingerNavigation() {
    setState(() {
      fingerPan=!fingerPan;
      doc.gestures['fingerPanOnly']=fingerPan;
    });
    _changed();
  }

  void _quickInkAction(String name) {
    if(name=='pen') _activateTool(_lastInkTool);
    else _activateTool(name);
    if(!mounted)return;
    setState((){});
  }

  /// Painel pequeno, retrátil e utilizável com caneta sem abrir menus.
  Widget _quickInkToolbar() {
    final scheme=Theme.of(context).colorScheme;
    final limit=math.max(80.0,math.min(360.0,viewport.width-24));
    return Material(
      elevation:2,
      color:scheme.surface.withValues(alpha:.96),
      borderRadius:BorderRadius.circular(16),
      clipBehavior:Clip.antiAlias,
      child:ConstrainedBox(constraints:BoxConstraints(maxWidth:limit),
        child:SingleChildScrollView(scrollDirection:Axis.horizontal,
          child:Row(mainAxisSize:MainAxisSize.min,children:[
            IconButton(tooltip:_quickStylusExpanded
              ? 'Recolher ações rápidas da caneta' : 'Abrir ações rápidas da caneta',
              onPressed:()=>setState(()=>_quickStylusExpanded=!_quickStylusExpanded),
              icon:Icon(_quickStylusExpanded?Icons.chevron_left:Icons.draw_outlined,
                color:scheme.primary)),
            if(_quickStylusExpanded) ...[
              const SizedBox(width:2),
              IconButton(tooltip:'Voltar à última ferramenta de escrita (${_toolLabel(_lastInkTool)})',
                onPressed:()=>_quickInkAction('pen'),
                icon:Icon(Icons.edit_outlined,
                  color:tool==_lastInkTool?scheme.primary:null)),
              IconButton(tooltip:'Marcador de texto',
                onPressed:()=>_quickInkAction('marker'),
                icon:Icon(Icons.border_color_outlined,
                  color:tool=='marker'?scheme.primary:null)),
              IconButton(tooltip:'Borracha: apagar traços',
                onPressed:()=>_quickInkAction('eraser'),
                icon:Icon(Icons.auto_fix_off,
                  color:tool=='eraser'?scheme.primary:null)),
              IconButton(tooltip:'Selecionar e mover objetos',
                onPressed:()=>_quickInkAction('select'),
                icon:Icon(Icons.select_all,
                  color:tool=='select'?scheme.primary:null)),
              IconButton(tooltip:fingerPan
                  ? 'Dedo navega: tocar para permitir desenhar com o dedo'
                  : 'Ativar navegação com dedo e escrita com caneta',
                onPressed:_toggleFingerNavigation,
                icon:Icon(Icons.pan_tool_alt_outlined,
                  color:fingerPan?scheme.primary:null)),
              IconButton(tooltip:'Desfazer último traço',
                onPressed:undoStack.isEmpty?null:_undo,
                icon:const Icon(Icons.undo)),
              IconButton(tooltip:'Refazer último traço',
                onPressed:redoStack.isEmpty?null:_redo,
                icon:const Icon(Icons.redo)),
              PopupMenuButton<double>(tooltip:'Escolher espessura rápida',
                icon:const Icon(Icons.line_weight),
                onSelected:(value)=>setState(()=>brush=value),
                itemBuilder:(_)=>const [
                  PopupMenuItem(value:1.5,child:Text('Fina · 1,5 px')),
                  PopupMenuItem(value:3.5,child:Text('Normal · 3,5 px')),
                  PopupMenuItem(value:8.0,child:Text('Grossa · 8 px')),
                  PopupMenuItem(value:14.0,child:Text('Marcador · 14 px')),
                ]),
              PopupMenuButton<int>(tooltip:'Trocar cor rapidamente',
                icon:const Icon(Icons.palette_outlined),
                onSelected:(value){
                  if(value==-1) _chooseColor();
                  else setState(()=>color=value);
                },
                itemBuilder:(_)=>[
                  for(final swatch in doc.palette.toSet().take(10))
                    PopupMenuItem(value:swatch,child:Row(children:[
                      Container(width:24,height:24,decoration:BoxDecoration(
                        color:Color(swatch),shape:BoxShape.circle,
                        border:Border.all(color:Colors.grey.shade400))),
                      const SizedBox(width:10),
                      Text('#${(swatch & 0x00ffffff).toRadixString(16).padLeft(6,'0').toUpperCase()}'),
                    ])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value:-1,child:Text('Mais cores...')),
                ]),
            ],
          ]))),
    );
  }

  // Do not mutate a live pointer gesture or steal letters from a text field.
  KeyEventResult _onEditorKey(FocusNode node, KeyEvent event) {
    if(event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if(ModalRoute.of(context)?.isCurrent==false) return KeyEventResult.ignored;
    final keyboard=HardwareKeyboard.instance;
    if(_textDraft!=null) {
      final controller=_richController;
      if(controller==null)return KeyEventResult.ignored;
      final bindings=<SingleActivator,VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape,includeRepeats:false):()=>_finishText(cancel:true),
        const SingleActivator(LogicalKeyboardKey.enter,control:true,includeRepeats:false):()=>_finishText(),
        const SingleActivator(LogicalKeyboardKey.keyB,control:true,includeRepeats:false):()=>controller.toggle(RichTextFormat.bold),
        const SingleActivator(LogicalKeyboardKey.keyI,control:true,includeRepeats:false):()=>controller.toggle(RichTextFormat.italic),
        const SingleActivator(LogicalKeyboardKey.keyU,control:true,includeRepeats:false):()=>controller.toggle(RichTextFormat.underline),
        const SingleActivator(LogicalKeyboardKey.keyX,control:true,shift:true,includeRepeats:false):()=>controller.toggle(RichTextFormat.strike),
        const SingleActivator(LogicalKeyboardKey.keyH,control:true,shift:true,includeRepeats:false):()=>controller.setHighlight(controller.current.highlight==null?0xffffeb3b:null),
      };
      for(final entry in bindings.entries) {
        if(entry.key.accepts(event,keyboard)) {entry.value();return KeyEventResult.handled;}
      }
      return KeyEventResult.ignored;
    }
    final focused=FocusManager.instance.primaryFocus?.context;
    if(focused?.widget is EditableText || focused?.findAncestorWidgetOfExactType<EditableText>()!=null) {
      return KeyEventResult.ignored;
    }
    if(_radialPointer!=null && EditorKeyboard.actions['escape']!.$1.accepts(event,keyboard)) {
      setState(_cancelRadialMenu);
      return KeyEventResult.handled;
    }
    if(pointers.isNotEmpty || activePointer!=null || _radialPointer!=null || pending!=null || _pastingClipboard) {
      // A key must never cancel an in-progress stroke or transform.
      return KeyEventResult.ignored;
    }
    for(final entry in EditorKeyboard.actions.entries) {
      if(!entry.value.$1.accepts(event,keyboard))continue;
      if(presenting && !const {'fullscreen','escape','fit','reset','zoomIn','zoomInPlus','zoomInPad','zoomOut','zoomOutPad','rotate','help'}.contains(entry.key)) {
        return KeyEventResult.ignored;
      }
      _runKeyboardAction(entry.key);
      return KeyEventResult.handled;
    }
    if(!presenting) {
      for(final id in EditorKeyboard.tools.keys) {
        if(EditorKeyboard.activator(id).accepts(event,keyboard)) {
          if(tool!=id || id=='image') _activateTool(id);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _runKeyboardAction(String id) {
    switch(id) {
      case 'undo': _undo(); break;
      case 'redo': case 'redo2': _redo(); break;
      case 'save': unawaited(_save()); break;
      case 'search': _searchText(); break;
      case 'picker': _openToolPicker(); break;
      case 'copy': case 'paste': case 'cut': case 'duplicate': case 'group': case 'ungroup':
        unawaited(_selectionAction(id)); break;
      case 'delete': if(selected.isNotEmpty)unawaited(_selectionAction(id)); break;
      case 'all': setState(() {
        tool='select';selected..clear()..addAll(doc.elements.where((e)=>_selectionAllowed(e) && !e.locked && !(doc.layerById(e.layerId)?.locked??true)).map((e)=>e.id));
      }); break;
      case 'escape': setState(() {
        _cancelRadialMenu();selected.clear();
        if(presenting){presenting=false;fullscreen=false;}
      }); break;
      case 'fit': _fitDrawing(); break;
      case 'reset': setState((){zoom=1;rotation=0;pan=const Offset(70,70);}); break;
      case 'zoomIn': case 'zoomInPlus': case 'zoomInPad': case 'zoomOut': case 'zoomOutPad':
        final center=Offset(viewport.width/2,viewport.height/2);
        final world=_world(center);
        setState(() {
          zoom=(zoom*(id.startsWith('zoomIn')?1.2:1/1.2)).clamp(.12,12).toDouble();
          pan=center-_rotate(world*zoom,rotation);
        }); break;
      case 'brushUp': case 'brushDown':
        setState(()=>brush=(brush+(id=='brushUp'?1:-1)).clamp(1.0,60.0).toDouble()); break;
      case 'rotate': setState(()=>rotation+=math.pi/12); break;
      case 'layers': _showLayers(); break;
      case 'fullscreen': setState(() {fullscreen=!fullscreen;if(!fullscreen)presenting=false;}); break;
      case 'center': _openActionCenter(); break;
      case 'help': _showKeyboardHelp(); break;
      case 'lastInk': _quickInkAction('pen'); break;
      case 'eraser': _quickInkAction('eraser'); break;
      case 'select': _quickInkAction('select'); break;
    }
  }

  void _showKeyboardHelp() {
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      showDragHandle:true,constraints:const BoxConstraints(maxWidth:680),
      builder:(sheet)=>SafeArea(child:FractionallySizedBox(heightFactor:.85,
        child:ListView(padding:const EdgeInsets.fromLTRB(18,0,18,24),children:[
          Text('Atalhos do teclado',style:Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height:6),
          const Text('Pressione uma tecla no quadro. Durante a edição de texto, as letras voltam a digitar normalmente.'),
          for(final group in ToolCatalog.sections.entries) ...[
            const SizedBox(height:16),
            Text(group.key,style:Theme.of(sheet).textTheme.titleMedium),
            for(final id in group.value) ListTile(dense:true,leading:Icon(tools[id]),
              title:Text(_toolLabel(id)),trailing:_keyHint(sheet,EditorKeyboard.label(id)??'')),
          ],
          const SizedBox(height:16),
          Text('Edição e navegação',style:Theme.of(sheet).textTheme.titleMedium),
          for(final action in EditorKeyboard.actions.values) ListTile(dense:true,
            title:Text(action.$3),trailing:_keyHint(sheet,action.$2)),
          const SizedBox(height:16),
          Text('Durante a digitação',style:Theme.of(sheet).textTheme.titleMedium),
          for(final item in const [('Negrito','Ctrl+B'),('Itálico','Ctrl+I'),
            ('Sublinhado','Ctrl+U'),('Tachado','Ctrl+Shift+X'),('Destaque','Ctrl+Shift+H'),
            ('Concluir','Ctrl+Enter'),('Cancelar','Esc')]) ListTile(dense:true,
              title:Text(item.$1),trailing:_keyHint(sheet,item.$2)),
        ]))));
  }

  Widget _keyHint(BuildContext ctx,String label) => Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(6),
      border:Border.all(color:Theme.of(ctx).colorScheme.outlineVariant)),
    child:Text(label,style:Theme.of(ctx).textTheme.labelMedium));

  @override Widget build(BuildContext context) {
    final wide=ResponsiveLayout.editorHasSidebar(MediaQuery.sizeOf(context).width);
    // Foque na camada ativa sem serializar e clonar milhares de pontos a cada gesto.
    final activeDoc=doc;
    return PopScope(
      canPop:false,
      onPopInvokedWithResult:(didPop,result) {
        if(!didPop) _leave();
      },
      child:Focus(focusNode:_editorKeyboardFocus,autofocus:true,onKeyEvent:_onEditorKey,child:Scaffold(
        appBar:fullscreen?null:AppBar(
          leading:IconButton(tooltip:'Voltar e salvar',onPressed:_leave,icon:const Icon(Icons.arrow_back)),
          title:InkWell(onTap:_textDraft==null?_renameDocument:null,child:Row(mainAxisSize:MainAxisSize.min,children:[
            Flexible(child:Text(doc.title,overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontWeight:FontWeight.w700,fontSize:17))),
            if(wide)...[const SizedBox(width:12),Text(needsSave?'Salvando…':'Salvo neste aparelho',
              style:Theme.of(context).textTheme.labelSmall?.copyWith(
                color:Theme.of(context).colorScheme.onSurfaceVariant))],
          ])),
          actions: _textDraft!=null?[]:[
            IconButton(tooltip:'Desfazer (Ctrl+Z)',onPressed:undoStack.isEmpty?null:_undo,icon:const Icon(Icons.undo)),
            IconButton(tooltip:'Refazer (Ctrl+Y)',onPressed:redoStack.isEmpty?null:_redo,icon:const Icon(Icons.redo)),
            if(wide) IconButton(tooltip:'Importar PDF ou imagem',onPressed:_importFile,icon:const Icon(Icons.add_photo_alternate_outlined)),
            if(wide)IconButton(tooltip:'Camadas',onPressed:_showLayers,icon:const Icon(Icons.layers_outlined)),
            if(wide)IconButton(tooltip:'Buscar texto',onPressed:_searchText,
              icon:const Icon(Icons.search_outlined)),
            if(wide)IconButton(tooltip:'Índice de regiões',onPressed:_openBookmarks,
              icon:const Icon(Icons.bookmarks_outlined)),
            if(wide)_exportMenu(),_moreMenu(),
            if(wide) IconButton(tooltip:'Tela cheia',onPressed:()=>setState(()=>fullscreen=!fullscreen),
              icon:Icon(fullscreen?Icons.fullscreen_exit:Icons.fullscreen)),
          ]),
        body:SafeArea(top:fullscreen,bottom:fullscreen,child:Column(children:[
          if(presenting) SizedBox(height:44,child:Row(children:[
            IconButton(tooltip:'Encerrar apresentação',onPressed:()=>setState((){presenting=false;fullscreen=false;}),
              icon:const Icon(Icons.close_fullscreen)),
            const Expanded(child:Center(child:Text('Apresentação • gestos para navegar'))),
          ])),
          if(fullscreen && !presenting) SizedBox(height:44,child:IgnorePointer(ignoring:_textDraft!=null,child:Row(children:[
            IconButton(tooltip:'Sair da tela cheia',onPressed:()=>setState(()=>fullscreen=false),icon:const Icon(Icons.fullscreen_exit)),
            _allTools(),_mindMapMenu(),if(tool=='text')IconButton(tooltip:'Tamanho padrão do texto',onPressed:_chooseDefaultTextSize,icon:const Icon(Icons.format_size)),IconButton(tooltip:'Gerenciar camadas',onPressed:_showLayers,icon:const Icon(Icons.layers_outlined)),
            if(wide)_exportMenu(),_moreMenu(),const Spacer(),Text('${(zoom*100).round()}%'),
          ]))),
          Expanded(child:Row(children:[
            if(wide && !fullscreen && !presenting) IgnorePointer(ignoring:_textDraft!=null,child:Material(
              color:Theme.of(context).colorScheme.surfaceContainerLow,
              child:SizedBox(width:59,child:Column(children:[
                Expanded(child:ListView(padding:const EdgeInsets.symmetric(vertical:6),children:[
                  for(final name in doc.quickTools.where((n)=>tools.containsKey(n)).take(7)) Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
                    child:_toolIcon(name)),
                  const Divider(),_mindMapMenu(),_allTools(),
                ])),
              ])))),
            Expanded(child:LayoutBuilder(builder:(ctx,constraints){
              viewport=constraints.biggest;
              return ClipRect(child:Listener(
                behavior:HitTestBehavior.opaque,
                onPointerDown:_pointerDown,onPointerMove:_pointerMove,
                onPointerUp:_pointerUp,onPointerCancel:_pointerUp,
                onPointerSignal:(event){if(event is PointerScrollEvent)_mouseScroll(event);},
                child:MouseRegion(cursor:tool=='pan'?SystemMouseCursors.grab:SystemMouseCursors.precise,
                  onHover:(event){
                    if(!cursorPreview)return;
                    final previous=hoverPosition.value;
                    if(previous==null || (previous-event.localPosition).distance>2) {
                      hoverPosition.value=event.localPosition;
                    }
                  },
                  onExit:(_){hoverPosition.value=null;},
                  child:Stack(fit:StackFit.expand,children:[
                    CustomPaint(painter:BoardPainter(doc:activeDoc,zoom:zoom,pan:pan,rotation:rotation,
                      pending:pending,selected:const {},images:imageCache,
                      onlyLayerId:focus?activeLayer:null,revision:editRevision,hiddenElementId:_editingTextId,
                      strokeFrame:strokeFrame,imageFrame:imageFrame)),
                    if(_textDraft==null && !presenting && doc.gestures['quickInkBar']!=false)
                      Positioned(left:12,top:doc.gestures['showMiniMap']==true?146:12,
                        child:_quickInkToolbar()),
                    if(!presenting && (guideVertical!=null || guideHorizontal!=null))
                      IgnorePointer(child:CustomPaint(painter:SmartGuidesPainter(
                        pan:pan,zoom:zoom,rotation:rotation,vertical:guideVertical,
                        horizontal:guideHorizontal))),
                    if(_textDraft==null && !presenting && doc.gestures['showMiniMap']==true)
                      Positioned(top:12,right:12,width:176,height:126,
                        child:DocumentMiniMap(doc:activeDoc,onlyLayerId:focus?activeLayer:null,
                          revision:editRevision,visibleWorld:_visibleWorldBounds,
                          onJump:(point)=>_centerAt(point))),
                    if(!presenting && (tool=='select' || tool=='lasso') &&
                       doc.elements.any((e)=>selected.contains(e.id) && !e.locked &&
                         !(doc.layerById(e.layerId)?.locked ?? true)))
                      IgnorePointer(child:CustomPaint(painter:SelectionHandlesPainter(
                        bounds:SelectionTransform.selectedBounds(doc.elements.where((e)=>
                          selected.contains(e.id) && !e.locked &&
                          !(doc.layerById(e.layerId)?.locked ?? true)),
                            minWidth:math.max(10.0,16/zoom),
                            minHeight:math.max(10.0,16/zoom)) ?? Rect.zero,
                        pan:pan,zoom:zoom,rotation:rotation,
                        dark:Theme.of(context).brightness==Brightness.dark,
                        activeHandle:dragHandle))),
                    if(!presenting && _textDraft==null && _singleVector!=null)
                      IgnorePointer(child:CustomPaint(painter:VectorHandlesPainter(
                        controls:(MindMapVectors.isCurve(_singleVector!)||MindMapVectors.isConnector(_singleVector!))?_curveHandlePositions(_singleVector!):const {},
                        ports:MindMapVectors.isNode(_singleVector!)?_nodePorts(_singleVector!):const {},
                        dark:Theme.of(context).brightness==Brightness.dark))),
                    if(!presenting && _canTrashSelection() && selectionDragMoved)
                      Positioned(left:_trashTarget().left,top:_trashTarget().top,
                        width:_trashTarget().width,height:_trashTarget().height,
                        child:IgnorePointer(child:AnimatedContainer(
                          duration:const Duration(milliseconds:110),
                          decoration:BoxDecoration(
                            color:dragOverTrash?Colors.red.shade700:Colors.red.shade50,
                            border:Border.all(color:Colors.red.shade400,width:2),
                            borderRadius:BorderRadius.circular(16)),
                          child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                            Icon(Icons.delete_forever,color:dragOverTrash?Colors.white:Colors.red.shade700),
                            Text('Solte para excluir',style:TextStyle(fontSize:10,
                              fontWeight:FontWeight.bold,
                              color:dragOverTrash?Colors.white:Colors.red.shade700)),
                          ])))),
                    if(_textDraft==null && cursorPreview) Positioned.fill(child:IgnorePointer(
                      child:ValueListenableBuilder<Offset?>(
                        valueListenable:hoverPosition,
                        builder:(context,position,_) {
                          if(position==null)return const SizedBox.shrink();
                          final diameter=math.max(3.0,brush*zoom);
                          return Stack(children:[Positioned(
                            left:position.dx-diameter/2,top:position.dy-diameter/2,
                            child:Container(width:diameter,height:diameter,
                              decoration:BoxDecoration(shape:BoxShape.circle,
                                border:Border.all(color:Color(color).withValues(alpha:.65)))))]);
                        }))),
                    if(showArtboard) IgnorePointer(child:CustomPaint(painter:_ArtboardPainter(
                      pan:pan,zoom:zoom,rotation:rotation,width:doc.artboardW,height:doc.artboardH))),
                    if(_textDraft==null && !presenting) Positioned(left:12,bottom:wide?12:78,child:Material(
                      borderRadius:BorderRadius.circular(14),elevation:2,
                      color:Theme.of(context).colorScheme.surface.withValues(alpha:.96),
                      child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
                        child:Text(selected.isNotEmpty && (tool=='select' || tool=='lasso')
                          ? 'Arraste as alças · ${(zoom*100).round()}%'
                          : '${_toolLabel(tool)} · ${(zoom*100).round()}%',
                          style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))))),
                    if(_textDraft==null && !presenting) Positioned(right:12,bottom:12,child:Material(
                      color:Theme.of(context).colorScheme.surface.withValues(alpha:.96),
                      borderRadius:BorderRadius.circular(14),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        IconButton(tooltip:'Diminuir zoom (-)',onPressed:()=>setState((){zoom=(zoom/1.2).clamp(.12,12).toDouble();}),
                          icon:const Icon(Icons.remove,size:19)),
                        IconButton(tooltip:'Centralizar e zerar rotação (Ctrl+1)',onPressed:()=>setState((){
                          zoom=1;rotation=0;pan=const Offset(70,70);}),
                          icon:const Icon(Icons.center_focus_strong,size:19)),
                        IconButton(tooltip:'Enquadrar todos os objetos desenhados (Ctrl+0)',onPressed:_fitDrawing,
                          icon:const Icon(Icons.zoom_out_map,size:19)),
                        IconButton(tooltip:'Aumentar zoom (= / +)',onPressed:()=>setState((){zoom=(zoom*1.2).clamp(.12,12).toDouble();}),
                          icon:const Icon(Icons.add,size:19)),
                      ]))) ,
                    if(_radialPointer!=null && _radialCenter!=null)
                      StylusRadialMenu(center:_radialCenter!,radius:_radialRadius,
                        highlighted:_radialHover,activeTool:tool,
                        canUndo:undoStack.isNotEmpty,canRedo:redoStack.isNotEmpty,
                        actions:_radialActions,
                        previousAction:doc.gestures['radialLastAction'] as String?),
                    if(_textDraft!=null)_inlineTextOverlay(),
                  ]))),
              );
            })),
          ])),
          if(_textDraft==null && !wide && !fullscreen && !presenting) SizedBox(height:59,child:ListView(scrollDirection:Axis.horizontal,
            padding:const EdgeInsets.symmetric(horizontal:8),children:[
              for(final name in doc.quickTools.where((n)=>tools.containsKey(n)).take(6)) Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:_toolIcon(name)),
              _mindMapMenu(),_allTools(),
            ])),
          if(_textDraft==null && !fullscreen && !presenting) SafeArea(top:false,child:Container(
            height: expandedInkControls ? 59 : 48,
            padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
            decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,
              border:Border(top:BorderSide(color:Theme.of(context).dividerColor))),
            child:Row(children:[
              IconButton(tooltip:'Escolher cor',onPressed:_chooseColor,
                icon:Container(width:25,height:25,decoration:BoxDecoration(
                  shape:BoxShape.circle,color:Color(color),
                  border:Border.all(color:Theme.of(context).colorScheme.outlineVariant,width:2)))),
              const SizedBox(width:8),
              if(tool=='text') ...[
                Expanded(child:TextButton.icon(onPressed:_chooseDefaultTextSize,
                  icon:const Icon(Icons.format_size),label:Text('Fonte padrão: ${_defaultTextSize.toStringAsFixed(1)} px',overflow:TextOverflow.ellipsis))),
              ] else if(expandedInkControls) ...[
                if(wide)Text('Espessura',style:Theme.of(context).textTheme.labelMedium),
                Expanded(flex:3,child:Slider(value:brush.clamp(1,60).toDouble(),
                  min:1,max:60,onChanged:(v)=>setState(()=>brush=v))),
                SizedBox(width:37,child:Text(brush.toStringAsFixed(1),
                  textAlign:TextAlign.right,style:Theme.of(context).textTheme.labelMedium)),
              ] else ...[
                Expanded(child:InkWell(onTap:_showBrushOptions,child:Text(
                  '${_toolLabel(tool)} · ${brush.toStringAsFixed(1)} px',
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  style:Theme.of(context).textTheme.labelSmall))),
              ],
              if(tool!='text')IconButton(tooltip:expandedInkControls?'Recolher ajustes':'Mostrar espessura',
                onPressed:()=>setState(()=>expandedInkControls=!expandedInkControls),
                icon:Icon(expandedInkControls?Icons.expand_more:Icons.tune_outlined,size:21)),
              if(tool!='text' && expandedInkControls) IconButton(tooltip:'Opacidade e suavização',onPressed:_showBrushOptions,
                icon:const Icon(Icons.tune,size:21)),
              if(selected.isNotEmpty)_selectionMenu(),
              if(wide)IconButton(tooltip:'Camadas',onPressed:_showLayers,
                icon:const Icon(Icons.layers_outlined,size:21)),
            ]))),
        ])),
      )));
  }
}

class _ArtboardPainter extends CustomPainter {
  final Offset pan;
  final double zoom,width,height,rotation;
  _ArtboardPainter({required this.pan,required this.zoom,required this.width,required this.height,this.rotation=0});
  @override void paint(Canvas canvas,Size size) {
    canvas.save();canvas.translate(pan.dx,pan.dy);canvas.rotate(rotation);canvas.scale(zoom);
    final rect=Rect.fromLTWH(0,0,width,height);
    canvas.drawRect(rect,Paint()..color=Colors.blueAccent.withValues(alpha:.8)
      ..style=PaintingStyle.stroke..strokeWidth=1.5/zoom);
    canvas.restore();
  }
  @override bool shouldRepaint(covariant _ArtboardPainter old) => true;
}
