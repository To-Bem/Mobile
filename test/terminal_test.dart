import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => Terminal.usarCores = false);

  test('sem cores devolve o texto puro', () {
    Terminal.usarCores = false;
    expect(Terminal.colorir('OK', Cor.verde), 'OK');
  });

  test('com cores envolve o texto no código ANSI', () {
    Terminal.usarCores = true;
    expect(Terminal.colorir('OK', Cor.verde), '\x1B[32mOK\x1B[0m');
  });

  test('etiqueta coloca o texto entre colchetes', () {
    Terminal.usarCores = false;
    expect(Terminal.etiqueta('ALERTA', Cor.vermelho), '[ ALERTA ]');
  });

  test('cabeçalho tem o título em maiúsculas entre duas linhas', () {
    final linhas = Terminal.cabecalho('Tô Bem', largura: 10).split('\n');
    expect(linhas, ['==========', '  TÔ BEM', '==========']);
  });

  test('a URL da API tem um valor padrão', () {
    expect(AppConfig.apiBaseUrl, startsWith('http'));
  });
}
