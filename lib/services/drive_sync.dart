import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/sketch.dart';
import 'local_store.dart';

const _driveScope = 'https://www.googleapis.com/auth/drive.file';
const _webClient = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _desktopClient = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
const _desktopSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

/// Configuração de desenvolvedor: IDs OAuth identificam o aplicativo, não o usuário.
/// No Windows, o arquivo JSON de cliente Desktop pode ser importado uma vez.
/// No Android, um Web Client ID pode vir do build ou do google-services.json.
class DesktopOAuthConfiguration {
  final String clientId;
  final String clientSecret;
  const DesktopOAuthConfiguration(this.clientId, this.clientSecret);

  static bool isClientId(String value) =>
      RegExp(r'^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$')
          .hasMatch(value);

  static DesktopOAuthConfiguration fromGoogleJson(String text) {
    if (utf8.encode(text).length > 65536) {
      throw const FormatException('Arquivo de credenciais muito grande.');
    }
    final json = jsonDecode(text);
    if (json is! Map || json['installed'] is! Map) {
      throw const FormatException('Selecione o JSON de um cliente OAuth do tipo "App para computador".');
    }
    final settings = Map<String, dynamic>.from(json['installed'] as Map);
    final id = settings['client_id'];
    final secret = settings['client_secret'];
    if (id is! String || !isClientId(id)) {
      throw const FormatException('ID do cliente Google inválido no JSON.');
    }
    if (secret != null && secret is! String) {
      throw const FormatException('Segredo do cliente inválido no JSON.');
    }
    return DesktopOAuthConfiguration(id, secret as String? ?? '');
  }
}

/// O arquivo OAuth Web não contém senha de usuário; extrai apenas o Client ID.
class WebOAuthConfiguration {
  static String fromGoogleJson(String text) {
    if (utf8.encode(text).length > 65536) {
      throw const FormatException('Arquivo de configuração muito grande.');
    }
    final raw = jsonDecode(text);
    if (raw is! Map || raw['web'] is! Map) {
      throw const FormatException('Selecione um JSON OAuth do tipo Aplicativo Web.');
    }
    final id = (raw['web'] as Map)['client_id'];
    if (id is! String || !DesktopOAuthConfiguration.isClientId(id)) {
      throw const FormatException('O JSON não contém um Web Client ID válido.');
    }
    return id;
  }
}

class DriveAuthorization {
  final secure = const FlutterSecureStorage();
  GoogleSignInAccount? _androidAccount;
  String? _cachedToken;
  DateTime _expires = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initialized = false;
  Future<void>? _initializing;

  Future<void> init() async {
    if (!Platform.isAndroid || _initialized) return;
    // initialize() no plugin 7.x deve ocorrer uma única vez por processo.
    _initializing ??= _initAndroid();
    await _initializing;
  }

  Future<String?> _androidClientId() async {
    if (DesktopOAuthConfiguration.isClientId(_webClient.trim())) {
      return _webClient.trim();
    }
    final imported = await secure.read(key: 'ci_android_web_oauth_id');
    return imported != null && DesktopOAuthConfiguration.isClientId(imported)
      ? imported : null;
  }

  Future<bool> get needsAndroidSetup async =>
      Platform.isAndroid && (await _androidClientId()) == null;

  Future<void> importAndroidCredentialsJson(String content) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Importação Web OAuth disponível no Android.');
    }
    if (_initialized) {
      throw StateError('Reinicie o aplicativo antes de trocar de projeto Google.');
    }
    final id = WebOAuthConfiguration.fromGoogleJson(content);
    await secure.write(key: 'ci_android_web_oauth_id', value: id);
  }

  Future<void> _initAndroid() async {
    try {
      final client = await _androidClientId();
      if (client == null) {
        throw StateError('Configure o login selecionando o JSON OAuth Web do Google Cloud.');
      }
      await GoogleSignIn.instance.initialize(serverClientId: client);
      _initialized = true;
    } catch (_) {
      _initializing = null; // Uma configuração corrigida pode ser tentada depois.
      rethrow;
    }
  }

  Future<DesktopOAuthConfiguration?> _desktopConfig() async {
    if (DesktopOAuthConfiguration.isClientId(_desktopClient)) {
      return DesktopOAuthConfiguration(_desktopClient, _desktopSecret);
    }
    final id = await secure.read(key: 'ci_desktop_oauth_id');
    if (id == null || !DesktopOAuthConfiguration.isClientId(id)) return null;
    return DesktopOAuthConfiguration(
        id, await secure.read(key: 'ci_desktop_oauth_secret') ?? '');
  }

  /// Apenas o primeiro uso no Windows pode exigir selecionar o JSON baixado
  /// no Google Cloud. Nas demais execuções, basta Entrar com Google.
  Future<bool> get needsDesktopSetup async =>
      Platform.isWindows && await _desktopConfig() == null;

  Future<void> importDesktopCredentialsJson(String content) async {
    if (!Platform.isWindows) throw UnsupportedError('Importação de OAuth apenas no Windows.');
    final parsed = DesktopOAuthConfiguration.fromGoogleJson(content);
    // Tokens gerados por outro client ID não podem ser reutilizados.
    await logout();
    await secure.write(key: 'ci_desktop_oauth_id', value: parsed.clientId);
    await secure.write(key: 'ci_desktop_oauth_secret', value: parsed.clientSecret);
  }

  Future<String?> get accountEmail async {
    if (Platform.isAndroid) {
      await init();
      _androidAccount ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
      return _androidAccount?.email;
    }
    return secure.read(key: 'ci_google_email');
  }

  Future<bool> get hasSession async {
    if (Platform.isAndroid) {
      await init();
      _androidAccount ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
      return _androidAccount != null;
    }
    if (!Platform.isWindows || await _desktopConfig() == null) return false;
    return (await secure.read(key: 'refreshToken')) != null ||
        (await secure.read(key: 'accessToken')) != null;
  }

  Future<String> token({bool interactive = false}) async {
    if (Platform.isAndroid) {
      await init();
      _androidAccount ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (_androidAccount == null && interactive) {
        _androidAccount = await GoogleSignIn.instance.authenticate(
          scopeHint: const [_driveScope],
        );
      }
      if (_androidAccount == null) {
        throw StateError('Entre com sua conta Google para sincronizar.');
      }
      final client = _androidAccount!.authorizationClient;
      final allowed = await client.authorizationForScopes(const [_driveScope]);
      if (allowed != null) return allowed.accessToken;
      if (!interactive) {
        throw StateError('Toque em Entrar com Google para autorizar o Drive.');
      }
      return (await client.authorizeScopes(const [_driveScope])).accessToken;
    }
    if (!Platform.isWindows) throw UnsupportedError('Suporte a Windows e Android.');
    final credentials = await _desktopConfig();
    if (credentials == null) {
      throw StateError('Importe uma vez o JSON OAuth Desktop para ativar o login neste PC.');
    }
    if (_cachedToken != null &&
        DateTime.now().isBefore(_expires.subtract(const Duration(minutes: 2)))) {
      return _cachedToken!;
    }
    final stored = await secure.read(key: 'accessToken');
    final expiry = int.tryParse(await secure.read(key: 'expiryMs') ?? '') ?? 0;
    if (stored != null && DateTime.now().millisecondsSinceEpoch + 120000 < expiry) {
      _cachedToken = stored;
      _expires = DateTime.fromMillisecondsSinceEpoch(expiry);
      return stored;
    }
    final refresh = await secure.read(key: 'refreshToken');
    if (refresh != null) {
      try {
        final response = await http.post(
            Uri.parse('https://oauth2.googleapis.com/token'), body: {
          'client_id': credentials.clientId,
          if (credentials.clientSecret.isNotEmpty)
            'client_secret': credentials.clientSecret,
          'refresh_token': refresh,
          'grant_type': 'refresh_token',
        }).timeout(const Duration(seconds: 30));
        if (response.statusCode == 200) {
          await _saveToken(jsonDecode(response.body) as Map<String, dynamic>);
          return _cachedToken!;
        }
      } catch (_) { /* Após falha, solicitará novo login por gesto do usuário. */ }
    }
    if (!interactive) throw StateError('Sessão expirada. Entre novamente com Google.');
    return _desktopLogin(credentials);
  }

  Future<void> _saveToken(Map<String, dynamic> json) async {
    _cachedToken = json['access_token'] as String?;
    if (_cachedToken == null) throw StateError('Google não retornou acesso válido.');
    final seconds = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _expires = DateTime.now().add(Duration(seconds: seconds));
    await secure.write(key: 'accessToken', value: _cachedToken);
    await secure.write(
        key: 'expiryMs', value: '${_expires.millisecondsSinceEpoch}');
    if (json['refresh_token'] is String) {
      await secure.write(key: 'refreshToken', value: json['refresh_token'] as String);
    }
  }

  String _randomUrlSafe(int bytes) {
    final rng = Random.secure();
    return base64Url
        .encode(List<int>.generate(bytes, (_) => rng.nextInt(256)))
        .replaceAll('=', '');
  }

  Future<void> _fetchAccountEmail() async {
    if (_cachedToken == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'),
        headers: {'Authorization': 'Bearer $_cachedToken'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final email = parsed['email'];
        if (email is String && email.contains('@')) {
          await secure.write(key: 'ci_google_email', value: email);
        }
      }
    } catch (_) { /* Identificação visual opcional; não bloqueia o Drive. */ }
  }

  Future<Uri> _receiveCallback(HttpServer server, String expectedState) async {
    await for (final request in server.timeout(const Duration(minutes: 3))) {
      if (request.uri.path != '/') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }
      final stateOk = request.uri.queryParameters['state'] == expectedState;
      final code = request.uri.queryParameters['code'];
      final googleError = request.uri.queryParameters['error'];
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      if (!stateOk) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('<!doctype html><meta charset="utf-8"><title>Solicitação inválida</title>');
        await request.response.close();
        continue; // Não aceita códigos de outro fluxo OAuth.
      }
      request.response.write(code != null && googleError == null
          ? '<!doctype html><meta charset="utf-8"><title>Conta conectada</title><h2>Autorização recebida.</h2><p>Volte ao Caderno Infinito.</p>'
          : '<!doctype html><meta charset="utf-8"><title>Não autorizado</title><h2>Autorização cancelada.</h2><p>Volte ao aplicativo.</p>');
      await request.response.close();
      if (googleError != null || code == null) {
        throw StateError('Autorização Google cancelada ou recusada.');
      }
      return request.uri;
    }
    throw StateError('Não foi possível receber o retorno do login Google.');
  }

  Future<String> _desktopLogin(DesktopOAuthConfiguration credentials) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}/';
    final state = _randomUrlSafe(18);
    final verifier = _randomUrlSafe(48);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': credentials.clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': 'openid email $_driveScope',
      'access_type': 'offline',
      'prompt': 'select_account consent',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
    });
    try {
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw StateError('Não foi possível abrir o navegador do Google.');
      }
      final callback = await _receiveCallback(server, state);
      final oauthError = callback.queryParameters['error'];
      if (oauthError != null) {
        throw StateError('Autorização Google não concluída ($oauthError). '
            'Tente novamente pelo botão Entrar com Google.');
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw StateError('Google não retornou o código de autorização. '
            'Tente novamente ou confira a configuração OAuth Desktop.');
      }
      final result = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'), body: {
        'client_id': credentials.clientId,
        if (credentials.clientSecret.isNotEmpty)
          'client_secret': credentials.clientSecret,
        'code': code,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      }).timeout(const Duration(seconds: 30));
      if (result.statusCode != 200) {
        throw StateError('Google não concluiu o login (${result.statusCode}). Confira o cadastro OAuth.');
      }
      await _saveToken(jsonDecode(result.body) as Map<String, dynamic>);
      await _fetchAccountEmail();
      return _cachedToken!;
    } on TimeoutException {
      throw StateError('O prazo do login terminou. Toque em Entrar com Google novamente.');
    } finally {
      await server.close(force: true);
    }
  }

  Future<void> invalidateToken(String invalidToken) async {
    if (Platform.isAndroid && _androidAccount != null) {
      await _androidAccount!.authorizationClient
          .clearAuthorizationToken(accessToken: invalidToken);
      return;
    }
    _cachedToken = null;
    _expires = DateTime.fromMillisecondsSinceEpoch(0);
    await secure.delete(key: 'accessToken');
    await secure.delete(key: 'expiryMs');
  }

  Future<void> logout() async {
    _cachedToken = null;
    _expires = DateTime.fromMillisecondsSinceEpoch(0);
    if (Platform.isAndroid && _initialized) {
      await GoogleSignIn.instance.signOut();
      _androidAccount = null;
    } else {
      await secure.delete(key: 'accessToken');
      await secure.delete(key: 'refreshToken');
      await secure.delete(key: 'expiryMs');
      await secure.delete(key: 'ci_google_email');
    }
    // Não apagamos a configuração OAuth importada nem os desenhos locais.
  }
}

class CloudFile {
  final String id, name, md5;
  CloudFile(Map<String,dynamic> j) : id = j['id'] as String,
    name = j['name'] as String, md5 = j['md5Checksum'] as String? ?? '';
}

class DriveApi {
  final DriveAuthorization auth;
  DriveApi(this.auth);
  Future<http.Response> _send(String method, Uri url, {Object? body, Map<String,String>? headers}) async {
    Future<http.Response> invoke(String token) {
      final h = {'Authorization': 'Bearer $token', ...?headers};
      return switch (method) {
        'GET' => http.get(url, headers: h),
        'POST' => http.post(url, headers: h, body: body),
        'PATCH' => http.patch(url, headers: h, body: body),
        'PUT' => http.put(url, headers: h, body: body),
        'DELETE' => http.delete(url, headers: h),
        _ => throw StateError('Método não suportado'),
      };
    }
    final oldToken = await auth.token();
    var result = await invoke(oldToken).timeout(const Duration(seconds: 90));
    if (result.statusCode == 401) {
      await auth.invalidateToken(oldToken);
      result = await invoke(await auth.token(interactive: false)).timeout(const Duration(seconds: 90));
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw HttpException('Google Drive HTTP ${result.statusCode}: ${result.body}', uri: url);
    }
    return result;
  }

  Future<List<CloudFile>> list(String query) async {
    final result = <CloudFile>[];
    String? pageToken;
    do {
      final url = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q': query, 'fields': 'nextPageToken,files(id,name,md5Checksum,modifiedTime,mimeType)',
        'pageSize': '1000', 'spaces': 'drive', if (pageToken != null) 'pageToken': pageToken,
      });
      final j = jsonDecode((await _send('GET', url)).body) as Map<String,dynamic>;
      for (final e in (j['files'] as List? ?? [])) { result.add(CloudFile(e as Map<String,dynamic>)); }
      pageToken = j['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return result;
  }

  Future<String> ensureFolder() async {
    final folders = await list("name = 'Caderno Infinito' and mimeType = 'application/vnd.google-apps.folder' and 'root' in parents and trashed = false");
    if (folders.length > 1) {
      throw StateError('Existem várias pastas Caderno Infinito visíveis no Drive. ' 
          'Renomeie as duplicatas antes de sincronizar, para evitar cópias erradas.');
    }
    if (folders.isNotEmpty) return folders.single.id;
    final url = Uri.https('www.googleapis.com', '/drive/v3/files', {'fields': 'id'});
    final response = await _send('POST', url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'name': 'Caderno Infinito',
          'mimeType': 'application/vnd.google-apps.folder', 'parents': ['root']}));
    return (jsonDecode(response.body) as Map<String,dynamic>)['id'] as String;
  }

  Future<CloudFile> uploadNew(String folderId, String name, String text) async {
    final content = utf8.encode(text);
    final metadata = {'name': name, 'parents': [folderId], 'mimeType': 'application/json'};
    if (content.length > 5 * 1024 * 1024) {
      final startUri = Uri.https('www.googleapis.com', '/upload/drive/v3/files',
        {'uploadType': 'resumable', 'fields': 'id,name,md5Checksum'});
      final init = await _send('POST', startUri,
        body: jsonEncode(metadata), headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'X-Upload-Content-Type': 'application/json',
          'X-Upload-Content-Length': '${content.length}',
        });
      final result = await _send('PUT', _safeUploadUrl(init), body: content,
          headers: {'Content-Type': 'application/json', 'Content-Length': '${content.length}'});
      return CloudFile(jsonDecode(result.body) as Map<String,dynamic>);
    }
    final boundary = 'ci-${DateTime.now().microsecondsSinceEpoch}';
    final body = <int>[];
    void append(String v) => body.addAll(utf8.encode(v));
    append('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n');
    append(jsonEncode(metadata));
    append('\r\n--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n');
    append(text);
    append('\r\n--$boundary--\r\n');
    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files',
        {'uploadType': 'multipart', 'fields': 'id,name,md5Checksum'});
    final res = await _send('POST', uri, body: body,
        headers: {'Content-Type': 'multipart/related; boundary=$boundary'});
    return CloudFile(jsonDecode(res.body) as Map<String,dynamic>);
  }

  Uri _safeUploadUrl(http.Response response) {
    final raw = response.headers['location'];
    if (raw == null) throw StateError('Drive não devolveu endereço da sessão de upload.');
    final uri = Uri.parse(raw);
    if (uri.scheme != 'https' || !(uri.host == 'www.googleapis.com' ||
      uri.host.endsWith('.googleapis.com'))) {
      throw StateError('Endereço inesperado para envio ao Google Drive.');
    }
    return uri;
  }

  Future<CloudFile> update(String fileId, String text) async {
    final content=utf8.encode(text);
    if (content.length > 5 * 1024 * 1024) {
      final startUri=Uri.https('www.googleapis.com','/upload/drive/v3/files/$fileId',
        {'uploadType':'resumable','fields':'id,name,md5Checksum'});
      final init=await _send('PATCH',startUri,body:'{}',headers:{
        'Content-Type':'application/json; charset=UTF-8',
        'X-Upload-Content-Type':'application/json',
        'X-Upload-Content-Length':'${content.length}',
      });
      final res=await _send('PUT',_safeUploadUrl(init),body:content,
        headers:{'Content-Type':'application/json','Content-Length':'${content.length}'});
      final j=jsonDecode(res.body) as Map<String,dynamic>;
      j.putIfAbsent('name', () => '$fileId.ci.json');
      return CloudFile(j);
    }
    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files/$fileId',
        {'uploadType': 'media', 'fields': 'id,name,md5Checksum'});
    final res = await _send('PATCH', uri, body: content,
        headers: {'Content-Type': 'application/json; charset=UTF-8'});
    final j = jsonDecode(res.body) as Map<String,dynamic>;
    j.putIfAbsent('name', () => '$fileId.ci.json');
    return CloudFile(j);
  }

  Future<CloudFile> metadata(String fileId) async {
    final uri=Uri.https('www.googleapis.com','/drive/v3/files/$fileId',
      {'fields':'id,name,md5Checksum'});
    return CloudFile(jsonDecode((await _send('GET',uri)).body) as Map<String,dynamic>);
  }

  /// Exclui o arquivo criado pelo aplicativo, sem mover para a lixeira do Drive.
  Future<void> deleteFile(String fileId) async {
    await _send('DELETE', Uri.https('www.googleapis.com', '/drive/v3/files/$fileId'));
  }

  Future<String> download(String fileId) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/$fileId', {'alt': 'media'});
    return utf8.decode((await _send('GET', uri)).bodyBytes);
  }
}

class SyncReport {
  int sent = 0, received = 0, conflicts = 0, unchanged = 0;
  String get description => 'Enviados: $sent • Recebidos: $received • Conflitos preservados: $conflicts • Sem alterações: $unchanged';
}

/// Nunca escolhe arbitrariamente entre duas cópias remotas com o mesmo nome:
/// o Drive permite nomes repetidos, mas isso tornaria a sincronização ambígua.
class DuplicateCloudDocuments implements Exception {
  final List<String> names;
  const DuplicateCloudDocuments(this.names);
  @override String toString() => 'Arquivos duplicados no Google Drive: '
    '${names.join(', ')}. Renomeie as duplicatas na pasta Caderno Infinito '
    'antes de continuar; seus arquivos locais foram preservados.';
}

class CloudManifest {
  static void validate(Iterable<CloudFile> files) {
    final count=<String,int>{};
    for (final f in files) {
      if(!f.name.endsWith('.ci.json'))continue;
      count[f.name]=(count[f.name]??0)+1;
    }
    final duplicate=count.entries.where((e)=>e.value>1).map((e)=>e.key).toList()..sort();
    if(duplicate.isNotEmpty) throw DuplicateCloudDocuments(duplicate);
  }

  static Sketch decodeVerified(String body,String expectedId,String checksum) {
    final hash=md5.convert(utf8.encode(body)).toString();
    if(checksum.isNotEmpty && hash!=checksum) {
      throw const FormatException('Checksum inválido; o desenho remoto não foi aplicado.');
    }
    final doc=Sketch.fromJson(jsonDecode(body) as Map<String,dynamic>);
    if(doc.id!=expectedId) {
      throw FormatException('Documento remoto possui ID diferente do arquivo: $expectedId');
    }
    return doc;
  }
}

class DriveFolderChanged implements Exception {
  final String oldId, newId;
  const DriveFolderChanged(this.oldId, this.newId);
  @override String toString() =>
    'A conta ou a pasta do Drive mudou. Confirme a troca antes de sincronizar os desenhos locais.';
}

/// Guarda a identidade da pasta remota e bloqueia troca silenciosa de conta.
class DriveBinding {
  static void verify(Map<String, dynamic> index, String folderId,
      Iterable<String> remoteIds) {
    final lastFolder=index['_remoteFolderId'] as String?;
    if(lastFolder != null && lastFolder != folderId) {
      throw DriveFolderChanged(lastFolder, folderId);
    }
    if(lastFolder == null && index.isNotEmpty) {
      final previousIds=index.values.whereType<Map>()
        .map((entry)=>entry['fileId']).whereType<String>().toSet();
      final cloudIds=remoteIds.toSet();
      if(previousIds.isNotEmpty && previousIds.intersection(cloudIds).isEmpty) {
        throw DriveFolderChanged('índice legado sem vínculo verificado', folderId);
      }
    }
    index['_remoteFolderId']=folderId;
  }
}

/// Marcadores remotos impedem que outro dispositivo reenvie desenhos apagados.
/// Cada exclusão é um arquivo pequeno e persistente na pasta do aplicativo.
class DeletionMarkers {
  static const suffix = '.ci.deleted';
  static final _idPattern = RegExp(r'^[a-zA-Z0-9_-]{8,80}$');
  static String nameFor(String id) {
    if (!_idPattern.hasMatch(id)) throw const FormatException('ID de desenho inválido.');
    return '$id$suffix';
  }
  static String? idFromName(String filename) {
    if (!filename.endsWith(suffix)) return null;
    final id = filename.substring(0, filename.length - suffix.length);
    return _idPattern.hasMatch(id) ? id : null;
  }
}

class DriveSync {
  final LocalStore store;
  final DriveAuthorization auth;
  DriveSync(this.store, this.auth);
  bool busy = false;

  /// Permite mudar de conta apenas após confirmação explícita na interface.
  /// Documentos locais permanecem intactos; a nova pasta recebe o acervo.
  Future<void> confirmUseOfNewDrive() async {
    if (busy) throw StateError('Espere a sincronização terminar.');
    final folder = await DriveApi(auth).ensureFolder();
    await store.saveIndex({'_remoteFolderId': folder});
  }

  Future<SyncReport> sync() async {
    if (busy) throw StateError('Sincronização já em andamento.');
    busy = true;
    try {
      final api = DriveApi(auth);
      final folder = await api.ensureFolder();
      // Inclui desenhos e marcadores de exclusão. Não se deve tratar um
      // marcador como um desenho editável.
      final remoteFiles = await api.list("'$folder' in parents and trashed = false");
      CloudManifest.validate(remoteFiles);
      final index = await store.readIndex();
      DriveBinding.verify(index, folder, remoteFiles.map((f)=>f.id));
      await store.saveIndex(index);
      // Primeiro converge as exclusões definitivas entre aparelhos, antes de
      // baixar ou reenviar qualquer documento. Os marcadores ficam na nuvem.
      final remoteDeleted = <String>{};
      for (final file in remoteFiles) {
        final id = DeletionMarkers.idFromName(file.name);
        if (id != null) remoteDeleted.add(id);
      }
      final localDeleted = store.permanentlyDeletedIds;
      for (final id in localDeleted.difference(remoteDeleted)) {
        await api.uploadNew(folder, DeletionMarkers.nameFor(id),
          jsonEncode({'id': id, 'deletedAt': DateTime.now().toUtc().toIso8601String()}));
      }
      final deleted = {...remoteDeleted, ...localDeleted};
      for (final id in deleted) {
        await store.permanentlyDelete(id);
        for (final file in remoteFiles) {
          if (file.name == '$id.ci.json') await api.deleteFile(file.id);
        }
        index.remove(id);
      }
      if (deleted.isNotEmpty) await store.saveIndex(index);
      final docs = {for (final doc in await store.all()) doc.id: doc};
      final remote = <String,CloudFile>{};
      for (final f in remoteFiles) {
        if (f.name.endsWith('.ci.json')) {
          final id = f.name.substring(0, f.name.length - '.ci.json'.length);
          if (!deleted.contains(id)) remote[id] = f;
        }
      }
      final report = SyncReport();
      for (final item in remote.entries) {
        final id = item.key;
        final file = item.value;
        final local = docs[id];
        final prior = index[id] is Map ? Map<String,dynamic>.from(index[id] as Map) : <String,dynamic>{};
        final previousRemoteHash = prior['remoteMd5'] as String? ?? '';
        final previousLocalHash = prior['localMd5'] as String? ?? '';
        final localHash = local == null ? '' : md5.convert(utf8.encode(local.serialize())).toString();
        final remoteChanged = previousRemoteHash.isEmpty || file.md5.isEmpty || file.md5 != previousRemoteHash;
        final identical = local != null && file.md5.isNotEmpty && localHash == file.md5;
        final localChanged = local != null && (previousLocalHash.isEmpty || localHash != previousLocalHash);
        if (identical) {
          index[id] = {'fileId':file.id,'remoteMd5':file.md5,'localMd5':localHash};
          report.unchanged++;
        } else if (local == null || (remoteChanged && !localChanged)) {
          final downloaded = CloudManifest.decodeVerified(
            await api.download(file.id),id,file.md5);
          await store.save(downloaded);
          docs[id] = downloaded;
          final hash = md5.convert(utf8.encode(downloaded.serialize())).toString();
          index[id] = {'fileId': file.id, 'remoteMd5': file.md5.isEmpty ? hash : file.md5, 'localMd5': hash};
          report.received++;
        } else if (remoteChanged && localChanged) {
          final copy = local.clone();
          copy.id = newId();
          copy.title = '${copy.title} (conflito local ${DateTime.now().toLocal().toIso8601String().substring(0, 16)})';
          copy.touch();
          await store.save(copy);
          docs[copy.id] = copy;
          final downloaded = CloudManifest.decodeVerified(
            await api.download(file.id),id,file.md5);
          await store.save(downloaded);
          docs[id] = downloaded;
          final hash = md5.convert(utf8.encode(downloaded.serialize())).toString();
          index[id] = {'fileId': file.id, 'remoteMd5': file.md5.isEmpty ? hash : file.md5, 'localMd5': hash};
          report.conflicts++;
          report.received++;
        } else if (localChanged) {
          // Uma edição remota pode ter ocorrido depois da listagem inicial.
          // Reconsultamos antes de substituir; preservamos ambas se divergir.
          final latest = await api.metadata(file.id);
          if(file.md5.isNotEmpty && latest.md5.isNotEmpty && latest.md5!=file.md5) {
            final conflict=local.clone();
            conflict.id=newId();
            conflict.title='${conflict.title} (cópia de conflito)';
            conflict.touch();
            await store.save(conflict);
            docs[conflict.id]=conflict;
            final downloaded=CloudManifest.decodeVerified(
              await api.download(file.id),id,latest.md5);
            await store.save(downloaded);docs[id]=downloaded;
            final hash=md5.convert(utf8.encode(downloaded.serialize())).toString();
            index[id]={'fileId':file.id,'remoteMd5':latest.md5,'localMd5':hash};
            report.conflicts++;report.received++;
          }else{
            final fresh = await api.update(file.id, local.serialize());
            index[id] = {'fileId': file.id, 'remoteMd5': fresh.md5.isEmpty ? localHash : fresh.md5,
              'localMd5': localHash};
            report.sent++;
          }
        } else {
          index[id] = {'fileId': file.id,
            'remoteMd5': file.md5.isEmpty ? localHash : file.md5, 'localMd5': localHash};
          report.unchanged++;
        }
        await store.saveIndex(index);
      }
      for (final doc in docs.values) {
        if (remote.containsKey(doc.id)) continue;
        final text = doc.serialize();
        final fresh = await api.uploadNew(folder, '${doc.id}.ci.json', text);
        final hash = md5.convert(utf8.encode(text)).toString();
        index[doc.id] = {'fileId': fresh.id,
          'remoteMd5': fresh.md5.isEmpty ? hash : fresh.md5, 'localMd5': hash};
        report.sent++;
        await store.saveIndex(index);
      }
      return report;
    } finally { busy = false; }
  }
}
