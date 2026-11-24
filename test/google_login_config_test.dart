import 'package:flutter_test/flutter_test.dart';
import 'package:caderno_infinito/services/drive_sync.dart';

void main() {
  group('Configuração Google sem digitar IDs', () {
    test('lê um arquivo OAuth Desktop real no formato installed', () {
      const raw = '''{"installed":{"client_id":"123456-abc_xyz.apps.googleusercontent.com","client_secret":"public-desktop-secret","auth_uri":"https://accounts.google.com/o/oauth2/auth"}}''';
      final parsed = DesktopOAuthConfiguration.fromGoogleJson(raw);
      expect(parsed.clientId, '123456-abc_xyz.apps.googleusercontent.com');
      expect(parsed.clientSecret, 'public-desktop-secret');
    });

    test('funciona quando o cliente Desktop não tem secret', () {
      const raw = '''{"installed":{"client_id":"123-a.apps.googleusercontent.com"}}''';
      expect(DesktopOAuthConfiguration.fromGoogleJson(raw).clientSecret, '');
    });

    test('não aceita um JSON do tipo Web para login Desktop', () {
      const raw = '''{"web":{"client_id":"123-a.apps.googleusercontent.com"}}''';
      expect(() => DesktopOAuthConfiguration.fromGoogleJson(raw), throwsFormatException);
    });

    test('rejeita client ID inesperado', () {
      const raw = '''{"installed":{"client_id":"https://example.com/falso"}}''';
      expect(() => DesktopOAuthConfiguration.fromGoogleJson(raw), throwsFormatException);
    });

    test('lê JSON OAuth Web sem digitar o Client ID', () {
      const web = '''{"web":{"client_id":"12345-abcd.apps.googleusercontent.com"}}''';
      expect(WebOAuthConfiguration.fromGoogleJson(web),
        '12345-abcd.apps.googleusercontent.com');
    });

    test('não confunde credenciais Desktop com Web no Android', () {
      const installed = '''{"installed":{"client_id":"12345-abcd.apps.googleusercontent.com"}}''';
      expect(() => WebOAuthConfiguration.fromGoogleJson(installed), throwsFormatException);
    });

    test('limita tamanho do JSON importado', () {
      final raw = '''{"installed":{"client_id":"123-a.apps.googleusercontent.com","junk":"${List.filled(65536, 'x').join()}"}}''';
      expect(() => DesktopOAuthConfiguration.fromGoogleJson(raw), throwsFormatException);
    });
  });
}
