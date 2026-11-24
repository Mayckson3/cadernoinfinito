import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class PexelsPhoto {
  final int id;
  final String photographer, page, preview, original;
  PexelsPhoto(Map<String,dynamic> j)
    : id=(j['id'] as num).toInt(),photographer=j['photographer'] as String? ?? '',
      page=j['url'] as String? ?? '',
      preview=(j['src'] as Map<String,dynamic>)['medium'] as String? ?? '',
      original=(j['src'] as Map<String,dynamic>)['large2x'] as String? ?? '';
}

class PexelsService {
  static const secure=FlutterSecureStorage();
  static const keyName='pexelsApiKey';
  Future<String?> get key=>secure.read(key:keyName);
  Future<void> setKey(String value)=>secure.write(key:keyName,value:value.trim());
  Uri _safeUri(String url) {
    final uri=Uri.parse(url);
    if(uri.scheme!='https'||uri.host!='images.pexels.com') {
      throw const FormatException('A resposta da API contém endereço inesperado.');
    }
    return uri;
  }
  Future<List<PexelsPhoto>> search(String query) async {
    final apiKey=await key;
    if(apiKey==null||apiKey.isEmpty)throw StateError('Configure uma chave da API Pexels.');
    if(query.trim().isEmpty)return [];
    final uri=Uri.https('api.pexels.com','/v1/search',{'query':query,'per_page':'12','locale':'pt-BR'});
    final response=await http.get(uri,headers:{'Authorization':apiKey});
    if(response.statusCode!=200)throw StateError('Falha Pexels HTTP ${response.statusCode}.');
    final json=jsonDecode(response.body) as Map<String,dynamic>;
    return (json['photos'] as List? ?? []).map((e)=>PexelsPhoto(e as Map<String,dynamic>)).toList();
  }
  Future<Uint8List> download(PexelsPhoto photo) async {
    final response=await http.get(_safeUri(photo.original));
    if(response.statusCode!=200)throw StateError('Erro ao baixar foto ${photo.id}.');
    if(response.bodyBytes.length>18*1024*1024)throw StateError('Foto excede limite de 18 MB.');
    return response.bodyBytes;
  }
}
