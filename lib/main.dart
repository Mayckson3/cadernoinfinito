import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/sketch.dart';
import 'theme/app_theme.dart';
import 'theme/responsive_layout.dart';
import 'screens/editor_screen.dart';
import 'services/drive_sync.dart';
import 'services/local_store.dart';
import 'services/folder_operations.dart';
import 'services/gallery_bulk_actions.dart';
import 'services/notebook_templates.dart';
import 'widgets/board_painter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store=LocalStore();
  await store.init();
  runApp(CadernoInfinito(store:store));
}

class CadernoInfinito extends StatefulWidget {
  final LocalStore store;
  const CadernoInfinito({super.key,required this.store});
  @override State<CadernoInfinito> createState()=>_CadernoInfinitoState();
}
class _CadernoInfinitoState extends State<CadernoInfinito> {
  ThemeMode theme=ThemeMode.system;
  @override void initState(){super.initState();_loadTheme();}
  Future<void> _loadTheme() async {
    final prefs=await SharedPreferences.getInstance();
    if(mounted)setState(()=>theme=ThemeMode.values[(prefs.getInt('theme')??0).clamp(0,2).toInt()]);
  }
  Future<void> changeTheme(ThemeMode value) async {
    setState(()=>theme=value);
    (await SharedPreferences.getInstance()).setInt('theme',value.index);
  }
  @override Widget build(BuildContext context) => MaterialApp(
    title:'Caderno Infinito',debugShowCheckedModeBanner:false,
    themeMode:theme,
    theme:AppTheme.light(),
    darkTheme:AppTheme.dark(),
    home:GalleryScreen(store:widget.store,theme:theme,onTheme:changeTheme),
  );
}

class GalleryScreen extends StatefulWidget {
  final LocalStore store;
  final ThemeMode theme;
  final Future<void> Function(ThemeMode) onTheme;
  const GalleryScreen({super.key,required this.store,required this.theme,required this.onTheme});
  @override State<GalleryScreen> createState()=>_GalleryState();
}
class _GalleryState extends State<GalleryScreen> with WidgetsBindingObserver {
  List<Sketch> docs=[];
  String folder='Todos',query='',sort='Recentes',syncStatus='Somente local';
  String? accountEmail;
  bool busy=false,showTrash=false,connected=false,editorOpen=false;
  bool selecting=false,bulkWorking=false;
  final Set<String> selectedIds=<String>{};
  final auth=DriveAuthorization();
  late DriveSync cloud;
  Timer? syncTimer;
  final search=TextEditingController();
  List<String> folders=['Geral','Concurso/Geografia','Concurso/Português','Estudos'];
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    cloud=DriveSync(widget.store,auth);
    _refresh();_initConnection();
    syncTimer=Timer.periodic(const Duration(minutes:3),(_){if(connected&&!busy)_sync(silent:true);});
  }
  @override void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();syncTimer?.cancel();super.dispose();
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.resumed && connected&&!busy)_sync(silent:true);
  }
  Future<void> _initConnection() async {
    try {
      if (Platform.isAndroid && await auth.needsAndroidSetup) {
        if (mounted) setState(() => syncStatus = 'Entre com Google para configurar o Drive');
        return;
      }
      await auth.init();
      final hasSession = await auth.hasSession;
      if (!mounted) return;
      // Estar logado no Google não significa ter autorizado o Drive.
      // Sem consentimento, não faz solicitações invisíveis nem informa "conectado".
      if (hasSession) await auth.token(interactive: false);
      final email = hasSession ? await auth.accountEmail : null;
      if (!mounted) return;
      setState(() {
        connected = hasSession;
        accountEmail = email;
        syncStatus = hasSession ? 'Drive conectado' : 'Somente neste aparelho';
      });
      if (hasSession) await _sync(silent: true);
    } catch (_) {
      if (mounted) setState(() {
        connected = false;
        syncStatus = 'Entre com Google para ativar a nuvem';
      });
    }
  }
  Future<void> _loadFolders() async {
    final prefs=await SharedPreferences.getInstance();
    folders=prefs.getStringList('folders')??folders;
  }
  Future<void> _refresh() async {
    await _loadFolders();
    final list=await widget.store.all();
    var foldersChanged=false;
    for (final doc in list) {
      if (!folders.contains(doc.folder)) {folders.add(doc.folder);foldersChanged=true;}
      final parts=doc.folder.split('/');
      for(int i=1;i<parts.length;i++) {
        final parent=parts.take(i).join('/');
        if(!folders.contains(parent)) {folders.add(parent);foldersChanged=true;}
      }
    }
    if(foldersChanged) {
      folders.sort();
      (await SharedPreferences.getInstance()).setStringList('folders',folders);
    }
    if(mounted)setState(() {
      docs=list;
      final validIds=GalleryBulkActions.inFolder(list,folder,trash:showTrash)
        .map((d)=>d.id).toSet();
      selectedIds.retainAll(validIds);
    });
  }
  void _notify(String msg) {
    if(!mounted)return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(msg)));
  }
  Future<bool> _prepareDesktopLogin() async {
    if (!await auth.needsDesktopSetup) return true;
    // Um único arquivo baixado do Google Cloud substitui copiar/colar três IDs.
    final chosen = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecionar JSON OAuth Desktop (uma única vez)',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (chosen == null || chosen.files.isEmpty) return false;
    final item = chosen.files.single;
    final bytes = item.bytes ??
        (item.path == null ? null : await File(item.path!).readAsBytes());
    if (bytes == null || bytes.length > 65536) {
      throw const FormatException('Selecione um JSON OAuth Desktop de até 64 KB.');
    }
    await auth.importDesktopCredentialsJson(utf8.decode(bytes));
    return true;
  }

  Future<bool> _prepareAndroidLogin() async {
    if (!Platform.isAndroid || !await auth.needsAndroidSetup) return true;
    final choice = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Configurar Google Drive uma vez'),
      content: const Text('Para conectar esta versão do aplicativo ao Google Drive, '
        'selecione o arquivo JSON OAuth do tipo Web baixado do seu projeto Google Cloud. '
        'É necessário cadastrar também um cliente Android para este aplicativo no mesmo projeto. '
        'Você não precisa digitar nenhum ID ou senha aqui.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false),
          child: const Text('Agora não')),
        FilledButton(onPressed: () => Navigator.pop(c, true),
          child: const Text('Selecionar JSON Web')),
      ],
    ));
    if (choice != true || !mounted) return false;
    final chosen = await FilePicker.platform.pickFiles(
      dialogTitle: 'Selecionar JSON OAuth Web',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (chosen == null || chosen.files.isEmpty) return false;
    final item = chosen.files.single;
    final bytes = item.bytes ??
        (item.path == null ? null : await File(item.path!).readAsBytes());
    if (bytes == null || bytes.length > 65536) {
      throw const FormatException('Selecione um JSON OAuth Web de até 64 KB.');
    }
    await auth.importAndroidCredentialsJson(utf8.decode(bytes));
    return true;
  }

  Future<void> _connect() async {
    if (busy || editorOpen) return;
    setState(() {busy = true; syncStatus = 'Preparando login Google…';});
    try {
      if (!await _prepareDesktopLogin()) return;
      if (!await _prepareAndroidLogin()) return;
      if (!mounted) return;
      setState(() => syncStatus = 'Aguardando autorização Google…');
      // O toque do usuário inicia diretamente a escolha de conta e a permissão
      // limitada ao Drive, sem campo de senha ou ID OAuth na interface.
      await auth.token(interactive: true);
      final email = await auth.accountEmail;
      if (!mounted) return;
      setState(() {
        connected = true;
        accountEmail = email;
        syncStatus = 'Conta Google conectada';
      });
    } catch (e) {
      if (mounted) {
        setState(() => syncStatus = 'Não foi possível conectar');
        _notify('Falha no login: $e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (connected && mounted) await _sync();
  }

  Future<void> _replaceDesktopCredentials() async {
    if (!Platform.isWindows || busy || editorOpen) return;
    try {
      final selection = await FilePicker.platform.pickFiles(
        dialogTitle: 'Atualizar configuração Google deste PC',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (selection == null || selection.files.isEmpty) return;
      final chosen = selection.files.single;
      final bytes = chosen.bytes ??
          (chosen.path == null ? null : await File(chosen.path!).readAsBytes());
      if (bytes == null || bytes.length > 65536) {
        throw const FormatException('O arquivo OAuth deve ter até 64 KB.');
      }
      await auth.importDesktopCredentialsJson(utf8.decode(bytes));
      if (!mounted) return;
      setState(() {
        connected = false;
        accountEmail = null;
        syncStatus = 'Configuração atualizada. Entre com Google novamente.';
      });
      _notify('Configuração Google atualizada. Seus cadernos foram preservados.');
    } catch (e) {
      _notify('Não foi possível atualizar a configuração: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await auth.logout();
      if (!mounted) return;
      setState(() {
        connected = false;
        accountEmail = null;
        syncStatus = 'Somente neste aparelho';
      });
      _notify('Conta desconectada. Seus desenhos permanecem neste aparelho.');
    } catch (e) {
      _notify('Não foi possível desconectar: $e');
    }
  }

  void _cloudPanel() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.cloud_outlined, color: cs.onPrimaryContainer)),
                const SizedBox(width: 14),
                const Expanded(child: Text('Seus cadernos na nuvem',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 14),
              Text(connected
                ? (accountEmail ?? 'Conta Google conectada')
                : 'Entre com Google para continuar no celular ou no PC.',
                style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 7),
              const Text('Uma pasta "Caderno Infinito" no seu Google Drive. '
                'Somente os arquivos do aplicativo. Funciona offline.'),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: busy ? null : () {
                  Navigator.pop(sheetContext);
                  if (connected) { _sync(); } else { _connect(); }
                },
                icon: Icon(connected ? Icons.sync : Icons.login),
                label: Text(connected ? 'Sincronizar agora' : 'Entrar com Google'),
              )),
              if (connected) ...[
                const SizedBox(height: 7),
                SizedBox(width: double.infinity, child: TextButton.icon(
                  onPressed: () { Navigator.pop(sheetContext); _disconnect(); },
                  icon: const Icon(Icons.logout),
                  label: const Text('Desconectar conta'),
                )),
              ],
              if (Platform.isWindows && !connected) ...[
                const SizedBox(height: 7),
                Text('No primeiro login deste PC, poderá ser necessário selecionar '
                  'uma vez o JSON OAuth Desktop do aplicativo.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
              if (Platform.isAndroid && !connected) ...[
                const SizedBox(height: 7),
                Text('Se o login ainda não estiver configurado neste APK, '
                  'selecione uma vez o arquivo JSON OAuth Web do seu projeto Google Cloud.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
              const SizedBox(height: 6),
              Text(syncStatus,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sync({bool silent=false}) async {
    // Não substitui documentos locais enquanto uma rota do editor os modifica.
    if(busy||bulkWorking||cloud.busy||!connected||editorOpen)return;
    setState(() {busy=true;syncStatus='Sincronizando desenhos…';});
    DriveFolderChanged? changedDrive;
    try {
      final report=await cloud.sync();
      await _refresh();
      if(!mounted)return;
      setState(()=>syncStatus='Atualizado às ${TimeOfDay.now().format(context)}');
      if(!silent)_notify(report.description);
    } on DriveFolderChanged catch(e) {
      changedDrive=e;
      if(mounted)setState(()=>syncStatus='Drive diferente: confirmação necessária');
    } catch(e) {
      if(!mounted)return;
      setState(()=>syncStatus='Falha na sincronização • arquivos locais preservados');
      if(!silent)_notify('Não foi possível sincronizar: $e');
    } finally {if(mounted)setState(()=>busy=false);}
    if (changedDrive!=null && !silent && mounted) {
      await _confirmDriveChange();
    }
  }

  Future<void> _confirmDriveChange() async {
    final approved=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Outra pasta do Google Drive'),
      content:const Text('A pasta encontrada é diferente daquela usada anteriormente. '
        'Isso pode indicar que você trocou de conta Google. Os arquivos locais NÃO serão apagados. '
        'Deseja vincular esta nova pasta e copiar seu acervo local para ela?'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Manter vínculo anterior')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Usar nova pasta'))],
    ));
    if(approved!=true)return;
    try {
      await cloud.confirmUseOfNewDrive();
      await _sync();
    } catch(e) {_notify('Não foi possível mudar a pasta: $e');}
  }

  Future<void> _exportBackup() async {
    try {
      final data=await widget.store.createBackup();
      final stamp=DateTime.now().toIso8601String().substring(0,10);
      final saved=await FilePicker.platform.saveFile(
        dialogTitle:'Salvar backup completo',
        fileName:'CadernoInfinito_$stamp.cibackup.json',
        bytes:Uint8List.fromList(utf8.encode(data)),
      );
      if(saved!=null)_notify('Backup exportado. Guarde uma cópia em local seguro.');
    } catch(e) {_notify('Falha ao preparar backup: $e');}
  }

  Future<void> _restoreBackup() async {
    try {
      final selection=await FilePicker.platform.pickFiles(
        type:FileType.custom,allowedExtensions:['json'],withData:true);
      if(selection==null||selection.files.isEmpty)return;
      final input=selection.files.single;
      final bytes=input.bytes??(input.path==null?null:await File(input.path!).readAsBytes());
      if(bytes==null)throw const FormatException('Arquivo sem dados.');
      final source=utf8.decode(bytes);
      final incoming=BackupCodec.decode(source);
      if(!mounted)return;
      final agree=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
        title:const Text('Restaurar cadernos'),
        content:Text('O arquivo contém ${incoming.length} desenhos. Os existentes serão preservados; '
          'versões diferentes serão importadas como cópias. Continuar?'),
        actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Restaurar'))]));
      if(agree!=true)return;
      final report=await widget.store.restoreBackup(source);
      await _refresh();
      _notify('${report.imported} restaurados • ${report.skipped} já existentes');
    } catch(e) {_notify('Não foi possível restaurar o backup: $e');}
  }

  // Pastas são índices locais. A exclusão preserva os arquivos editáveis.
  Future<void> _deleteFolder(String target) async {
    if (target == 'Geral' || busy || bulkWorking || cloud.busy || editorOpen) {
      _notify('Não é possível alterar esta pasta agora.');
      return;
    }
    final affected = docs.where((doc) =>
      FolderOperations.contains(doc.folder, target)).toList();
    final nestedCount = folders.where((f) =>
      FolderOperations.contains(f, target)).length - 1;
    final confirmation = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Excluir pasta?'),
      content: Text('Excluir "$target"${nestedCount > 0 ? ' e suas $nestedCount subpastas' : ''}? '
        '${affected.isEmpty ? 'A pasta não contém desenhos.' : '${affected.length} desenho(s), incluindo os da lixeira, serão movidos para Geral.'} '
        'Nenhum desenho será apagado.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true),
          child: const Text('Excluir pasta')),
      ],
    ));
    if (confirmation != true || !mounted) return;
    try {
      for (final doc in affected) {
        doc.folder = 'Geral';
        doc.touch();
        await widget.store.save(doc);
      }
      final remaining = FolderOperations.afterDelete(folders, target);
      if (!remaining.contains('Geral')) remaining.insert(0, 'Geral');
      await (await SharedPreferences.getInstance()).setStringList('folders', remaining);
      if (!mounted) return;
      setState(() {
        folders = remaining;
        if (FolderOperations.contains(folder, target)) {
          folder = 'Todos';
          showTrash = false;
        }
      });
      await _refresh();
      _notify('Pasta excluída. Seus desenhos foram preservados.');
      if (connected && !busy) await _sync(silent: true);
    } catch (e) {
      await _refresh();
      _notify('Não foi possível excluir a pasta: $e');
    }
  }

  Future<void> _renameFolder(String target) async {
    if (target == 'Geral' || busy || cloud.busy || editorOpen) return;
    final controller = TextEditingController(text: target);
    final chosen = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Renomear pasta'),
      content: TextField(controller: controller, autofocus: true,
        decoration: const InputDecoration(labelText: 'Novo nome ou caminho')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()),
          child: const Text('Salvar')),
      ],
    ));
    controller.dispose();
    if (chosen == null || !mounted) return;
    final next = FolderOperations.normalize(chosen);
    if (!FolderOperations.canRename(folders, target, next)) {
      _notify('Nome inválido, igual ao atual ou já usado por outra pasta.');
      return;
    }
    try {
      final affected = docs.where((doc) =>
        FolderOperations.contains(doc.folder, target)).toList();
      for (final doc in affected) {
        doc.folder = FolderOperations.afterRename(doc.folder, target, next);
        doc.touch();
        await widget.store.save(doc);
      }
      final updated = FolderOperations.renamed(folders, target, next);
      await (await SharedPreferences.getInstance()).setStringList('folders', updated);
      if (!mounted) return;
      setState(() {
        folders = updated;
        folder = FolderOperations.afterRename(folder, target, next);
      });
      await _refresh();
      _notify('Pasta renomeada. Desenhos preservados.');
      if (connected && !busy) await _sync(silent: true);
    } catch (e) {
      await _refresh();
      _notify('Não foi possível renomear a pasta: $e');
    }
  }

  Future<void> _newFolder() async {
    final controller=TextEditingController();
    final result=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
      title:const Text('Nova pasta'),
      content:TextField(controller:controller,autofocus:true,
        decoration:const InputDecoration(hintText:'Ex.: Concurso/Geografia/Cartografia')),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(c,controller.text.trim()),child:const Text('Criar'))]));
    controller.dispose();
    if(result==null||result.isEmpty)return;
    final name=FolderOperations.normalize(result);
    if (!FolderOperations.isValid(name)) {
      _notify('Nome de pasta inválido.');
      return;
    }
    if (folders.contains(name)) {
      setState(() => folder = name);
      return;
    }
    folders.add(name);
    folders.sort();
    await (await SharedPreferences.getInstance()).setStringList('folders',folders);
    if (mounted) setState(()=>folder=name);
  }
  Future<void> _newDoc() async {
    final controller=TextEditingController();
    var chosenFolder=folder=='Todos'||folder=='Lixeira'?'Geral':folder;
    var grid='pautado';
    var chosenTemplate=NotebookTemplates.names.first;
    final created=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>
      AlertDialog(title:const Text('Novo desenho'),content:SizedBox(width:400,
        child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:controller,autofocus:true,
            decoration:const InputDecoration(labelText:'Título',hintText:'Ex.: Resumo de Cartografia')),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(initialValue:chosenFolder,
            decoration:const InputDecoration(labelText:'Pasta'),
            items:[...folders,if(!folders.contains(chosenFolder))chosenFolder].map((f)=>
              DropdownMenuItem(value:f,child:Text(f,overflow:TextOverflow.ellipsis))).toList(),
            onChanged:(v){if(v!=null)update(()=>chosenFolder=v);}),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(initialValue:chosenTemplate,
            isExpanded:true,
            decoration:const InputDecoration(labelText:'Modelo do caderno'),
            items:NotebookTemplates.names.map((name)=>DropdownMenuItem(
              value:name,child:Text(name,overflow:TextOverflow.ellipsis))).toList(),
            onChanged:(v){if(v!=null)update(()=>chosenTemplate=v);}),
          const SizedBox(height:8),
          Text(NotebookTemplates.descriptions[chosenTemplate] ?? '',
            style:Theme.of(c).textTheme.bodySmall),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(initialValue:grid,
            decoration:const InputDecoration(labelText:'Papel'),
            items:const ['pautado','quadriculado','pontilhado','isometrico','nenhum'].map((g)=>
              DropdownMenuItem(value:g,child:Text(g))).toList(),
            onChanged:(v){if(v!=null)update(()=>grid=v);}),
        ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),
          FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Criar'))])));
    final name=controller.text.trim();controller.dispose();
    if(created!=true)return;
    final doc=NotebookTemplates.create(
      title:name.isEmpty?'Novo desenho':name,
      folder:chosenFolder,grid:grid,template:chosenTemplate);
    await widget.store.save(doc);await _open(doc);
  }
  Future<void> _open(Sketch doc) async {
    if(busy || bulkWorking || cloud.busy) {
      _notify('Sincronização em andamento. Abra o desenho quando ela terminar.');
      return;
    }
    editorOpen=true;
    try {
      await Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>EditorScreen(
        initial:doc,store:widget.store)));
      await _refresh();
    } finally {
      editorOpen=false;
    }
    // A sincronização retoma apenas depois que o editor salvou e saiu.
    if(connected && !busy && mounted)await _sync(silent:true);
  }
  Future<void> _action(Sketch doc,String action) async {
    if ((busy || bulkWorking || cloud.busy) && action!='open') {
      _notify('Aguarde o término da sincronização para alterar o documento.');
      return;
    }
    switch(action){
      case 'open':await _open(doc);break;
      case 'duplicate':
        final copy=doc.clone()..id=newId()..title='${doc.title} (cópia)'..touch();
        await widget.store.save(copy);await _refresh();break;
      case 'deleteForever':
        await _deleteForever([doc]);
        return;
      case 'delete':case 'restore':
        doc.deleted=action=='delete';doc.touch();
        await widget.store.save(doc);await _refresh();break;
      case 'rename':
        final ctrl=TextEditingController(text:doc.title);
        final result=await showDialog<String>(context:context,builder:(c)=>AlertDialog(
          title:const Text('Renomear'),content:TextField(controller:ctrl,autofocus:true),
          actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancelar')),
            FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text.trim()),child:const Text('Salvar'))]));
        ctrl.dispose();
        if(result!=null&&result.isNotEmpty){doc.title=result;doc.touch();await widget.store.save(doc);await _refresh();}break;
      case 'move':
        final result=await showDialog<String>(context:context,builder:(c)=>SimpleDialog(title:const Text('Mover para pasta'),
          children:folders.map((f)=>SimpleDialogOption(onPressed:()=>Navigator.pop(c,f),child:Text(f))).toList()));
        if(result!=null){doc.folder=result;doc.touch();await widget.store.save(doc);await _refresh();}break;
    }
    if(action!='open' && connected && !busy)await _sync(silent:true);
  }
  Future<void> _deleteForever(List<Sketch> targets) async {
    if (targets.isEmpty || busy || bulkWorking || cloud.busy || editorOpen) return;
    final count = targets.length;
    final entireTrash=count==docs.where((d)=>d.deleted).length;
    final approved = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(count == 1 ? 'Excluir definitivamente?' :
        entireTrash ? 'Esvaziar lixeira?' : 'Excluir $count desenhos definitivamente?'),
      content: Text(count == 1
        ? 'O desenho "${targets.first.title}" será apagado deste aparelho e, '
          'quando a sincronização ocorrer, também da pasta do Caderno Infinito '
          'no Google Drive e dos demais aparelhos. Isso não pode ser desfeito.'
        : '$count desenhos serão apagados deste aparelho e, quando a '
          'sincronização ocorrer, também da pasta do Caderno Infinito no '
          'Google Drive e dos demais aparelhos. Isso não pode ser desfeito.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true),
          child: Text(count == 1 ? 'Apagar definitivamente' :
            entireTrash ? 'Esvaziar lixeira' : 'Excluir selecionados')),
      ],
    ));
    if (approved != true || !mounted) return;
    if (busy || bulkWorking || cloud.busy || editorOpen) {
      _notify('Aguarde a sincronização terminar e tente novamente.');
      return;
    }
    var erased=0;
    setState(()=>bulkWorking=true);
    try {
      // Apaga somente documentos que continuam na lixeira.
      for (final item in targets) {
        final fresh = await widget.store.get(item.id);
        if (fresh != null && fresh.deleted) {
          await widget.store.permanentlyDelete(fresh.id);
          erased++;
        }
      }
      await _refresh();
      if(mounted)_stopSelection();
      _notify('$erased ${erased==1?'desenho apagado':'desenhos apagados'} definitivamente. '
        '${connected ? 'Sincronizando com o Drive…' : 'Será sincronizado ao conectar o Drive.'}');
    } catch (e) {
      await _refresh();
      _notify('Falha ao excluir: $e');
    } finally {
      if(mounted)setState(()=>bulkWorking=false);
    }
    if (erased>0 && connected && mounted) await _sync(silent: false);
  }

  // Seleção múltipla: toque prolongado no cartão ou botão Selecionar.
  void _switchFolder(String value) {
    setState(() {
      folder=value;
      showTrash=value=='Lixeira';
      selecting=false;
      selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    if (busy || bulkWorking || cloud.busy || editorOpen) return;
    setState(() {
      selecting=true;
      if (!selectedIds.add(id)) selectedIds.remove(id);
    });
  }

  void _stopSelection() => setState(() {
    selecting=false;
    selectedIds.clear();
  });

  void _selectAllVisible(List<Sketch> visible) {
    final ids=visible.map((d)=>d.id).toSet();
    setState(() {
      if (ids.isNotEmpty && selectedIds.containsAll(ids)) {
        selectedIds.removeAll(ids);
      } else {
        selectedIds.addAll(ids);
      }
    });
  }

  Future<void> _moveManyToTrash(List<Sketch> targets, {bool entireFolder=false}) async {
    if (targets.isEmpty || busy || bulkWorking || cloud.busy || editorOpen) return;
    final currentFolder=folder;
    final count=targets.length;
    final label=currentFolder=='Todos'?'toda a biblioteca':
      'a pasta "${currentFolder.split('/').last}"';
    final approved=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
      title:Text(entireFolder?'Mover todos para a Lixeira?':
        'Mover $count ${count==1?'desenho':'desenhos'} para a Lixeira?'),
      content:Text(entireFolder
        ? 'Você vai mover $count ${count==1?'desenho':'desenhos'} de $label para a Lixeira. '
          '${currentFolder=='Todos'?'Isso inclui todas as pastas.':'Subpastas não serão alteradas.'} '
          'Os desenhos poderão ser recuperados na Lixeira.'
        : 'Os $count desenhos selecionados serão movidos para a Lixeira e poderão ser recuperados.'),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancelar')),
        FilledButton.icon(onPressed:()=>Navigator.pop(c,true),
          icon:const Icon(Icons.delete_outline),
          label:const Text('Mover para a Lixeira')),
      ],
    ));
    if(approved!=true || !mounted)return;
    if(busy || bulkWorking || cloud.busy || editorOpen) {
      _notify('Aguarde a sincronização terminar e tente novamente.');
      return;
    }
    var moved=0;
    setState(()=>bulkWorking=true);
    try {
      for(final doc in targets) {
        final fresh=await widget.store.get(doc.id);
        if(fresh==null || fresh.deleted ||
           (currentFolder!='Todos' && fresh.folder!=currentFolder))continue;
        fresh.deleted=true;
        fresh.touch();
        await widget.store.save(fresh);
        moved++;
      }
      await _refresh();
      if(mounted) _stopSelection();
      _notify('$moved ${moved==1?'desenho movido':'desenhos movidos'} para a Lixeira.');
    } catch(e) {
      await _refresh();
      _notify('Não foi possível mover todos os desenhos: $e');
    } finally {
      if(mounted)setState(()=>bulkWorking=false);
    }
    if(moved>0 && connected && mounted) await _sync(silent:true);
  }

  Future<void> _restoreMany(List<Sketch> targets) async {
    if(targets.isEmpty || busy || bulkWorking || cloud.busy || editorOpen)return;
    var restored=0;
    setState(()=>bulkWorking=true);
    try {
      for(final doc in targets) {
        final fresh=await widget.store.get(doc.id);
        if(fresh==null || !fresh.deleted)continue;
        fresh.deleted=false;
        fresh.touch();
        await widget.store.save(fresh);
        restored++;
      }
      await _refresh();
      if(mounted)_stopSelection();
      _notify('$restored ${restored==1?'desenho restaurado':'desenhos restaurados'}.');
    } catch(e) {
      await _refresh();
      _notify('Não foi possível restaurar todos os desenhos: $e');
    } finally {
      if(mounted)setState(()=>bulkWorking=false);
    }
    if(restored>0 && connected && mounted)await _sync(silent:true);
  }

  Future<void> _importNative() async {
    try {
      final result=await FilePicker.platform.pickFiles(type:FileType.custom,
        allowedExtensions:['json','ci'],withData:true);
      if(result==null)return;
      final file=result.files.single;
      final bytes=file.bytes??(file.path==null?null:await File(file.path!).readAsBytes());
      if(bytes==null)return;
      final doc=Sketch.fromJson(jsonDecode(utf8.decode(bytes)) as Map<String,dynamic>);
      if(await widget.store.get(doc.id)!=null || widget.store.isPermanentlyDeleted(doc.id)){doc.id=newId();doc.title='${doc.title} (importado)';}
      doc.deleted=false;doc.touch();
      await widget.store.save(doc);await _refresh();
      await _open(doc);
    } catch(e){_notify('Falha na importação do desenho: $e');}
  }
  List<Sketch> get visibleDocs {
    final data=docs.where((d)=>d.deleted==showTrash &&
      (folder=='Todos'||folder=='Lixeira'||d.folder==folder) &&
      (query.isEmpty||'${d.title} ${d.notes} ${d.folder} ${d.elements.where((e)=>e.type=='text').map((e)=>e.text).join(' ')}'.toLowerCase().contains(query.toLowerCase()))).toList();
    switch(sort){
      case 'Título':data.sort((a,b)=>a.title.toLowerCase().compareTo(b.title.toLowerCase()));break;
      case 'Antigos':data.sort((a,b)=>a.updatedAt.compareTo(b.updatedAt));break;
      default:data.sort((a,b)=>b.updatedAt.compareTo(a.updatedAt));
    }
    return data;
  }
  Widget _sidebar(bool wide) {
    final cs=Theme.of(context).colorScheme;
    final items=['Todos',...folders,'Lixeira'];
    return ListView(padding:const EdgeInsets.fromLTRB(12,18,12,18),children:[
      Padding(padding:const EdgeInsets.fromLTRB(12,0,4,8),child:Row(children:[
        Expanded(child:Text('CADERNOS',style:Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing:1.3,fontWeight:FontWeight.w700,color:cs.onSurfaceVariant))),
        IconButton(tooltip:'Criar pasta',onPressed:_newFolder,
          icon:const Icon(Icons.create_new_folder_outlined,size:19)),
      ])),
      for(final item in items) Padding(padding:const EdgeInsets.only(bottom:4),child:ListTile(
        dense:true,visualDensity:VisualDensity.compact,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(11)),
        selected:folder==item,
        selectedTileColor:cs.primaryContainer.withValues(alpha:.55),
        leading:Icon(item=='Todos'?Icons.grid_view_outlined:
          item=='Lixeira'?Icons.delete_outline:Icons.folder_outlined,
          color:folder==item?cs.primary:cs.onSurfaceVariant,size:20),
        title:Text(item=='Todos'?'Todos os desenhos':item=='Lixeira'?'Lixeira':
          (item.contains('/')?'  ${item.split('/').last}':item),
          maxLines:1,overflow:TextOverflow.ellipsis,
          style:TextStyle(fontWeight:folder==item?FontWeight.w700:FontWeight.w500)),
        trailing: item != 'Todos' && item != 'Lixeira' && item != 'Geral'
          ? PopupMenuButton<String>(
              tooltip: 'Opções da pasta',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz, size: 18),
              onSelected: (choice) {
                if (choice == 'rename') {
                  _renameFolder(item);
                } else if (choice == 'delete') {
                  _deleteFolder(item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Row(children:[Icon(Icons.edit_outlined),SizedBox(width:10),Text('Renomear pasta')])),
                PopupMenuItem(value: 'delete', child: Row(children:[Icon(Icons.delete_outline),SizedBox(width:10),Text('Excluir pasta')])),
              ],
            )
          : null,
        onTap:(){_switchFolder(item);
          if(!wide)Navigator.pop(context);},
      )),
      const SizedBox(height:22),
      Padding(padding:const EdgeInsets.fromLTRB(12,0,8,12),child:Text('SINCRONIZAÇÃO',
        style:Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing:1.3,fontWeight:FontWeight.w700,color:cs.onSurfaceVariant))),
      ListTile(
        dense:true,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        leading:Icon(connected?Icons.cloud_done_outlined:Icons.cloud_off_outlined,
          color:connected?cs.primary:cs.onSurfaceVariant),
        title:Text(connected?(accountEmail??'Google Drive'):'Entrar com Google'),
        subtitle:Text(connected?'Sincronização ativa':'Sincronize PC e celular',
          style:Theme.of(context).textTheme.labelSmall),
        onTap:_cloudPanel,
      ),
      const SizedBox(height:16),
      OutlinedButton.icon(onPressed:_settings,
        icon:const Icon(Icons.settings_outlined,size:17),label:const Text('Preferências')),
    ]);
  }
  Widget _bulkToolbar(List<Sketch> visible) {
    final current=GalleryBulkActions.selected(docs,folder,selectedIds,trash:showTrash);
    final inFolder=GalleryBulkActions.inFolder(docs,folder,trash:showTrash);
    final allVisibleSelected=visible.isNotEmpty &&
      selectedIds.containsAll(visible.map((d)=>d.id));
    final available=!(busy || cloud.busy || bulkWorking || editorOpen);
    return Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
      if(!selecting)
        OutlinedButton.icon(onPressed:available?()=>setState(()=>selecting=true):null,
          icon:const Icon(Icons.check_box_outlined,size:18),
          label:const Text('Selecionar vários')),
      if(selecting) ...[
        Text('${current.length} selecionado(s)',
          style:Theme.of(context).textTheme.labelMedium),
        OutlinedButton.icon(onPressed:available?()=>_selectAllVisible(visible):null,
          icon:Icon(allVisibleSelected?Icons.close:Icons.select_all,size:18),
          label:Text(allVisibleSelected?'Desmarcar todos':'Selecionar todos')),
        if(!showTrash)
          FilledButton.icon(onPressed:available && current.isNotEmpty?
            ()=>_moveManyToTrash(current):null,
            icon:const Icon(Icons.delete_outline,size:18),
            label:const Text('Mover selecionados para a Lixeira')),
        if(showTrash) ...[
          FilledButton.icon(onPressed:available && current.isNotEmpty?
            ()=>_restoreMany(current):null,
            icon:const Icon(Icons.restore_outlined,size:18),
            label:const Text('Restaurar selecionados')),
          OutlinedButton.icon(onPressed:available && current.isNotEmpty?
            ()=>_deleteForever(current):null,
            icon:const Icon(Icons.delete_forever_outlined,size:18),
            label:const Text('Excluir selecionados definitivamente')),
        ],
        TextButton.icon(onPressed:_stopSelection,
          icon:const Icon(Icons.close,size:18),label:const Text('Cancelar seleção')),
      ] else if(!showTrash && inFolder.isNotEmpty)
        TextButton.icon(onPressed:available?
          ()=>_moveManyToTrash(inFolder,entireFolder:true):null,
          icon:const Icon(Icons.delete_sweep_outlined,size:18),
          label:Text(folder=='Todos'?'Mover todos para a Lixeira':
            'Mover todos desta pasta para a Lixeira')),
    ]);
  }

  Widget _miniature(Sketch doc) {
    final cs=Theme.of(context).colorScheme;
    return Container(height:151,
      decoration:BoxDecoration(color:cs.surfaceContainerLowest,
        border:Border(bottom:BorderSide(color:cs.outlineVariant.withValues(alpha:.45)))),
      child:ClipRect(child:CustomPaint(painter:_PreviewPainter(doc),
        child:const SizedBox.expand())));
  }
  void _settings(){
    showModalBottomSheet<void>(context:context,showDragHandle:true,isScrollControlled:true,
      builder:(c)=>SafeArea(child:ConstrainedBox(
      constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(c).height*.82),
      child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(18),
        child:Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Preferências',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
        const SizedBox(height:12),
        DropdownButtonFormField<ThemeMode>(initialValue:widget.theme,
          decoration:const InputDecoration(labelText:'Aparência'),
          items:const [
            DropdownMenuItem(value:ThemeMode.system,child:Text('Seguir o sistema')),
            DropdownMenuItem(value:ThemeMode.light,child:Text('Tema claro')),
            DropdownMenuItem(value:ThemeMode.dark,child:Text('Tema escuro')),
          ],onChanged:(v){if(v!=null)widget.onTheme(v);}),
        const SizedBox(height:8),
        ListTile(leading:const Icon(Icons.save_alt_outlined),
          title:const Text('Exportar backup de todos os cadernos'),
          subtitle:const Text('Arquivo editável e independente da nuvem'),
          onTap:(){Navigator.pop(c);_exportBackup();}),
        ListTile(leading:const Icon(Icons.restore_outlined),
          title:const Text('Restaurar backup'),
          subtitle:const Text('Sem substituir os seus desenhos existentes'),
          onTap:(){Navigator.pop(c);_restoreBackup();}),
        ListTile(leading:const Icon(Icons.file_open_outlined),
          title:const Text('Importar desenho editável'),
          subtitle:const Text('Abrir arquivo .ci.json salvo ou transferido'),
          onTap:(){Navigator.pop(c);_importNative();}),
        const SizedBox(height:8),
        ListTile(leading:const Icon(Icons.cloud_outlined),
          title:Text(connected?'Google Drive conectado':'Entrar com Google'),
          subtitle:Text(connected?(accountEmail??'Sincronizar desenhos'):
            'Autorize uma vez e use nos dois aparelhos'),
          onTap:(){Navigator.pop(c);_cloudPanel();}),
        if (Platform.isWindows) ListTile(
          leading: const Icon(Icons.vpn_key_outlined),
          title: const Text('Corrigir configuração Google deste PC'),
          subtitle: const Text('Importar outro JSON OAuth Desktop se necessário'),
          onTap: () {Navigator.pop(c); _replaceDesktopCredentials();},
        ),
        if(connected)ListTile(leading:const Icon(Icons.logout),title:const Text('Desconectar conta Google'),
          onTap:(){Navigator.pop(c);_disconnect();}),
        const Padding(padding:EdgeInsets.all(9),child:Text(
          'Se houver alterações diferentes no PC e no celular, uma cópia local de conflito será mantida. '
          'O app funciona sem internet e sincroniza quando a galeria está aberta, '
          'ao retomá-la e após sair do editor.',style:TextStyle(fontSize:12))),
      ]))))));
  }
  @override Widget build(BuildContext context) {
    final wide=ResponsiveLayout.libraryHasSidebar(MediaQuery.sizeOf(context).width);
    final cs=Theme.of(context).colorScheme;
    final items=visibleDocs;
    return Scaffold(
      drawer:wide?null:Drawer(child:SafeArea(child:_sidebar(false))),
      appBar:AppBar(
        toolbarHeight:68,
        title:Row(mainAxisSize:MainAxisSize.min,children:[
          Container(width:34,height:34,decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(11),color:cs.primary),
            child:const Icon(Icons.draw_outlined,color:Colors.white,size:20)),
          const SizedBox(width:12),
          const Flexible(child:Text('Caderno Infinito',overflow:TextOverflow.ellipsis)),
        ]),
        actions:[
          if(busy || bulkWorking)const Padding(padding:EdgeInsets.symmetric(horizontal:12),
            child:Center(child:SizedBox(width:19,height:19,
              child:CircularProgressIndicator(strokeWidth:2)))),
          IconButton(tooltip:connected?'Conta Google e sincronização':'Entrar com Google',
            onPressed:busy || bulkWorking?null:_cloudPanel,
            icon:Icon(connected?Icons.cloud_done_outlined:Icons.cloud_outlined)),
          IconButton(tooltip:'Preferências e backups',onPressed:_settings,
            icon:const Icon(Icons.tune_outlined)),
          const SizedBox(width:12),
        ],
      ),
      body:Row(children:[
        if(wide)Container(
          width:246,
          decoration:BoxDecoration(color:cs.surface,
            border:Border(right:BorderSide(color:cs.outlineVariant.withValues(alpha:.45)))),
          child:SafeArea(top:false,child:_sidebar(true))),
        Expanded(child:Center(child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:1220),
          child:Column(children:[
            Padding(padding:EdgeInsets.fromLTRB(wide?30:18,26,wide?30:18,18),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                LayoutBuilder(builder:(ctx,available){
                  final narrow=ResponsiveLayout.galleryHeaderIsStacked(available.maxWidth);
                  final heading=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(showTrash?'Lixeira':folder=='Todos'?'Sua biblioteca':folder.split('/').last,
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      style:Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight:FontWeight.w700,letterSpacing:-.6)),
                    const SizedBox(height:4),
                    Text(showTrash?'Recupere ou apague definitivamente seus desenhos':
                      '${items.length} ${items.length==1?'desenho':'desenhos'} neste espaço',
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      style:Theme.of(context).textTheme.bodySmall?.copyWith(color:cs.onSurfaceVariant)),
                  ]);
                  final createAction=showTrash && items.isNotEmpty
                    ? OutlinedButton.icon(onPressed:busy?null:()=>_deleteForever(
                        docs.where((d)=>d.deleted).toList()),
                        icon:const Icon(Icons.delete_forever_outlined,size:19),
                        label:const Text('Esvaziar lixeira'))
                    : !showTrash ? FilledButton.icon(onPressed:_newDoc,
                        icon:const Icon(Icons.add,size:19),label:const Text('Novo desenho'))
                    : const SizedBox.shrink();
                  if(narrow)return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    heading,const SizedBox(height:14),createAction,
                  ]);
                  return Row(children:[Expanded(child:heading),const SizedBox(width:12),createAction]);
                }),
                const SizedBox(height:22),
                Row(children:[
                  Expanded(child:TextField(
                    controller:search,
                    onChanged:(value)=>setState(() {query=value;selectedIds.clear();}),
                    decoration:InputDecoration(
                      hintText:'Buscar por título, pasta ou texto',
                      prefixIcon:const Icon(Icons.search_outlined),
                      suffixIcon:query.isEmpty?null:IconButton(
                        tooltip:'Limpar pesquisa',icon:const Icon(Icons.close),
                        onPressed:(){search.clear();setState(() {query='';selectedIds.clear();});})),
                  )),
                  const SizedBox(width:10),
                  PopupMenuButton<String>(
                    tooltip:'Ordenar desenhos',
                    onSelected:(v)=>setState(()=>sort=v),
                    itemBuilder:(_)=>['Recentes','Antigos','Título'].map((v)=>
                      CheckedPopupMenuItem<String>(value:v,checked:v==sort,child:Text(v))).toList(),
                    child:Container(height:48,padding:const EdgeInsets.symmetric(horizontal:12),
                      decoration:BoxDecoration(color:cs.surface,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:cs.outlineVariant.withValues(alpha:.65))),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        const Icon(Icons.sort,size:19),if(wide)...[
                          const SizedBox(width:8),Text(sort),
                        ],
                        const SizedBox(width:3),const Icon(Icons.keyboard_arrow_down,size:16),
                      ])),
                  ),
                ]),
                if(!wide) ...[
                  const SizedBox(height:11),
                  SizedBox(height:42,child:ListView(scrollDirection:Axis.horizontal,
                    children:[
                    for(final f in ['Todos',...folders,'Lixeira'])
                      Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(
                        avatar:Icon(f=='Lixeira'?Icons.delete_outline:
                          f=='Todos'?Icons.grid_view_outlined:Icons.folder_outlined,size:17),
                        label:Text(f=='Todos'?'Todos':f.split('/').last),
                        selected:folder==f,onSelected:(_)=>_switchFolder(f),
                      )),
                  ])),
                ],
                const SizedBox(height:12),
                Row(children:[
                  Icon(connected?Icons.cloud_done_outlined:Icons.cloud_off_outlined,
                    size:16,color:connected?cs.primary:cs.outline),
                  const SizedBox(width:7),
                  Expanded(child:Text(syncStatus,maxLines:1,overflow:TextOverflow.ellipsis,
                    style:Theme.of(context).textTheme.labelSmall?.copyWith(color:cs.onSurfaceVariant))),
                  if(!wide)TextButton.icon(onPressed:_newFolder,
                    icon:const Icon(Icons.create_new_folder_outlined,size:17),
                    label:const Text('Pasta')),
                ]),
                if(items.isNotEmpty || selecting ||
                    GalleryBulkActions.inFolder(docs,folder,trash:showTrash).isNotEmpty) ...[
                  const SizedBox(height:12),
                  _bulkToolbar(items),
                ],
              ]),
            ),
            Expanded(child:items.isEmpty?_emptyState(cs):GridView.builder(
              padding:EdgeInsets.fromLTRB(wide?30:18,0,wide?30:18,32),
              gridDelegate:SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:ResponsiveLayout.galleryCardMaxWidth(MediaQuery.sizeOf(context).width),
                mainAxisExtent:ResponsiveLayout.galleryCardHeight(MediaQuery.sizeOf(context).width),
                crossAxisSpacing:14,mainAxisSpacing:14),
              itemCount:items.length,
              itemBuilder:(context,i) {
                final doc=items[i];
                return Card(clipBehavior:Clip.antiAlias,
                  child:InkWell(
                    onTap:selecting?()=>_toggleSelection(doc.id):
                      (showTrash?()=>_action(doc,'restore'):()=>_open(doc)),
                    onLongPress:()=>_toggleSelection(doc.id),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
                      Stack(children:[
                        _miniature(doc),
                        if(selecting)Positioned(right:8,top:8,
                          child:Material(color:cs.surface,borderRadius:BorderRadius.circular(20),
                            elevation:2,child:Checkbox(
                              semanticLabel:'Selecionar ${doc.title}',
                              value:selectedIds.contains(doc.id),
                              onChanged:(_)=>_toggleSelection(doc.id),
                              visualDensity:VisualDensity.compact))),
                      ]),
                      Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(14,12,6,8),
                        child:Row(children:[
                          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            Text(doc.title,maxLines:1,overflow:TextOverflow.ellipsis,
                              style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700)),
                            const SizedBox(height:4),
                            Text(doc.folder,maxLines:1,overflow:TextOverflow.ellipsis,
                              style:Theme.of(context).textTheme.labelSmall?.copyWith(color:cs.onSurfaceVariant)),
                            const Spacer(),
                            Text('${doc.layers.length} camadas · ${doc.elements.length} elementos',
                              style:Theme.of(context).textTheme.labelSmall?.copyWith(color:cs.outline)),
                          ])),
                          if(!selecting)PopupMenuButton<String>(tooltip:'Ações do desenho',
                            onSelected:(action)=>_action(doc,action),
                            itemBuilder:(_)=>showTrash?const [
                              PopupMenuItem(value:'restore',child:Row(children:[Icon(Icons.restore_outlined),SizedBox(width:10),Text('Restaurar desenho')])),
                              PopupMenuItem(value:'deleteForever',child:Row(children:[Icon(Icons.delete_forever_outlined),SizedBox(width:10),Text('Excluir definitivamente')])),
                            ]:const [
                              PopupMenuItem(value:'open',child:Row(children:[Icon(Icons.open_in_new_outlined),SizedBox(width:10),Text('Abrir desenho')])),
                              PopupMenuItem(value:'rename',child:Row(children:[Icon(Icons.edit_outlined),SizedBox(width:10),Text('Renomear desenho')])),
                              PopupMenuItem(value:'move',child:Row(children:[Icon(Icons.drive_file_move_outlined),SizedBox(width:10),Text('Mover para pasta')])),
                              PopupMenuItem(value:'duplicate',child:Row(children:[Icon(Icons.content_copy_outlined),SizedBox(width:10),Text('Criar uma cópia')])),
                              PopupMenuItem(value:'delete',child:Row(children:[Icon(Icons.delete_outline),SizedBox(width:10),Text('Mover para a lixeira')])),
                            ],
                          ),
                        ])),
                      ),
                    ])),
                );
              },
            )),
          ]),
        ))),
      ]),
    );
  }

  Widget _emptyState(ColorScheme cs) => Center(child:Padding(
    padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:76,height:76,decoration:BoxDecoration(
        color:cs.primaryContainer.withValues(alpha:.5),borderRadius:BorderRadius.circular(24)),
        child:Icon(showTrash?Icons.delete_outline:Icons.auto_stories_outlined,
          size:34,color:cs.primary)),
      const SizedBox(height:18),
      Text(showTrash?'Lixeira vazia':'Um espaço para suas ideias',
        style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w700)),
      const SizedBox(height:8),
      Text(showTrash?'Os desenhos excluídos aparecem aqui.':
        'Crie um desenho, escreva à mão e organize suas ideias em qualquer dispositivo.',
        textAlign:TextAlign.center,
        style:Theme.of(context).textTheme.bodyMedium?.copyWith(color:cs.onSurfaceVariant)),
      const SizedBox(height:18),
      if(!showTrash)FilledButton.icon(onPressed:_newDoc,
        icon:const Icon(Icons.add),label:const Text('Criar desenho')),
    ]),
  ));

}

class _PreviewPainter extends CustomPainter {
  final Sketch doc;
  _PreviewPainter(this.doc);
  @override void paint(Canvas canvas,Size size){
    canvas.drawRect(Offset.zero&size,Paint()..color=colorFromHex(doc.background));
    canvas.save();
    final bounds=doc.contentBounds;
    final scale=(mathMin(size.width/bounds.width,size.height/bounds.height)*.92).clamp(.03,2.0).toDouble();
    canvas.translate((size.width-bounds.width*scale)/2-bounds.left*scale,
      (size.height-bounds.height*scale)/2-bounds.top*scale);
    canvas.scale(scale);
    BoardRenderer.paint(canvas,doc,bounds,grids:true,zoom:scale);
    canvas.restore();
  }
  static double mathMin(double a,double b) => a<b?a:b;
  @override bool shouldRepaint(covariant _PreviewPainter old)=>old.doc.id!=doc.id || old.doc.updatedAt!=doc.updatedAt;
}
