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

  group('validarOpcao', () {
    test('aceita de 0 até o máximo', () {
      expect(validarOpcao('0', 3), isNull);
      expect(validarOpcao(' 3 ', 3), isNull);
    });

    test('recusa fora da faixa ou texto', () {
      expect(validarOpcao('4', 3), 'Digite um número de 0 a 3.');
      expect(validarOpcao('-1', 3), isNotNull);
      expect(validarOpcao('um', 3), isNotNull);
      expect(validarOpcao('', 3), isNotNull);
    });
  });

  group('validarSimNao', () {
    test('aceita sim e não em vários formatos', () {
      for (final resposta in ['s', 'S', 'sim', 'SIM', 'n', 'nao', 'Não']) {
        expect(validarSimNao(resposta), isNull, reason: resposta);
      }
    });

    test('recusa outras respostas', () {
      expect(validarSimNao('talvez'), 'Responda s (sim) ou n (não).');
      expect(validarSimNao(''), isNotNull);
    });

    test('respostaSim', () {
      expect(respostaSim('Sim'), isTrue);
      expect(respostaSim('n'), isFalse);
    });
  });
}
