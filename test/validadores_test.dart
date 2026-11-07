import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

void main() {
  group('validarObrigatorio', () {
    test('vazio ou só espaços é erro', () {
      expect(validarObrigatorio(''), isNotNull);
      expect(validarObrigatorio('   ', 'Nome'), 'Nome: preenchimento obrigatório.');
      expect(validarObrigatorio(null), isNotNull);
    });

    test('com texto passa', () {
      expect(validarObrigatorio('Maria'), isNull);
    });
  });

  group('validarEmail', () {
    test('aceita e-mails válidos', () {
      expect(validarEmail('ana@email.com'), isNull);
      expect(validarEmail('ana.souza+fiap@email.com.br'), isNull);
    });

    test('recusa e-mails inválidos', () {
      expect(validarEmail(''), 'E-mail: preenchimento obrigatório.');
      expect(validarEmail('ana@'), isNotNull);
      expect(validarEmail('ana.email.com'), isNotNull);
      expect(validarEmail('ana@email'), isNotNull);
    });
  });

  group('validarSenha', () {
    test('mínimo de 6 caracteres', () {
      expect(validarSenha('12345'), isNotNull);
      expect(validarSenha('123456'), isNull);
    });

    test('vazia é erro', () {
      expect(validarSenha(''), 'Senha: preenchimento obrigatório.');
    });
  });
}
