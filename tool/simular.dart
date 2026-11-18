// Faz o papel da lâmpada (ESP32) na demonstração, falando com a API Java
// de verdade. Também prepara dados de demonstração no banco.
//
// Precisa da API Java rodando e de uma conta ADMIN ou MANAGER, porque
// registrar eventos e alertas é exclusivo desses perfis na API.
// As credenciais vêm das mesmas variáveis da API Java:
//   ADMIN_EMAIL e ADMIN_PASSWORD (padrão: admin@tobem.com / Admin@12345)
// e o endereço vem de API_URL (padrão: http://localhost:8080).
//
// Uso:
//   dart run tool/simular.dart preparar
//       cria (uma vez só) a conta familiar.teste@example.com / Teste12345!,
//       dois idosos ligados a ela, uma lâmpada e uma rotina para cada um.
//
//   dart run tool/simular.dart <acao> <id do dispositivo>
//       movimento    evento MOVIMENTO (a pessoa se mexeu)
//       queda        evento ALERTA_QUEDA_N2 + alerta CRÍTICO
//       inatividade  evento ALERTA_INATIVIDADE_N2 + alerta de nível ALERTA
//       calor        evento TEMPERATURA_ALTA (34 °C) + alerta de ATENÇÃO
//       temperatura  evento TEMPERATURA (26 °C)
//       ok           evento BOTAO_OK ("Estou bem")
//       saiu         evento BOTAO_AUSENTE + idoso em modo "fora de casa"
//       voltou       evento BOTAO_VOLTEI + idoso em modo "em casa"
//       heartbeat    renova o "último sinal" do dispositivo
//
// Exemplo: dart run tool/simular.dart queda 1

import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';

const String emailFamiliar = 'familiar.teste@example.com';
const String senhaFamiliar = 'Teste12345!';

/// Ação -> (tipo do evento, valor, alerta a criar: (tipo, nível) ou null).
const Map<String, (String, int, (String, NivelAlerta)?)> acoes = {
  'movimento': ('MOVIMENTO', 1, null),
  'queda': ('ALERTA_QUEDA_N2', 1, ('QUEDA', NivelAlerta.critico)),
  'inatividade': (
    'ALERTA_INATIVIDADE_N2',
    1,
    ('INATIVIDADE', NivelAlerta.alerta),
  ),
  'calor': ('TEMPERATURA_ALTA', 34, ('TEMPERATURA_ALTA', NivelAlerta.atencao)),
  'temperatura': ('TEMPERATURA', 26, null),
  'ok': ('BOTAO_OK', 1, null),
  'saiu': ('BOTAO_AUSENTE', 1, null),
  'voltou': ('BOTAO_VOLTEI', 1, null),
};

Future<void> main(List<String> argumentos) async {
  final comando = argumentos.isEmpty ? '' : argumentos[0];
  final dispositivoId = argumentos.length == 2
      ? int.tryParse(argumentos[1])
      : null;

  final valido =
      (comando == 'preparar' && argumentos.length == 1) ||
      ((acoes.containsKey(comando) || comando == 'heartbeat') &&
          dispositivoId != null);
  if (!valido) {
    _mostrarUso();
    exitCode = 64;
    return;
  }

  final api = ApiClient();
  try {
    final sessao = await _entrarComoGestor(api);
    if (comando == 'preparar') {
      await _preparar(api, sessao);
    } else if (comando == 'heartbeat') {
      await api.post('/api/dispositivos/$dispositivoId/heartbeat', null);
      stdout.writeln('OK: heartbeat do dispositivo $dispositivoId registrado.');
    } else {
      await _simular(api, sessao, comando, dispositivoId!);
    }
  } on ApiException catch (erro) {
    stderr.writeln('Erro: ${erro.mensagem}');
    for (final campo in erro.campos.entries) {
      stderr.writeln('  - ${campo.key}: ${campo.value}');
    }
    exitCode = 1;
  } finally {
    api.fechar();
  }
}

void _mostrarUso() {
  stderr.writeln('Uso:');
  stderr.writeln('  dart run tool/simular.dart preparar');
  stderr.writeln(
    '  dart run tool/simular.dart '
    '<${[...acoes.keys, 'heartbeat'].join('|')}> <id do dispositivo>',
  );
  stderr.writeln('Exemplo: dart run tool/simular.dart queda 1');
}

Future<Sessao> _entrarComoGestor(ApiClient api) async {
  final email = Platform.environment['ADMIN_EMAIL'] ?? 'admin@tobem.com';
  final senha = Platform.environment['ADMIN_PASSWORD'] ?? 'Admin@12345';
  final sessao = await AuthService(api).login(email, senha);
  if (!sessao.ehGestao) {
    throw ApiException(
      '$email não é ADMIN nem MANAGER. Defina ADMIN_EMAIL e ADMIN_PASSWORD.',
    );
  }
  return sessao;
}

/// Registra o evento como se fosse a lâmpada e, se a ação pedir, abre o
/// alerta correspondente.
Future<void> _simular(
  ApiClient api,
  Sessao sessao,
  String acao,
  int dispositivoId,
) async {
  final (tipo, valor, alerta) = acoes[acao]!;
  final evento = ApiClient.objetoDaResposta(
    await api.post('/api/dispositivos/$dispositivoId/evento', {
      'tipo': tipo,
      'valor': valor,
      'dataHora': dataHoraParaApi(DateTime.now()),
    }),
  );
  final eventoId = lerInt(evento['id']);
  stdout.writeln('OK: evento $tipo #$eventoId no dispositivo $dispositivoId.');

  if (alerta != null) {
    final (tipoAlerta, nivel) = alerta;
    final criado = ApiClient.objetoDaResposta(
      await api.post('/api/eventos/$eventoId/alerta', {
        'tipo': tipoAlerta,
        'nivel': enumParaApi(nivel),
        'status': 'ABERTO',
        'nivelEscalonamento': 1,
      }),
    );
    stdout.writeln(
      'OK: alerta $tipoAlerta (${nivel.rotulo}) #${criado['id']} aberto.',
    );
  }

  if (acao == 'saiu' || acao == 'voltou') {
    final dispositivo = Dispositivo.fromJson(
      ApiClient.objetoDaResposta(
        await api.get('/api/dispositivos/$dispositivoId'),
      ),
    );
    final idoso = Idoso.fromJson(
      ApiClient.objetoDaResposta(
        await api.get('/api/idosos/${dispositivo.idosoId}'),
      ),
    );
    final modo = acao == 'saiu' ? ModoIdoso.ausente : ModoIdoso.normal;
    await IdosoService(api, sessao).alterarModo(idoso, modo);
    stdout.writeln('OK: ${idoso.nome} agora está "${modo.rotulo}".');
  }
}

/// Cria a conta de familiar e os idosos de demonstração (só na primeira vez).
Future<void> _preparar(ApiClient api, Sessao sessao) async {
  try {
    await api.post('/api/auth/register', {
      'name': 'Familiar Teste',
      'email': emailFamiliar,
      'password': senhaFamiliar,
    });
    stdout.writeln('Conta criada: $emailFamiliar / $senhaFamiliar');
  } on ApiException catch (erro) {
    if (erro.statusCode != 409) rethrow;
    stdout.writeln('Conta $emailFamiliar já existia (senha mantida).');
  }

  final usuarios = ApiClient.listaDaResposta(
    await api.get('/api/usuarios', parametros: ApiClient.pagina()),
  ).map(Usuario.fromJson);
  final familiar = usuarios.firstWhere(
    (usuario) => usuario.email.toLowerCase() == emailFamiliar,
    orElse: () => throw const ApiException(
      'Conta do familiar não encontrada em /api/usuarios.',
    ),
  );

  final vinculos = ApiClient.objetoDaResposta(
    await api.get('/api/usuarios/${familiar.id}/withContatos'),
  );
  final idososDoFamiliar = {
    for (final contato in lerLista(vinculos['contatos'], Contato.fromJson))
      contato.idosoId,
  };

  if (idososDoFamiliar.isEmpty) {
    await _criarIdoso(
      api,
      familiarId: familiar.id,
      idoso: Idoso(
        nome: 'Dona Maria',
        dataNascimento: DateTime(1948, 3, 12),
        telefone: '11988887777',
        endereco: 'Rua das Flores, 120',
      ),
      parentesco: 'Filho(a)',
      comodo: 'Sala',
      horaAcorda: '07:00:00',
    );
    await _criarIdoso(
      api,
      familiarId: familiar.id,
      idoso: Idoso(
        nome: 'Seu João',
        dataNascimento: DateTime(1944, 7, 5),
        telefone: '11977776666',
        endereco: 'Avenida Brasil, 45',
      ),
      parentesco: 'Neto(a)',
      comodo: 'Quarto',
      horaAcorda: '06:30:00',
    );
  } else {
    stdout.writeln('O familiar já tem idosos vinculados; nada foi criado.');
  }

  stdout.writeln('');
  stdout.writeln('Dispositivos do familiar (use o número nas simulações):');
  final atualizados = ApiClient.objetoDaResposta(
    await api.get('/api/usuarios/${familiar.id}/withContatos'),
  );
  for (final contato in lerLista(atualizados['contatos'], Contato.fromJson)) {
    final idoso = ApiClient.objetoDaResposta(
      await api.get('/api/idosos/${contato.idosoId}/withDispositivos'),
    );
    for (final dispositivo in lerLista(
      idoso['dispositivos'],
      Dispositivo.fromJson,
    )) {
      stdout.writeln('  ${idoso['nome']}: #${dispositivo.id} ${dispositivo.nome}');
    }
  }
  stdout.writeln('');
  stdout.writeln('Entre no app com $emailFamiliar / $senhaFamiliar');
  stdout.writeln('Exemplo: dart run tool/simular.dart queda <número acima>');
}

Future<void> _criarIdoso(
  ApiClient api, {
  required int familiarId,
  required Idoso idoso,
  required String parentesco,
  required String comodo,
  required String horaAcorda,
}) async {
  final criado = Idoso.fromJson(
    ApiClient.objetoDaResposta(
      await api.post(
        '/api/usuarios/$familiarId/idoso',
        idoso.toJson(),
        parametros: {'parentesco': parentesco, 'ordemEscalonamento': '1'},
      ),
    ),
  );
  final idosoId = criado.id;
  if (idosoId == null) throw const ApiException('A API não devolveu o id.');

  final dispositivo = Dispositivo.fromJson(
    ApiClient.objetoDaResposta(
      await api.post(
        '/api/idosos/$idosoId/dispositivo',
        Dispositivo(tipo: TipoDispositivo.lampada, comodo: comodo).toJson(),
      ),
    ),
  );
  await api.post(
    '/api/idosos/$idosoId/rotina',
    Rotina(
      diaSemana: 'TODOS',
      horaPrimeiraAtividade: horaAcorda,
      mediaLevantadasPorNoite: 2,
    ).toJson(),
  );
  for (final tipo in ['INICIADO', 'MOVIMENTO']) {
    await api.post('/api/dispositivos/${dispositivo.id}/evento', {
      'tipo': tipo,
      'valor': 1,
      'dataHora': dataHoraParaApi(DateTime.now()),
    });
  }
  stdout.writeln(
    'Criado: ${criado.nome} (#$idosoId) com ${dispositivo.nome} '
    '#${dispositivo.id} e rotina.',
  );
}
