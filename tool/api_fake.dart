// API falsa para testar a aplicação enquanto a API Java não fica pronta.
// Segue o formato de docs/contrato-api.md e cresce a cada camada.
//
// Uso (num terminal separado):
//   dart run tool/api_fake.dart
//
// Sobe em http://localhost:8080. Não rode junto com a API Java (mesma porta).

import 'dart:convert';
import 'dart:io';

const List<Map<String, Object>> _usuarios = [
  {
    'id': 1,
    'nome': 'Ana Souza',
    'email': 'ana@email.com',
    'senha': '123456',
    'papel': 'FAMILIAR',
  },
  {
    'id': 2,
    'nome': 'Carlos Lima',
    'email': 'carlos@email.com',
    'senha': '123456',
    'papel': 'CUIDADOR',
  },
  {
    'id': 3,
    'nome': 'Administrador',
    'email': 'admin@email.com',
    'senha': 'admin123',
    'papel': 'ADMIN',
  },
];

Future<void> main() async {
  final porta =
      int.tryParse(Platform.environment['PORTA_API_FALSA'] ?? '') ?? 8080;
  await iniciarApiFalsa(porta: porta);

  stdout.writeln(
    'API falsa rodando em http://localhost:$porta (Ctrl+C para parar)',
  );
  stdout.writeln('Usuários de teste:');
  for (final usuario in _usuarios) {
    stdout.writeln(
      '  ${usuario['email']} / ${usuario['senha']} '
      '(${usuario['papel']})',
    );
  }
}

/// Sobe a API falsa. Use [porta] 0 para uma porta livre qualquer (nos testes).
Future<HttpServer> iniciarApiFalsa({
  int porta = 8080,
  bool registrarLog = true,
}) async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, porta);
  servidor.listen((requisicao) => _responder(requisicao, registrarLog));
  return servidor;
}

Future<void> _responder(HttpRequest requisicao, bool registrarLog) async {
  final rota = '${requisicao.method} ${requisicao.uri.path}';
  if (registrarLog) {
    final hora = DateTime.now().toIso8601String().substring(11, 19);
    stdout.writeln('$hora  $rota');
  }

  try {
    final corpo = _lerJson(await utf8.decoder.bind(requisicao).join());

    if (rota == 'POST /auth/login') {
      await _login(requisicao, corpo);
      return;
    }

    await _responderJson(requisicao, 404, {
      'status': 404,
      'mensagem': 'Rota ainda não existe na API falsa: $rota',
    });
  } on Object catch (erro) {
    await _responderJson(requisicao, 500, {
      'status': 500,
      'mensagem': 'Erro na API falsa: $erro',
    });
  }
}

Future<void> _login(HttpRequest requisicao, Map<String, dynamic> corpo) {
  for (final usuario in _usuarios) {
    if (usuario['email'] == corpo['email'] &&
        usuario['senha'] == corpo['senha']) {
      final semSenha = Map.of(usuario)..remove('senha');
      return _responderJson(requisicao, 200, {
        'token': 'token-falso-${usuario['id']}',
        'usuario': semSenha,
      });
    }
  }
  return _responderJson(requisicao, 401, {
    'status': 401,
    'mensagem': 'E-mail ou senha inválidos.',
  });
}

Map<String, dynamic> _lerJson(String texto) {
  if (texto.trim().isEmpty) return {};
  try {
    final json = jsonDecode(texto);
    return json is Map<String, dynamic> ? json : {};
  } on FormatException {
    return {};
  }
}

Future<void> _responderJson(
  HttpRequest requisicao,
  int status,
  Object corpo,
) async {
  requisicao.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(corpo));
  await requisicao.response.close();
}
