// Imitação da API Java (to_bem_api), usada SÓ nos testes automatizados.
//
// O app em si sempre fala com a API Java de verdade (API_URL). Este servidor
// existe para os testes rodarem sem banco e sem a API no ar: ele responde
// nas mesmas rotas, com os mesmos JSONs, regras de permissão por perfil
// (ADMIN, MANAGER, MEMBER) e formatos de erro da API Java.

import 'dart:convert';
import 'dart:io';

String _dois(int numero) => numero.toString().padLeft(2, '0');

/// "17/11/2026 14:05:09", como o Java grava dataHora, criadoEm etc.
String dataHoraJava(DateTime momento) =>
    '${dataJava(momento)} ${_dois(momento.hour)}:${_dois(momento.minute)}:'
    '${_dois(momento.second)}';

/// "12/03/1948", como o Java grava dataNascimento.
String dataJava(DateTime data) =>
    '${_dois(data.day)}/${_dois(data.month)}/${data.year}';

class UsuarioFalso {
  UsuarioFalso(this.id, this.nome, this.email, this.senha, this.role,
      [this.papel]);

  final int id;
  final String nome;
  final String email;
  final String senha;
  final String role;
  final String? papel;

  bool get ehGestao => role == 'ADMIN' || role == 'MANAGER';

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'email': email,
    'papel': papel,
  };
}

class IdosoFalso {
  IdosoFalso(
    this.id,
    this.nome,
    this.dataNascimento,
    this.telefone,
    this.endereco,
    this.modo,
  );

  final int id;
  String nome;
  String dataNascimento;
  String telefone;
  String endereco;
  String modo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'dataNascimento': dataNascimento,
    'telefone': telefone,
    'endereco': endereco,
    'modo': modo,
  };
}

class ContatoFalso {
  ContatoFalso(this.id, this.usuarioId, this.idosoId, this.parentesco,
      this.ordemEscalonamento);

  final int id;
  final int usuarioId;
  final int idosoId;
  final String parentesco;
  final int ordemEscalonamento;

  Map<String, dynamic> toJson() => {
    'id': id,
    'parentesco': parentesco,
    'ordemEscalonamento': ordemEscalonamento,
    'usuarioId': usuarioId,
    'idosoId': idosoId,
  };
}

class DispositivoFalso {
  DispositivoFalso(this.id, this.idosoId, this.tipo, this.comodo, this.status,
      this.ultimoHeartbeat);

  final int id;
  final int idosoId;
  final String tipo;
  final String comodo;
  final String status;
  String ultimoHeartbeat;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo,
    'comodo': comodo,
    'status': status,
    'ultimoHeartbeat': ultimoHeartbeat,
    'idosoId': idosoId,
  };
}

class EventoFalso {
  EventoFalso(this.id, this.dispositivoId, this.tipo, this.valor, this.dataHora);

  final int id;
  final int dispositivoId;
  final String tipo;
  final int valor;
  final String dataHora;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo,
    'valor': valor,
    'dataHora': dataHora,
    'dispositivoId': dispositivoId,
  };
}

class AlertaFalso {
  AlertaFalso(this.id, this.idosoId, this.usuarioId, this.tipo, this.nivel,
      this.status, this.nivelEscalonamento, this.criadoEm);

  final int id;
  final int idosoId;
  final int usuarioId;
  String tipo;
  String nivel;
  String status;
  final int nivelEscalonamento;
  final String criadoEm;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo,
    'nivel': nivel,
    'status': status,
    'nivelEscalonamento': nivelEscalonamento,
    'criadoEm': criadoEm,
    'usuarioId': usuarioId,
    'idosoId': idosoId,
  };
}

class RotinaFalsa {
  RotinaFalsa(this.id, this.idosoId, this.diaSemana, this.hora, this.media);

  final int id;
  final int idosoId;
  final String diaSemana;
  final String hora;
  final int media;

  Map<String, dynamic> toJson() => {
    'id': id,
    'diaSemana': diaSemana,
    'horaPrimeiraAtividade': hora,
    'mediaLevantadasPorNoite': media,
    'idosoId': idosoId,
  };
}

/// Banco em memória da API falsa.
///
/// Usuários (senha Senha12345, exceto o admin):
///   1 admin@tobem.com / Admin@12345 (ADMIN)
///   2 ana@email.com (MEMBER)     — contato de Maria, João e Lurdes
///   3 carlos@email.com (MEMBER)  — contato de Lurdes (2º) e Antônio
///   4 gerente@email.com (MANAGER)
///
/// Situação calculada pelo app com estes dados:
///   1 Dona Maria   tudo bem  (lâmpada online, sem alerta aberto)
///   2 Seu João     atenção   (alerta INATIVIDADE aberto)
///   3 Dona Lurdes  crítico   (alerta QUEDA escalonado para o 2º contato)
///   4 Seu Antônio  sem sinal (base sem sinal há 3 horas, fora de casa)
class DadosJavaFalsos {
  DadosJavaFalsos(this.agora) {
    String ha(Duration tempo) => dataHoraJava(agora.subtract(tempo));

    usuarios.addAll([
      UsuarioFalso(1, 'Administrador', 'admin@tobem.com', 'Admin@12345',
          'ADMIN'),
      UsuarioFalso(2, 'Ana Souza', 'ana@email.com', 'Senha12345', 'MEMBER',
          'FAMILIAR'),
      UsuarioFalso(3, 'Carlos Lima', 'carlos@email.com', 'Senha12345',
          'MEMBER', 'CUIDADOR'),
      UsuarioFalso(4, 'Gerente Teste', 'gerente@email.com', 'Senha12345',
          'MANAGER', 'CUIDADOR'),
    ]);
    idosos.addAll([
      IdosoFalso(1, 'Dona Maria', '12/03/1948', '11988887777',
          'Rua das Flores, 120', 'NORMAL'),
      IdosoFalso(2, 'Seu João', '05/07/1944', '11977776666',
          'Avenida Brasil, 45', 'NORMAL'),
      IdosoFalso(3, 'Dona Lurdes', '20/11/1940', '11966665555',
          'Rua Aurora, 300', 'NORMAL'),
      IdosoFalso(4, 'Seu Antônio', '01/01/1950', '11955554444',
          'Rua do Sol, 12', 'AUSENTE'),
    ]);
    contatos.addAll([
      ContatoFalso(1, 2, 1, 'Filho(a)', 1),
      ContatoFalso(2, 2, 2, 'Neto(a)', 1),
      ContatoFalso(3, 2, 3, 'Filho(a)', 1),
      ContatoFalso(4, 3, 3, 'Cuidador(a)', 2),
      ContatoFalso(5, 3, 4, 'Cuidador(a)', 1),
    ]);
    dispositivos.addAll([
      DispositivoFalso(1, 1, 'LAMPADA', 'Sala', 'ONLINE',
          ha(const Duration(minutes: 1))),
      DispositivoFalso(2, 2, 'LAMPADA', 'Quarto', 'ONLINE',
          ha(const Duration(minutes: 1))),
      DispositivoFalso(3, 3, 'LAMPADA', 'Banheiro', 'ONLINE',
          ha(const Duration(minutes: 1))),
      DispositivoFalso(4, 4, 'BASE', 'Sala', 'ONLINE',
          ha(const Duration(hours: 3))),
    ]);
    eventos.addAll([
      EventoFalso(1, 1, 'MOVIMENTO', 1, ha(const Duration(minutes: 20))),
      EventoFalso(2, 1, 'TEMPERATURA', 27, ha(const Duration(minutes: 10))),
      EventoFalso(3, 2, 'MOVIMENTO', 1, ha(const Duration(hours: 2))),
      EventoFalso(4, 3, 'PRESENCA_PARADA', 1, ha(const Duration(minutes: 40))),
      EventoFalso(5, 3, 'ALERTA_QUEDA_N2', 1, ha(const Duration(minutes: 30))),
      EventoFalso(6, 4, 'BOTAO_AUSENTE', 1, ha(const Duration(hours: 3))),
    ]);
    alertas.addAll([
      AlertaFalso(1, 1, 2, 'TEMPERATURA_ALTA', 'ATENCAO', 'RESOLVIDO', 1,
          ha(const Duration(days: 1))),
      AlertaFalso(2, 2, 2, 'INATIVIDADE', 'ATENCAO', 'ABERTO', 1,
          ha(const Duration(hours: 1))),
      AlertaFalso(3, 3, 3, 'QUEDA', 'CRITICO', 'ESCALONADO', 2,
          ha(const Duration(minutes: 30))),
    ]);
    rotinas.add(RotinaFalsa(1, 1, 'TODOS', '07:00:00', 2));
  }

  final DateTime agora;
  final List<UsuarioFalso> usuarios = [];
  final List<IdosoFalso> idosos = [];
  final List<ContatoFalso> contatos = [];
  final List<DispositivoFalso> dispositivos = [];
  final List<EventoFalso> eventos = [];
  final List<AlertaFalso> alertas = [];
  final List<RotinaFalsa> rotinas = [];

  int _proximoId = 100;
  int proximoId() => _proximoId++;

  /// Atalho para os testes: abre um alerta novo para o idoso.
  AlertaFalso abrirAlerta(int idosoId, String tipo, String nivel) {
    final primeiro = contatos.where((c) => c.idosoId == idosoId).toList()
      ..sort((a, b) => a.ordemEscalonamento.compareTo(b.ordemEscalonamento));
    final alerta = AlertaFalso(proximoId(), idosoId, primeiro.first.usuarioId,
        tipo, nivel, 'ABERTO', 1, dataHoraJava(DateTime.now()));
    alertas.add(alerta);
    return alerta;
  }

  IdosoFalso? idoso(int id) {
    for (final idoso in idosos) {
      if (idoso.id == id) return idoso;
    }
    return null;
  }

  bool podeAcessarIdoso(UsuarioFalso usuario, int idosoId) =>
      usuario.ehGestao ||
      contatos.any((c) => c.idosoId == idosoId && c.usuarioId == usuario.id);
}

/// Servidor HTTP que imita a API Java. Sobe numa porta livre.
class ApiJavaFalsa {
  ApiJavaFalsa._(this._servidor, this.dados);

  final HttpServer _servidor;
  final DadosJavaFalsos dados;

  /// Rotas chamadas, ex.: "PUT /api/alertas/2".
  final List<String> rotasChamadas = [];

  String get url => 'http://127.0.0.1:${_servidor.port}';

  static Future<ApiJavaFalsa> iniciar({DateTime? agora}) async {
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final api = ApiJavaFalsa._(
      servidor,
      DadosJavaFalsos(agora ?? DateTime.now()),
    );
    servidor.listen(api._atender);
    return api;
  }

  Future<void> fechar() => _servidor.close(force: true);

  Future<void> _atender(HttpRequest requisicao) async {
    final metodo = requisicao.method;
    rotasChamadas.add('$metodo ${requisicao.uri.path}');

    final texto = await utf8.decoder.bind(requisicao).join();
    Object? corpo;
    if (texto.isNotEmpty) {
      try {
        corpo = jsonDecode(texto);
      } on FormatException {
        return _erro(requisicao, 400, 'Corpo da requisição inválido ou malformado');
      }
    }
    final json = corpo is Map<String, dynamic> ? corpo : <String, dynamic>{};
    final partes = requisicao.uri.pathSegments;
    final query = requisicao.uri.queryParameters;

    if (metodo == 'POST' && requisicao.uri.path == '/api/auth/login') {
      return _login(requisicao, json);
    }
    if (metodo == 'POST' && requisicao.uri.path == '/api/auth/register') {
      return _registrar(requisicao, json);
    }

    final usuario = _usuarioDoToken(requisicao);
    if (usuario == null) {
      return _erro(requisicao, 401,
          'Autenticação necessária: envie um token válido');
    }

    switch ((metodo, partes)) {
      case ('GET', ['api', 'auth', 'me']):
        return _json(requisicao, 200, usuario.toJson());

      case ('GET', ['api', 'idosos']):
        if (!usuario.ehGestao) return _semPermissao(requisicao);
        return _pagina(requisicao, [
          for (final idoso in dados.idosos) idoso.toJson(),
        ], query);

      case ('GET', ['api', 'idosos', final id]):
        final idoso = _idosoPermitido(requisicao, usuario, id);
        if (idoso == null) return;
        return _json(requisicao, 200, idoso.toJson());

      case ('GET', ['api', 'idosos', final id, 'withAll']):
        final idoso = _idosoPermitido(requisicao, usuario, id);
        if (idoso == null) return;
        return _json(requisicao, 200, _idosoComTudo(idoso));

      case ('GET', ['api', 'idosos', final id, 'withDispositivos']):
        final idoso = _idosoPermitido(requisicao, usuario, id);
        if (idoso == null) return;
        return _json(requisicao, 200, {
          ...idoso.toJson(),
          'dispositivos': [
            for (final d in dados.dispositivos)
              if (d.idosoId == idoso.id) d.toJson(),
          ],
        });

      case ('PUT', ['api', 'idosos', final id]):
        if (!usuario.ehGestao) return _semPermissao(requisicao);
        final idoso = _idosoPermitido(requisicao, usuario, id);
        if (idoso == null) return;
        return _atualizarIdoso(requisicao, idoso, json);

      case ('POST', ['api', 'idosos', final id, 'dispositivo']):
        final idoso = _idosoPermitido(requisicao, usuario, id);
        if (idoso == null) return;
        return _cadastrarDispositivo(requisicao, idoso, json);

      case ('POST', ['api', 'idosos', final id, 'rotina']):
        final idoso = _idosoPermitido(requisicao, usuario, id);
        if (idoso == null) return;
        return _cadastrarRotina(requisicao, idoso, json);

      case ('GET', ['api', 'usuarios', final id]):
        final alvo = _usuarioPermitido(requisicao, usuario, id);
        if (alvo == null) return;
        return _json(requisicao, 200, alvo.toJson());

      case ('GET', ['api', 'usuarios', final id, 'withContatos']):
        final alvo = _usuarioPermitido(requisicao, usuario, id);
        if (alvo == null) return;
        return _json(requisicao, 200, {
          ...alvo.toJson(),
          'contatos': [
            for (final c in dados.contatos)
              if (c.usuarioId == alvo.id) c.toJson(),
          ],
        });

      case ('POST', ['api', 'usuarios', final id, 'idoso']):
        final alvo = _usuarioPermitido(requisicao, usuario, id);
        if (alvo == null) return;
        return _cadastrarIdoso(requisicao, alvo, json, query);

      case ('GET', ['api', 'eventos', 'byOtherFilter']):
        return _eventosDoDispositivo(requisicao, usuario, query);

      case ('GET', ['api', 'alertas']):
        if (!usuario.ehGestao) return _semPermissao(requisicao);
        return _pagina(requisicao, [
          for (final alerta in dados.alertas) alerta.toJson(),
        ], query);

      case ('GET', ['api', 'alertas', 'byOtherFilter']):
        return _filtrarAlertas(requisicao, usuario, query);

      case ('PUT', ['api', 'alertas', final id]):
        return _atualizarAlerta(requisicao, usuario, id, json);
    }

    return _erro(requisicao, 404, 'Recurso nao encontrado.');
  }

  // ---------------------------------------------------------------------
  // Autenticação
  // ---------------------------------------------------------------------

  Future<void> _login(HttpRequest requisicao, Map<String, dynamic> json) {
    final email = _texto(json['email']).toLowerCase();
    final senha = _texto(json['password']);
    final erros = [
      if (email.isEmpty) ('email', 'email é obrigatório'),
      if (senha.isEmpty) ('password', 'password é obrigatório'),
    ];
    if (erros.isNotEmpty) return _errosDeCampo(requisicao, erros);

    for (final usuario in dados.usuarios) {
      if (usuario.email == email && usuario.senha == senha) {
        return _json(requisicao, 200, {
          'token': 'token-falso-${usuario.id}',
          'tokenType': 'Bearer',
          'expiresInSeconds': 3600,
          'email': usuario.email,
          'role': usuario.role,
        });
      }
    }
    return _erro(requisicao, 401, 'Credenciais inválidas');
  }

  Future<void> _registrar(HttpRequest requisicao, Map<String, dynamic> json) {
    final nome = _texto(json['name']);
    final email = _texto(json['email']).toLowerCase();
    final senha = _texto(json['password']);
    final erros = [
      if (nome.isEmpty) ('name', 'name é obrigatório'),
      if (!email.contains('@')) ('email', 'email inválido'),
      if (senha.length < 8 || senha.length > 72)
        ('password', 'password deve ter entre 8 e 72 caracteres'),
    ];
    if (erros.isNotEmpty) return _errosDeCampo(requisicao, erros);

    if (dados.usuarios.any((usuario) => usuario.email == email)) {
      return _erro(requisicao, 409,
          'Dados duplicados, obrigatorios ausentes ou registro vinculado a '
          'outro recurso.');
    }
    final novo = UsuarioFalso(dados.proximoId(), nome, email, senha, 'MEMBER');
    dados.usuarios.add(novo);
    return _json(requisicao, 201, novo.toJson());
  }

  UsuarioFalso? _usuarioDoToken(HttpRequest requisicao) {
    final cabecalho =
        requisicao.headers.value(HttpHeaders.authorizationHeader) ?? '';
    const prefixo = 'Bearer token-falso-';
    if (!cabecalho.startsWith(prefixo)) return null;
    final id = int.tryParse(cabecalho.substring(prefixo.length));
    for (final usuario in dados.usuarios) {
      if (usuario.id == id) return usuario;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Idosos, dispositivos e rotinas
  // ---------------------------------------------------------------------

  /// Como no Java: primeiro a permissão (403), depois a existência (404).
  IdosoFalso? _idosoPermitido(
    HttpRequest requisicao,
    UsuarioFalso usuario,
    String idTexto,
  ) {
    final id = int.tryParse(idTexto);
    if (id == null) {
      _erro(requisicao, 400, "Parâmetro 'id' inválido: $idTexto");
      return null;
    }
    if (!dados.podeAcessarIdoso(usuario, id)) {
      _semPermissao(requisicao);
      return null;
    }
    final idoso = dados.idoso(id);
    if (idoso == null) {
      _erro(requisicao, 404, 'idoso não encontrado com id $id');
      return null;
    }
    return idoso;
  }

  UsuarioFalso? _usuarioPermitido(
    HttpRequest requisicao,
    UsuarioFalso usuario,
    String idTexto,
  ) {
    final id = int.tryParse(idTexto);
    if (id == null || (!usuario.ehGestao && usuario.id != id)) {
      _semPermissao(requisicao);
      return null;
    }
    for (final alvo in dados.usuarios) {
      if (alvo.id == id) return alvo;
    }
    _erro(requisicao, 404, 'usuario não encontrado com id $id');
    return null;
  }

  Map<String, dynamic> _idosoComTudo(IdosoFalso idoso) => {
    ...idoso.toJson(),
    'contatos': [
      for (final c in dados.contatos)
        if (c.idosoId == idoso.id) c.toJson(),
    ],
    'alertas': [
      for (final a in dados.alertas)
        if (a.idosoId == idoso.id) a.toJson(),
    ],
    'rotinas': [
      for (final r in dados.rotinas)
        if (r.idosoId == idoso.id) r.toJson(),
    ],
    'dispositivos': [
      for (final d in dados.dispositivos)
        if (d.idosoId == idoso.id) d.toJson(),
    ],
  };

  /// Valida o IdosoRequest. Devolve a data no formato do Java ou null
  /// (quando já respondeu 400).
  String? _validarIdoso(HttpRequest requisicao, Map<String, dynamic> json) {
    final nascimento = DateTime.tryParse(_texto(json['dataNascimento']));
    final erros = [
      if (_texto(json['nome']).isEmpty) ('nome', 'nome não pode ser vazio'),
      if (nascimento == null)
        ('dataNascimento', 'dataNascimento é obrigatorio')
      else if (!nascimento.isBefore(DateTime.now()))
        ('dataNascimento', 'A data de nascimento deve estar no passado'),
      if (_texto(json['telefone']).isEmpty)
        ('telefone', 'telefone não pode ser vazio'),
      if (_texto(json['endereco']).isEmpty)
        ('endereco', 'endereco não pode ser vazio'),
      if (!['NORMAL', 'AUSENTE'].contains(json['modo']))
        ('modo', 'modo é obrigatorio'),
    ];
    if (erros.isNotEmpty || nascimento == null) {
      _errosDeCampo(requisicao, erros);
      return null;
    }
    return dataJava(nascimento);
  }

  Future<void> _cadastrarIdoso(
    HttpRequest requisicao,
    UsuarioFalso usuario,
    Map<String, dynamic> json,
    Map<String, String> query,
  ) async {
    final parentesco = query['parentesco'];
    if (parentesco == null) {
      return _erro(requisicao, 400,
          "O parâmetro obrigatório 'parentesco' não foi informado.");
    }
    final ordem = int.tryParse(query['ordemEscalonamento'] ?? '');
    if (ordem == null || ordem < 1) {
      return _erro(requisicao, 400,
          "O parâmetro obrigatório 'ordemEscalonamento' não foi informado.");
    }
    final nascimento = _validarIdoso(requisicao, json);
    if (nascimento == null) return;

    final idoso = IdosoFalso(dados.proximoId(), _texto(json['nome']),
        nascimento, _texto(json['telefone']), _texto(json['endereco']),
        _texto(json['modo']));
    dados.idosos.add(idoso);
    dados.contatos.add(ContatoFalso(
        dados.proximoId(), usuario.id, idoso.id, parentesco, ordem));
    return _json(requisicao, 201, idoso.toJson());
  }

  Future<void> _atualizarIdoso(
    HttpRequest requisicao,
    IdosoFalso idoso,
    Map<String, dynamic> json,
  ) async {
    final nascimento = _validarIdoso(requisicao, json);
    if (nascimento == null) return;
    idoso
      ..nome = _texto(json['nome'])
      ..dataNascimento = nascimento
      ..telefone = _texto(json['telefone'])
      ..endereco = _texto(json['endereco'])
      ..modo = _texto(json['modo']);
    return _json(requisicao, 200, idoso.toJson());
  }

  Future<void> _cadastrarDispositivo(
    HttpRequest requisicao,
    IdosoFalso idoso,
    Map<String, dynamic> json,
  ) {
    final erros = [
      if (!['LAMPADA', 'BASE'].contains(json['tipo']))
        ('tipo', 'tipo é obrigatorio'),
      if (_texto(json['comodo']).isEmpty)
        ('comodo', 'comodo não pode ser vazio'),
      if (!['ONLINE', 'OFFLINE'].contains(json['status']))
        ('status', 'status é obrigatorio'),
    ];
    if (erros.isNotEmpty) return _errosDeCampo(requisicao, erros);

    final dispositivo = DispositivoFalso(dados.proximoId(), idoso.id,
        _texto(json['tipo']), _texto(json['comodo']), _texto(json['status']),
        dataHoraJava(DateTime.now()));
    dados.dispositivos.add(dispositivo);
    return _json(requisicao, 201, dispositivo.toJson());
  }

  Future<void> _cadastrarRotina(
    HttpRequest requisicao,
    IdosoFalso idoso,
    Map<String, dynamic> json,
  ) {
    final hora = _texto(json['horaPrimeiraAtividade']);
    final media = json['mediaLevantadasPorNoite'];
    final erros = [
      if (_texto(json['diaSemana']).isEmpty)
        ('diaSemana', 'diaSemana não pode ser vazio'),
      if (!RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(hora))
        ('horaPrimeiraAtividade', 'horaPrimeiraAtividade é obrigatorio'),
      if (media is! int || media < 0)
        ('mediaLevantadasPorNoite', 'A media nao pode ser negativa'),
    ];
    if (erros.isNotEmpty) return _errosDeCampo(requisicao, erros);

    final rotina = RotinaFalsa(dados.proximoId(), idoso.id,
        _texto(json['diaSemana']), hora.length == 5 ? '$hora:00' : hora,
        media as int);
    dados.rotinas.add(rotina);
    return _json(requisicao, 201, rotina.toJson());
  }

  Future<void> _eventosDoDispositivo(
    HttpRequest requisicao,
    UsuarioFalso usuario,
    Map<String, String> query,
  ) {
    final dispositivoId = int.tryParse(query['dispositivoId'] ?? '');
    if (dispositivoId == null) {
      return _erro(requisicao, 400,
          "O parâmetro obrigatório 'dispositivoId' não foi informado.");
    }
    final dispositivo = dados.dispositivos
        .where((d) => d.id == dispositivoId)
        .toList();
    if (dispositivo.isEmpty ||
        !dados.podeAcessarIdoso(usuario, dispositivo.single.idosoId)) {
      return _semPermissao(requisicao);
    }
    return _pagina(requisicao, [
      for (final evento in dados.eventos)
        if (evento.dispositivoId == dispositivoId) evento.toJson(),
    ], query);
  }

  // ---------------------------------------------------------------------
  // Alertas
  // ---------------------------------------------------------------------

  /// Mesma regra do PermissaoService.podeFiltrar do Java.
  Future<void> _filtrarAlertas(
    HttpRequest requisicao,
    UsuarioFalso usuario,
    Map<String, String> query,
  ) {
    final idosoId = int.tryParse(query['idosoId'] ?? '');
    final usuarioId = int.tryParse(query['usuarioId'] ?? '');

    var pode = usuario.ehGestao;
    if (!pode) {
      if (usuarioId != null && usuarioId != usuario.id) {
        pode = false;
      } else if (idosoId != null) {
        pode = dados.podeAcessarIdoso(usuario, idosoId);
      } else {
        pode = usuarioId == usuario.id;
      }
    }
    if (!pode) return _semPermissao(requisicao);

    return _pagina(requisicao, [
      for (final alerta in dados.alertas)
        if ((idosoId == null || alerta.idosoId == idosoId) &&
            (usuarioId == null || alerta.usuarioId == usuarioId) &&
            (query['status'] == null || alerta.status == query['status']) &&
            (query['nivel'] == null || alerta.nivel == query['nivel']))
          alerta.toJson(),
    ], query);
  }

  Future<void> _atualizarAlerta(
    HttpRequest requisicao,
    UsuarioFalso usuario,
    String idTexto,
    Map<String, dynamic> json,
  ) {
    final id = int.tryParse(idTexto);
    final encontrados = dados.alertas.where((a) => a.id == id).toList();
    if (encontrados.isEmpty) {
      return usuario.ehGestao
          ? _erro(requisicao, 404, 'alerta não encontrado com id $idTexto')
          : _semPermissao(requisicao);
    }
    final alerta = encontrados.single;
    if (!dados.podeAcessarIdoso(usuario, alerta.idosoId)) {
      return _semPermissao(requisicao);
    }

    final niveis = ['ATENCAO', 'ALERTA', 'CRITICO'];
    final status = ['ABERTO', 'ESCALONADO', 'RESOLVIDO'];
    final escalonamento = json['nivelEscalonamento'];
    final erros = [
      if (_texto(json['tipo']).isEmpty) ('tipo', 'O tipo não pode ser vazio'),
      if (!niveis.contains(json['nivel'])) ('nivel', 'O nivel é obrigatorio'),
      if (!status.contains(json['status'])) ('status', 'O status é obrigatio'),
      if (escalonamento is! int || escalonamento < 1)
        ('nivelEscalonamento', 'O nivel deve ser positivo'),
    ];
    if (erros.isNotEmpty) return _errosDeCampo(requisicao, erros);

    if (alerta.status == 'RESOLVIDO' && json['status'] != 'RESOLVIDO') {
      return _erro(requisicao, 409,
          'Um alerta resolvido nao pode ser reaberto. Crie outro alerta.');
    }
    alerta
      ..tipo = _texto(json['tipo'])
      ..nivel = _texto(json['nivel'])
      ..status = _texto(json['status']);
    return _json(requisicao, 200, alerta.toJson());
  }

  // ---------------------------------------------------------------------
  // Respostas
  // ---------------------------------------------------------------------

  /// PageResponse do Java, com ordenação por `sort` e `direction`.
  Future<void> _pagina(
    HttpRequest requisicao,
    List<Map<String, dynamic>> itens,
    Map<String, String> query,
  ) {
    final campo = query['sort'] ?? 'id';
    final decrescente = (query['direction'] ?? 'ASC').toUpperCase() == 'DESC';
    itens.sort((a, b) {
      final valorA = a[campo];
      final valorB = b[campo];
      final comparacao = valorA is Comparable && valorB is Comparable
          ? valorA.compareTo(valorB)
          : 0;
      return decrescente ? -comparacao : comparacao;
    });

    final pagina = int.tryParse(query['page'] ?? '') ?? 0;
    final tamanho = int.tryParse(query['size'] ?? '') ?? 10;
    final inicio = pagina * tamanho;
    final conteudo = itens.skip(inicio).take(tamanho).toList();
    final totalPaginas = itens.isEmpty ? 0 : (itens.length / tamanho).ceil();

    return _json(requisicao, 200, {
      'content': conteudo,
      'page': pagina,
      'size': tamanho,
      'totalElements': itens.length,
      'totalPages': totalPaginas,
      'last': inicio + tamanho >= itens.length,
    });
  }

  Future<void> _semPermissao(HttpRequest requisicao) => _erro(
    requisicao,
    403,
    'Você não tem permissão para executar esta ação',
  );

  /// ErrorCustomResponse do Java.
  Future<void> _erro(HttpRequest requisicao, int status, String mensagem) =>
      _json(requisicao, status, {
        'timestamp': DateTime.now().toIso8601String(),
        'status': status,
        'error': _motivo(status),
        'message': mensagem,
      });

  /// ValidationErrorResponse do Java.
  Future<void> _errosDeCampo(
    HttpRequest requisicao,
    List<(String, String)> erros,
  ) => _json(requisicao, 400, {
    'timestamp': DateTime.now().toIso8601String(),
    'status': 400,
    'error': 'Bad Request',
    'errors': [
      for (final (campo, mensagem) in erros)
        {'field': campo, 'message': mensagem},
    ],
  });

  String _motivo(int status) => switch (status) {
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    409 => 'Conflict',
    _ => 'Error',
  };

  Future<void> _json(HttpRequest requisicao, int status, Object corpo) async {
    final bytes = utf8.encode(jsonEncode(corpo));
    requisicao.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..contentLength = bytes.length
      ..add(bytes);
    await requisicao.response.close();
  }

  String _texto(Object? valor) => valor is String ? valor.trim() : '';
}
