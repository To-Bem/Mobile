// API falsa para testar a aplicação enquanto a API Java não fica pronta.
// Segue o formato de docs/contrato-api.md e cresce a cada camada.
//
// Uso (num terminal separado):
//   dart run tool/api_fake.dart
//
// Sobe em http://localhost:8080. Não rode junto com a API Java (mesma porta).
// Os dados ficam só na memória: reiniciar a API falsa volta tudo ao início.

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Usuários (fixos)
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

// ---------------------------------------------------------------------------
// Dados que mudam durante o uso (um conjunto novo por servidor)
// ---------------------------------------------------------------------------

class _DadosFalsos {
  /// Quais idosos cada usuário acompanha. O ADMIN vê todos.
  final Map<int, List<int>> vinculos = {
    1: [1, 2, 3], // Ana (FAMILIAR)
    2: [3, 4], // Carlos (CUIDADOR)
  };

  int _proximoIdoso = 5;
  int _proximoContato = 7;

  int novoIdIdoso() => _proximoIdoso++;
  int novoIdContato() => _proximoContato++;

  final List<Map<String, Object?>> contatos = [
    _contato(1, 1, 'Ana Souza', '11999990001', 'Filha', 1, usuarioId: 1),
    _contato(2, 1, 'Rosa Pereira', '11999990002', 'Vizinha', 2),
    _contato(3, 2, 'Ana Souza', '11999990001', 'Sobrinha', 1, usuarioId: 1),
    _contato(4, 3, 'Ana Souza', '11999990001', 'Filha', 1, usuarioId: 1),
    _contato(5, 3, 'Carlos Lima', '11999990003', 'Cuidador', 2, usuarioId: 2),
    _contato(6, 4, 'Carlos Lima', '11999990003', 'Cuidador', 1, usuarioId: 2),
  ];

  final List<_IdosoFalso> idosos = [
    _IdosoFalso(
      id: 1,
      nome: 'Dona Maria',
      nascimento: '1948-03-12',
      telefone: '11988887777',
      endereco: 'Rua das Flores, 120 - Vila Mariana',
      minutosSemAtividade: 23,
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
      minutosSemAtividade: 130,
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
      minutosSemAtividade: 175,
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
      modo: 'AUSENTE',
      minutosSemAtividade: 1500,
      temperatura: 24,
      umidade: 65,
      eventos: const [_EventoFalso(1500, 'BOTAO_SAIU', 'Sala')],
    ),
  ];

  final List<_AlertaFalso> alertas = [
    _AlertaFalso(
      id: 1,
      idosoId: 3,
      tipo: 'PESSOA_PARADA',
      descricao: 'Sem movimento no banheiro há mais de 40 min',
      nivel: 'CRITICO',
      minutosAtras: 170,
      status: 'ESCALONADO',
      etapaEscalonamento: 2,
    ),
    _AlertaFalso(
      id: 2,
      idosoId: 3,
      tipo: 'CALOR',
      descricao: 'Temperatura de 33,5 °C dentro de casa',
      nivel: 'ATENCAO',
      minutosAtras: 255,
    ),
    _AlertaFalso(
      id: 3,
      idosoId: 2,
      tipo: 'SEM_ATIVIDADE',
      descricao: 'Sem movimento há mais de 2 h, fora da rotina',
      nivel: 'ATENCAO',
      minutosAtras: 10,
    ),
    _AlertaFalso(
      id: 4,
      idosoId: 1,
      tipo: 'LEVANTADAS_NOTURNAS',
      descricao: 'Levantou 5 vezes durante a madrugada (média: 2)',
      nivel: 'ALERTA',
      minutosAtras: 1300,
      status: 'RESOLVIDO',
      resolvidoEm: _ha(1250),
    ),
    _AlertaFalso(
      id: 5,
      idosoId: 4,
      tipo: 'DISPOSITIVO_OFFLINE',
      descricao: 'A lâmpada ficou sem sinal por 35 min',
      nivel: 'ALERTA',
      minutosAtras: 2900,
      status: 'RESOLVIDO',
      resolvidoEm: _ha(2850),
    ),
  ];

  _IdosoFalso? idosoPorId(int id) {
    for (final idoso in idosos) {
      if (idoso.id == id) return idoso;
    }
    return null;
  }

  List<_AlertaFalso> abertosDe(int idosoId) => alertas
      .where((alerta) => alerta.idosoId == idosoId && alerta.estaAberto)
      .toList();

  /// Status do idoso = nível do pior alerta aberto.
  /// Sem alertas: OK, ou OFFLINE se o dispositivo nunca mandou sinal.
  String statusDe(_IdosoFalso idoso) {
    final idosoId = idoso.id;
    var pior = idoso.minutosSemAtividade == null ? 'OFFLINE' : 'OK';
    var gravidadePior = 0;
    for (final alerta in abertosDe(idosoId)) {
      final gravidade = _gravidade[alerta.nivel] ?? 0;
      if (gravidade > gravidadePior) {
        pior = alerta.nivel;
        gravidadePior = gravidade;
      }
    }
    return pior;
  }

  Map<String, Object?> idosoJson(_IdosoFalso idoso) => {
    'id': idoso.id,
    'nome': idoso.nome,
    'dataNascimento': idoso.nascimento,
    'telefone': idoso.telefone,
    'endereco': idoso.endereco,
    'modo': idoso.modo,
    'status': statusDe(idoso),
    'ultimaAtividade': idoso.minutosSemAtividade == null
        ? null
        : _dataJava(_ha(idoso.minutosSemAtividade!)),
    'alertasAbertos': abertosDe(idoso.id).length,
    '_links': {
      'self': {'href': '/idosos/${idoso.id}'},
      'painel': {'href': '/idosos/${idoso.id}/painel'},
      'alertas': {'href': '/alertas?idosoId=${idoso.id}'},
      'contatos': {'href': '/idosos/${idoso.id}/contatos'},
      'modo': {'href': '/idosos/${idoso.id}/modo'},
    },
  };

  Map<String, Object?> painelJson(_IdosoFalso idoso) => {
    'idoso': idosoJson(idoso),
    'temperatura': idoso.temperatura,
    'umidade': idoso.umidade,
    'eventosHoje': [
      for (var i = 0; i < idoso.eventos.length; i++)
        idoso.eventos[i].toJson(idoso.id * 100 + i),
    ],
  };

  Map<String, Object?> alertaJson(_AlertaFalso alerta) {
    final resolvidoEm = alerta.resolvidoEm;
    return {
      'id': alerta.id,
      'idosoId': alerta.idosoId,
      'idosoNome': idosoPorId(alerta.idosoId)?.nome ?? '',
      'tipo': alerta.tipo,
      'descricao': alerta.descricao,
      'nivel': alerta.nivel,
      'status': alerta.status,
      'nivelEscalonamento': alerta.etapaEscalonamento,
      'criadoEm': _dataJava(_ha(alerta.minutosAtras)),
      'resolvidoEm': resolvidoEm == null ? null : _dataJava(resolvidoEm),
      '_links': {
        'self': {'href': '/alertas/${alerta.id}'},
        'idoso': {'href': '/idosos/${alerta.idosoId}'},
        if (alerta.estaAberto)
          'confirmar': {'href': '/alertas/${alerta.id}/confirmar'},
      },
    };
  }
}

const Map<String, int> _gravidade = {'ATENCAO': 1, 'ALERTA': 2, 'CRITICO': 3};

class _IdosoFalso {
  _IdosoFalso({
    required this.id,
    required this.nome,
    required this.nascimento,
    required this.telefone,
    required this.endereco,
    this.minutosSemAtividade,
    this.temperatura,
    this.umidade,
    this.eventos = const [],
    this.modo = 'NORMAL',
  });

  final int id;
  final String nome;
  final String nascimento;
  final String telefone;
  final String endereco;

  /// null = dispositivo ainda não mandou nenhum sinal (idoso recém-cadastrado).
  final int? minutosSemAtividade;
  final double? temperatura;
  final int? umidade;
  final List<_EventoFalso> eventos;

  /// Muda com a chave "fora de casa".
  String modo;
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
    'dataHora': _dataJava(_ha(minutosAtras)),
    'comodo': comodo,
  };
}

class _AlertaFalso {
  _AlertaFalso({
    required this.id,
    required this.idosoId,
    required this.tipo,
    required this.descricao,
    required this.nivel,
    required this.minutosAtras,
    this.status = 'ABERTO',
    this.etapaEscalonamento = 1,
    this.resolvidoEm,
  });

  final int id;
  final int idosoId;
  final String tipo;
  final String descricao;
  final String nivel;
  final int minutosAtras;

  // Mudam quando o alerta é confirmado.
  String status;
  int etapaEscalonamento;
  DateTime? resolvidoEm;

  bool get estaAberto => status != 'RESOLVIDO';
}

Map<String, Object?> _contato(
  int id,
  int idosoId,
  String nome,
  String telefone,
  String parentesco,
  int ordem, {
  int? usuarioId,
}) => {
  'id': id,
  'idosoId': idosoId,
  'usuarioId': usuarioId,
  'nome': nome,
  'telefone': telefone,
  'parentesco': parentesco,
  'ordemEscalonamento': ordem,
};

/// Os horários são relativos ao momento da consulta ("há 23 min"),
/// para a demonstração parecer sempre atual.
DateTime _ha(int minutos) =>
    DateTime.now().subtract(Duration(minutes: minutos));

/// LocalDateTime do Java, sem fuso: "2026-11-06T09:40:00".
String _dataJava(DateTime data) => data.toIso8601String().substring(0, 19);

// ---------------------------------------------------------------------------
// Servidor
// ---------------------------------------------------------------------------

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

/// Sobe a API falsa com dados novos.
/// Use [porta] 0 para uma porta livre qualquer (nos testes).
Future<HttpServer> iniciarApiFalsa({
  int porta = 8080,
  bool registrarLog = true,
}) async {
  final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, porta);
  final dados = _DadosFalsos();
  servidor.listen((requisicao) => _responder(requisicao, dados, registrarLog));
  return servidor;
}

final RegExp _rotaPainel = RegExp(r'^GET /idosos/(\d+)/painel$');
final RegExp _rotaConfirmar = RegExp(r'^PATCH /alertas/(\d+)/confirmar$');
final RegExp _rotaModo = RegExp(r'^PATCH /idosos/(\d+)/modo$');
final RegExp _rotaContatos = RegExp(r'^(GET|POST) /idosos/(\d+)/contatos$');

Future<void> _responder(
  HttpRequest requisicao,
  _DadosFalsos dados,
  bool registrarLog,
) async {
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
      await _erro(requisicao, 401, 'Faça login para continuar.');
      return;
    }
    final visiveis = _idososVisiveis(dados, usuario);

    if (rota == 'GET /idosos') {
      await _responderJson(requisicao, 200, {
        '_embedded': {
          'idosos': [for (final idoso in visiveis) dados.idosoJson(idoso)],
        },
        '_links': {
          'self': {'href': '/idosos'},
        },
      });
      return;
    }

    if (rota == 'POST /idosos') {
      await _cadastrarIdoso(requisicao, dados, usuario, corpo);
      return;
    }

    final modo = _rotaModo.firstMatch(rota);
    if (modo != null) {
      final idoso = _buscar(visiveis, int.parse(modo.group(1)!));
      await _alterarModo(requisicao, dados, idoso, corpo);
      return;
    }

    final contatos = _rotaContatos.firstMatch(rota);
    if (contatos != null) {
      final idoso = _buscar(visiveis, int.parse(contatos.group(2)!));
      if (contatos.group(1) == 'GET') {
        await _listarContatos(requisicao, dados, idoso);
      } else {
        await _cadastrarContato(requisicao, dados, idoso, corpo);
      }
      return;
    }

    final painel = _rotaPainel.firstMatch(rota);
    if (painel != null) {
      final id = int.parse(painel.group(1)!);
      final idoso = _buscar(visiveis, id);
      if (idoso == null) {
        await _erro(requisicao, 404, 'Idoso não encontrado.');
      } else {
        await _responderJson(requisicao, 200, dados.painelJson(idoso));
      }
      return;
    }

    if (rota == 'GET /alertas') {
      await _listarAlertas(requisicao, dados, visiveis);
      return;
    }

    final confirmar = _rotaConfirmar.firstMatch(rota);
    if (confirmar != null) {
      final id = int.parse(confirmar.group(1)!);
      await _confirmarAlerta(requisicao, dados, visiveis, id);
      return;
    }

    await _erro(requisicao, 404, 'Rota ainda não existe na API falsa: $rota');
  } on Object catch (erro) {
    await _erro(requisicao, 500, 'Erro na API falsa: $erro');
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
  return _erro(requisicao, 401, 'E-mail ou senha inválidos.');
}

/// GET /alertas?status=&nivel=&idosoId= — mais recentes primeiro.
Future<void> _listarAlertas(
  HttpRequest requisicao,
  _DadosFalsos dados,
  List<_IdosoFalso> visiveis,
) {
  final filtros = requisicao.uri.queryParameters;
  final idsVisiveis = visiveis.map((idoso) => idoso.id).toSet();
  final idosoId = int.tryParse(filtros['idosoId'] ?? '');

  final alertas = dados.alertas.where((alerta) {
    if (!idsVisiveis.contains(alerta.idosoId)) return false;
    if (idosoId != null && alerta.idosoId != idosoId) return false;
    final status = filtros['status'];
    if (status != null && alerta.status != status) return false;
    final nivel = filtros['nivel'];
    if (nivel != null && alerta.nivel != nivel) return false;
    return true;
  }).toList()..sort((a, b) => a.minutosAtras.compareTo(b.minutosAtras));

  return _responderJson(requisicao, 200, {
    '_embedded': {
      'alertas': [for (final alerta in alertas) dados.alertaJson(alerta)],
    },
    '_links': {
      'self': {'href': '/alertas'},
    },
  });
}

/// PATCH /alertas/{id}/confirmar — encerra o alerta e para o escalonamento.
Future<void> _confirmarAlerta(
  HttpRequest requisicao,
  _DadosFalsos dados,
  List<_IdosoFalso> visiveis,
  int alertaId,
) {
  final idsVisiveis = visiveis.map((idoso) => idoso.id).toSet();
  for (final alerta in dados.alertas) {
    if (alerta.id != alertaId || !idsVisiveis.contains(alerta.idosoId)) {
      continue;
    }
    if (!alerta.estaAberto) {
      return _erro(requisicao, 409, 'Este alerta já foi confirmado.');
    }
    alerta
      ..status = 'RESOLVIDO'
      ..resolvidoEm = DateTime.now();
    return _responderJson(requisicao, 200, dados.alertaJson(alerta));
  }
  return _erro(requisicao, 404, 'Alerta não encontrado.');
}

/// POST /idosos — o FAMILIAR que cadastra passa a acompanhar o idoso.
Future<void> _cadastrarIdoso(
  HttpRequest requisicao,
  _DadosFalsos dados,
  Map<String, Object> usuario,
  Map<String, dynamic> corpo,
) {
  if (usuario['papel'] == 'CUIDADOR') {
    return _erro(requisicao, 403, 'Cuidadores não podem cadastrar idosos.');
  }

  final nome = _texto(corpo['nome']);
  final nascimento = DateTime.tryParse(_texto(corpo['dataNascimento']));
  final telefone = _texto(corpo['telefone']).replaceAll(RegExp(r'\D'), '');
  final endereco = _texto(corpo['endereco']);

  final campos = <String, String>{
    if (nome.isEmpty) 'nome': 'obrigatório',
    if (nascimento == null) 'dataNascimento': 'data inválida (use aaaa-mm-dd)',
    if (telefone.length < 10 || telefone.length > 11)
      'telefone': 'use DDD + número',
    if (endereco.isEmpty) 'endereco': 'obrigatório',
  };
  if (campos.isNotEmpty) {
    return _erro(requisicao, 400, 'Dados inválidos.', campos);
  }

  final idoso = _IdosoFalso(
    id: dados.novoIdIdoso(),
    nome: nome,
    nascimento: _texto(corpo['dataNascimento']),
    telefone: telefone,
    endereco: endereco,
  );
  dados.idosos.add(idoso);
  if (usuario['papel'] == 'FAMILIAR') {
    (dados.vinculos[usuario['id'] as int] ??= []).add(idoso.id);
  }
  return _responderJson(requisicao, 201, dados.idosoJson(idoso));
}

/// PATCH /idosos/{id}/modo — {"modo": "AUSENTE"} ou {"modo": "NORMAL"}.
Future<void> _alterarModo(
  HttpRequest requisicao,
  _DadosFalsos dados,
  _IdosoFalso? idoso,
  Map<String, dynamic> corpo,
) {
  if (idoso == null) return _erro(requisicao, 404, 'Idoso não encontrado.');

  final modo = _texto(corpo['modo']);
  if (modo != 'NORMAL' && modo != 'AUSENTE') {
    return _erro(requisicao, 400, 'Dados inválidos.', {
      'modo': 'use NORMAL ou AUSENTE',
    });
  }
  idoso.modo = modo;
  return _responderJson(requisicao, 200, dados.idosoJson(idoso));
}

/// GET /idosos/{id}/contatos
Future<void> _listarContatos(
  HttpRequest requisicao,
  _DadosFalsos dados,
  _IdosoFalso? idoso,
) {
  if (idoso == null) return _erro(requisicao, 404, 'Idoso não encontrado.');
  return _responderJson(requisicao, 200, {
    '_embedded': {
      'contatos': [
        for (final contato in dados.contatos)
          if (contato['idosoId'] == idoso.id) contato,
      ],
    },
  });
}

/// POST /idosos/{id}/contatos
Future<void> _cadastrarContato(
  HttpRequest requisicao,
  _DadosFalsos dados,
  _IdosoFalso? idoso,
  Map<String, dynamic> corpo,
) {
  if (idoso == null) return _erro(requisicao, 404, 'Idoso não encontrado.');

  final nome = _texto(corpo['nome']);
  final telefone = _texto(corpo['telefone']).replaceAll(RegExp(r'\D'), '');
  final parentesco = _texto(corpo['parentesco']);
  final ordem = corpo['ordemEscalonamento'];

  final campos = <String, String>{
    if (nome.isEmpty) 'nome': 'obrigatório',
    if (telefone.length < 10 || telefone.length > 11)
      'telefone': 'use DDD + número',
    if (parentesco.isEmpty) 'parentesco': 'obrigatório',
    if (ordem is! int || ordem < 1 || ordem > 5)
      'ordemEscalonamento': 'use um número de 1 a 5',
  };
  if (campos.isNotEmpty) {
    return _erro(requisicao, 400, 'Dados inválidos.', campos);
  }

  final contato = _contato(
    dados.novoIdContato(),
    idoso.id,
    nome,
    telefone,
    parentesco,
    ordem as int,
    usuarioId: corpo['usuarioId'] is int ? corpo['usuarioId'] as int : null,
  );
  dados.contatos.add(contato);
  return _responderJson(requisicao, 201, contato);
}

// ---------------------------------------------------------------------------
// Apoio
// ---------------------------------------------------------------------------

String _texto(Object? valor) => valor is String ? valor.trim() : '';

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

List<_IdosoFalso> _idososVisiveis(
  _DadosFalsos dados,
  Map<String, Object> usuario,
) {
  if (usuario['papel'] == 'ADMIN') return dados.idosos;
  final ids = dados.vinculos[usuario['id']] ?? const <int>[];
  return dados.idosos.where((idoso) => ids.contains(idoso.id)).toList();
}

_IdosoFalso? _buscar(List<_IdosoFalso> idosos, int id) {
  for (final idoso in idosos) {
    if (idoso.id == id) return idoso;
  }
  return null;
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

Future<void> _erro(
  HttpRequest requisicao,
  int status,
  String mensagem, [
  Map<String, String>? campos,
]) {
  final corpo = <String, Object>{'status': status, 'mensagem': mensagem};
  if (campos != null) corpo['campos'] = campos;
  return _responderJson(requisicao, status, corpo);
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
