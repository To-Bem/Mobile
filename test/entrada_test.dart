import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import 'apoio/entrada_falsa.dart';

void main() {
  test('pergunta de novo até a resposta ser válida', () {
    final saida = <String>[];
    final entrada = entradaFalsa(['', 'ana@', 'ana@email.com'], saida);

    final email = entrada.perguntar('E-mail', validar: validarEmail);

    expect(email, 'ana@email.com');
    expect(saida.where((linha) => linha == 'E-mail: ').length, 3);
    expect(saida.where((linha) => linha.contains('[ERRO]')).length, 2);
  });

  test('remove espaços das pontas, mas não da senha', () {
    final entrada = entradaFalsa(['  Maria  ', ' 123456 '], []);

    expect(entrada.perguntar('Nome'), 'Maria');
    expect(entrada.perguntarSenha('Senha'), ' 123456 ');
  });

  test('sem mais entrada lança EntradaEncerradaException', () {
    final entrada = entradaFalsa([], []);

    expect(
      () => entrada.perguntar('Nome'),
      throwsA(isA<EntradaEncerradaException>()),
    );
  });

  test('escolherOpcao mostra o menu e insiste até ser válido', () {
    final saida = <String>[];
    final entrada = entradaFalsa(['x', '5', '2'], saida);

    final opcao = entrada.escolherOpcao(['Meus idosos', 'Alertas']);

    expect(opcao, 2);
    expect(saida, containsAll(['  1) Meus idosos', '  2) Alertas', '  0) Voltar']));
    expect(saida.where((linha) => linha.contains('[ERRO]')).length, 2);
  });

  test('pausar espera um Enter', () {
    final entrada = entradaFalsa([''], []);
    entrada.pausar();
    expect(() => entrada.pausar(), throwsA(isA<EntradaEncerradaException>()));
  });

  test('confirmar insiste até receber s ou n', () {
    final saida = <String>[];
    final entrada = entradaFalsa(['talvez', 's', 'nao'], saida);

    expect(entrada.confirmar('Confirmar?'), isTrue);
    expect(entrada.confirmar('Confirmar?'), isFalse);
    expect(saida, contains('Confirmar? (s/n): '));
    expect(saida.where((linha) => linha.contains('[ERRO]')).length, 1);
  });

  test('acento quebrado pelo terminal mostra como resolver', () {
    final saida = <String>[];
    final entrada = entradaFalsa(['Jo\uFFFDo', 'Joao'], saida);

    expect(entrada.perguntar('Nome'), 'Joao');
    expect(saida.any((linha) => linha.contains('chcp 65001')), isTrue);
  });
}
