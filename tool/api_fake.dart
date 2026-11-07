// API falsa para testar a aplicação enquanto a API Java não fica pronta.
// Segue o formato de docs/contrato-api.md e cresce a cada camada.
//
// Uso (num terminal separado):
//   dart run tool/api_fake.dart
//
// Sobe em http://localhost:8080. Não rode junto com a API Java (mesma porta).

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Dados de exemplo
// ---------------------------------------------------------------------------

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

/// Quais idosos cada usuário acompanha. O ADMIN vê todos.
const Map<int, List<int>> _vinculos = {
  1: [1, 2, 3], // Ana (FAMILIAR)
  2: [3, 4], // Carlos (CUIDADOR)
};

/// Os horários são relativos ao momento da consulta ("há 23 min"),
/// para a demonstração parecer sempre atual.
final List<_IdosoFalso> _idosos = [
  _IdosoFalso(
    id: 1,
    nome: 'Dona Maria',
    nascimento: '1948-03-12',
    telefone: '11988887777',
    endereco: 'Rua das Flores, 120 - Vila Mariana',
    status: 'OK',
    minutosSemAtividade: 23,
    alertasAbertos: 0,
    temperatura: 26.5,
    umidade: 55,
    eventos: const [
      _EventoFalso(23, 'PRESENCA', 'Cozinha'),
      _EventoFalso(41, 'PORTA_GELADEIRA', 'Cozinha'),
      _EventoFalso(95, 'BOTAO_ESTOU_BEM', 'Sala'),
      _EventoFalso(180, 'PRESENCA', 'Corredor'),
      _EventoFalso(300, 'TEMPERATURA', 'Sala', 26.5),
      _EventoFalso(410, 'PRESENCA', 'Quarto'),
    ],
  ),
  _IdosoFalso(
    id: 2,
    nome: 'Seu João',
    nascimento: '1945-07-30',
    telefone: '1133334444',
    endereco: 'Av. Paulista, 900, apto 52 - Bela Vista',
    status: 'ATENCAO',
    minutosSemAtividade: 130,
    alertasAbertos: 1,
    temperatura: 30,
    umidade: 60,
    eventos: const [
      _EventoFalso(130, 'PRESENCA', 'Corredor'),
      _EventoFalso(205, 'PORTA_GELADEIRA', 'Cozinha'),
      _EventoFalso(290, 'PRESENCA', 'Banheiro'),
      _EventoFalso(360, 'HEARTBEAT', 'Sala'),
    ],
  ),
  _IdosoFalso(
    id: 3,
    nome: 'Dona Lurdes',
    nascimento: '1940-11-02',
    telefone: '11977776666',
    endereco: 'Rua Augusta, 45 - Consolação',
    status: 'CRITICO',
    minutosSemAtividade: 175,
    alertasAbertos: 2,
    temperatura: 33.5,
    umidade: 40,
    eventos: const [
      _EventoFalso(175, 'PESSOA_PARADA', 'Banheiro'),
      _EventoFalso(215, 'PRESENCA', 'Banheiro'),
      _EventoFalso(260, 'TEMPERATURA', 'Quarto', 33.5),
      _EventoFalso(400, 'PRESENCA', 'Quarto'),
    ],
  ),
  _IdosoFalso(
    id: 4,
    nome: 'Seu Antônio',
    nascimento: '1950-01-15',
    telefone: '11966665555',
    endereco: 'Rua Vergueiro, 2000 - Paraíso',
    status: 'OK',
    modo: 'AUSENTE',
    minutosSemAtividade: 1500,
    alertasAbertos: 0,
    temperatura: 24,
    umidade: 65,
    eventos: const [
      _EventoFalso(1500, 'BOTAO_SAIU', 'Sala'),
    ],
  ),
];

class _IdosoFalso {
  _IdosoFalso({
    required this.id,
    required this.nome,
    required this.nascimento,
    required this.telefone,
    required this.endereco,
    required this.status,
    required this.minutosSemAtividade,
    required this.alertasAbertos,
    required this.temperatura,
    required this.umidade,
    required this.eventos,
    this.modo = 'NORMAL',
  });

  final int id;
  final String nome;
  final String nascimento;
  final String telefone;
  final String endereco;
  final int minutosSemAtividade;
  final double temperatura;
  final int umidade;
  final List<_EventoFalso> eventos;

  // Mudam nas próximas camadas (confirmar alerta, modo ausente).
  String status;
  String modo;
  int alertasAbertos;

  Map<String, Object?> toJson() => {
        'id': id,
        'nome': nome,
        'dataNascimento': nascimento,
        'telefone': telefone,
        'endereco': endereco,
        'modo': modo,
        'status': status,
        'ultimaAtividade': _haMinutos(minutosSemAtividade),
        'alertasAbertos': alertasAbertos,
        '_links': {
          'self': {'href': '/idosos/$id'},
          'painel': {'href': '/idosos/$id/painel'},
        },
      };

  Map<String, Object?> painelJson() => {
        'idoso': toJson(),
        'temperatura': temperatura,
        'umidade': umidade,
        'eventosHoje': [
          for (var i = 0; i < eventos.length; i++)
            eventos[i].toJson(id * 100 + i),
        ],
      };
}

class _EventoFalso {
  const _EventoFalso(this.minutosAtras, this.tipo, this.comodo, [this.valor]);

  final int minutosAtras;
  final String tipo;
  final String comodo;
  final double? valor;

  Map<String, Object?> toJson(int id) => {
        'id': id,
        'tipo': tipo,
        'valor': valor,
        'dataHora': _haMinutos(minutosAtras),
        'comodo': comodo,
      };
}

/// LocalDateTime do Java, sem fuso: "2026-11-06T09:40:00".
String _haMinutos(int minutos) => DateTime.now()
    .subtract(Duration(minutes: minutos))
    .toIso8601String()
    .substring(0, 19);

// ---------------------------------------------------------------------------
// Servidor
// ---------------------------------------------------------------------------

Future<void> main() async {
  final porta =
      int.tryParse(Platform.environment['PORTA_API_FALSA'] ?? '') ?? 8080;
  await iniciarApiFalsa(porta: porta);

  stdout.writeln('API falsa rodando em http://localhost:$porta (Ctrl+C para parar)');
  stdout.writeln('Usuários de teste:');
  for (final usuario in _usuarios) {
    stdout.writeln('  ${usuario['email']} / ${usuario['senha']} '
        '(${usuario['papel']})');
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

final RegExp _rotaPainel = RegExp(r'^GET /idosos/(\d+)/painel$');

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

    final usuario = _usuarioDoToken(requisicao);
    if (usuario == null) {
      await _responderJson(requisicao, 401, {
        'status': 401,
        'mensagem': 'Faça login para continuar.',
      });
      return;
    }

    if (rota == 'GET /idosos') {
      await _listarIdosos(requisicao, usuario);
      return;
    }

    final painel = _rotaPainel.firstMatch(rota);
    if (painel != null) {
      await _painel(requisicao, usuario, int.parse(painel.group(1)!));
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

// ---------------------------------------------------------------------------
// Rotas
// ---------------------------------------------------------------------------

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

/// GET /idosos — no formato HATEOAS do Spring (_embedded + _links).
Future<void> _listarIdosos(HttpRequest requisicao, Map<String, Object> usuario) {
  return _responderJson(requisicao, 200, {
    '_embedded': {
      'idosos': [for (final idoso in _idososVisiveis(usuario)) idoso.toJson()],
    },
    '_links': {
      'self': {'href': '/idosos'},
    },
  });
}

/// GET /idosos/{id}/painel
Future<void> _painel(
  HttpRequest requisicao,
  Map<String, Object> usuario,
  int idosoId,
) {
  for (final idoso in _idososVisiveis(usuario)) {
    if (idoso.id == idosoId) {
      return _responderJson(requisicao, 200, idoso.painelJson());
    }
  }
  return _responderJson(requisicao, 404, {
    'status': 404,
    'mensagem': 'Idoso não encontrado.',
  });
}

// ---------------------------------------------------------------------------
// Apoio
// ---------------------------------------------------------------------------

/// O token falso tem o formato `token-falso-<id do usuário>`.
Map<String, Object>? _usuarioDoToken(HttpRequest requisicao) {
  const prefixo = 'Bearer token-falso-';
  final cabecalho =
      requisicao.headers.value(HttpHeaders.authorizationHeader) ?? '';
  if (!cabecalho.startsWith(prefixo)) return null;

  final id = int.tryParse(cabecalho.substring(prefixo.length));
  for (final usuario in _usuarios) {
    if (usuario['id'] == id) return usuario;
  }
  return null;
}

List<_IdosoFalso> _idososVisiveis(Map<String, Object> usuario) {
  if (usuario['papel'] == 'ADMIN') return _idosos;
  final ids = _vinculos[usuario['id']] ?? const <int>[];
  return _idosos.where((idoso) => ids.contains(idoso.id)).toList();
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
