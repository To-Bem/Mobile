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

  group('validarNome', () {
    test('aceita nomes com acento, apóstrofo e hífen', () {
      expect(validarNome('José da Silva'), isNull);
      expect(validarNome("Maria D'Ávila"), isNull);
      expect(validarNome('Ana-Júlia Souza'), isNull);
    });

    test('recusa vazio, curto e com números', () {
      expect(validarNome(''), 'Nome: preenchimento obrigatório.');
      expect(validarNome('Jo'), contains('muito curto'));
      expect(validarNome('A B'), contains('muito curto'));
      expect(validarNome('Ana123'), 'Use só letras e espaços no nome.');
    });
  });

  group('converterDataBr', () {
    test('converte datas válidas', () {
      expect(converterDataBr('12/03/1948'), DateTime(1948, 3, 12));
      expect(converterDataBr('29/02/1952'), DateTime(1952, 2, 29));
    });

    test('devolve null para formato errado ou data inexistente', () {
      expect(converterDataBr('31/02/1950'), isNull);
      expect(converterDataBr('29/02/1951'), isNull);
      expect(converterDataBr('1950-03-12'), isNull);
      expect(converterDataBr('1/3/1950'), isNull);
    });
  });

  group('validarDataNascimento', () {
    final hoje = DateTime(2026, 11, 7);

    test('aceita a partir de 60 anos completos', () {
      expect(validarDataNascimento('12/03/1948', hoje: hoje), isNull);
      expect(validarDataNascimento('07/11/1966', hoje: hoje), isNull);
    });

    test('recusa quem ainda não tem 60 anos', () {
      expect(
        validarDataNascimento('08/11/1966', hoje: hoje),
        contains('60 anos ou mais (esta pessoa tem 59)'),
      );
    });

    test('recusa data inválida, futura ou idade acima de 120', () {
      expect(validarDataNascimento('abc', hoje: hoje), contains('inválida'));
      expect(validarDataNascimento('01/01/2030', hoje: hoje),
          contains('futuro'));
      expect(validarDataNascimento('01/01/1890', hoje: hoje),
          contains('120 anos'));
      expect(validarDataNascimento('', hoje: hoje), contains('obrigatório'));
    });
  });

  test('calcularIdade considera se já fez aniversário', () {
    final hoje = DateTime(2026, 11, 7);
    expect(calcularIdade(DateTime(1966, 11, 7), hoje), 60);
    expect(calcularIdade(DateTime(1966, 11, 8), hoje), 59);
  });

  group('validarTelefone', () {
    test('aceita celular e fixo, com ou sem pontuação', () {
      expect(validarTelefone('(11) 98888-7777'), isNull);
      expect(validarTelefone('11988887777'), isNull);
      expect(validarTelefone('1133334444'), isNull);
    });

    test('recusa telefones inválidos', () {
      expect(validarTelefone('123'), contains('Telefone inválido'));
      expect(validarTelefone('0988887777'), 'DDD inválido.');
      expect(validarTelefone('11888877771'), contains('9 depois do DDD'));
      expect(validarTelefone(''), contains('obrigatório'));
    });

    test('somenteDigitos', () {
      expect(somenteDigitos('(11) 98888-7777'), '11988887777');
    });
  });

  group('validarEndereco', () {
    test('precisa de rua e número (ou s/n)', () {
      expect(validarEndereco('Rua das Acácias, 77'), isNull);
      expect(validarEndereco('Estrada Velha, S/N'), isNull);
      expect(validarEndereco('Rua'), contains('muito curto'));
      expect(validarEndereco('Rua das Acácias'), contains('número da casa'));
    });
  });

  group('validarOrdemEscalonamento', () {
    test('de 1 a 5', () {
      expect(validarOrdemEscalonamento('1'), isNull);
      expect(validarOrdemEscalonamento('5'), isNull);
      expect(validarOrdemEscalonamento('0'), isNotNull);
      expect(validarOrdemEscalonamento('6'), isNotNull);
      expect(validarOrdemEscalonamento('x'), isNotNull);
    });
  });

  test('validarNumeroEntre', () {
    expect(validarNumeroEntre('1', 1, 30), isNull);
    expect(validarNumeroEntre('30', 1, 30), isNull);
    expect(validarNumeroEntre('0', 1, 30), 'Digite um número de 1 a 30.');
    expect(validarNumeroEntre('31', 1, 30), isNotNull);
    expect(validarNumeroEntre('dois', 1, 30), isNotNull);
  });
}
