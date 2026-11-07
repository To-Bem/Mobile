// Simula o sensor (a lâmpada) para a demonstração ao vivo.
// Cria situações na API falsa, que o monitoramento detecta na próxima consulta.
//
// Uso (com a API falsa rodando):
//   dart run tool/simular.dart <acao> <id do idoso>
//
// Ações:
//   queda   cria um alerta CRÍTICO de pessoa parada
//   calor   cria um alerta de ATENÇÃO de calor dentro de casa
//   saiu    marca o idoso como fora de casa
//   voltou  marca o idoso como em casa
//
// Idosos: 1 Dona Maria · 2 Seu João · 3 Dona Lurdes · 4 Seu Antônio
//
// Exemplo: dart run tool/simular.dart queda 1

import 'dart:convert';
import 'dart:io';

const List<String> _acoes = ['queda', 'calor', 'saiu', 'voltou'];

Future<void> main(List<String> argumentos) async {
  if (argumentos.length != 2 ||
      !_acoes.contains(argumentos[0]) ||
      int.tryParse(argumentos[1]) == null) {
    stderr.writeln('Uso: dart run tool/simular.dart '
        '<${_acoes.join('|')}> <id do idoso>');
    stderr.writeln('Exemplo: dart run tool/simular.dart queda 1');
    exitCode = 64;
    return;
  }

  final porta = Platform.environment['PORTA_API_FALSA'] ?? '8080';
  final uri = Uri.parse(
    'http://localhost:$porta/simulador/${argumentos[0]}/${argumentos[1]}',
  );
  final cliente = HttpClient();

  try {
    final requisicao = await cliente.postUrl(uri);
    final resposta = await requisicao.close();
    final texto = await resposta.transform(utf8.decoder).join();
    final mensagem = _mensagem(texto);

    if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
      stdout.writeln('OK: $mensagem');
    } else {
      stderr.writeln('Erro ${resposta.statusCode}: $mensagem');
      exitCode = 1;
    }
  } on SocketException {
    stderr.writeln('A API falsa não está rodando em $uri');
    stderr.writeln('Rode antes, em outro terminal: dart run tool/api_fake.dart');
    exitCode = 1;
  } finally {
    cliente.close();
  }
}

String _mensagem(String texto) {
  try {
    final json = jsonDecode(texto);
    if (json is Map && json['mensagem'] is String) {
      return json['mensagem'] as String;
    }
  } on FormatException {
    // Resposta não é JSON: mostra o texto como veio.
  }
  return texto;
}
