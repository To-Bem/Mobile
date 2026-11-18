import '../core/config/app_config.dart';
import '../core/utils/json_utils.dart';
import '../models/contato.dart';
import '../models/dispositivo.dart';
import '../models/enums.dart';
import '../models/evento.dart';
import '../models/idoso.dart';
import '../models/painel_idoso.dart';
import '../models/rotina.dart';
import '../models/usuario.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Operações sobre idosos, dispositivos e rotinas.
///
/// Quem o usuário enxerga depende do perfil (Role) da sessão:
/// - ADMIN/MANAGER: todos os idosos (GET /api/idosos);
/// - MEMBER: só os idosos em que ele é contato
///   (GET /api/usuarios/{id}/withContatos).
class IdosoService {
  IdosoService(
    this._api,
    this.sessao, {
    DateTime Function()? relogio,
    Duration? limiteSemSinal,
  }) : _relogio = relogio ?? DateTime.now,
       limiteSemSinal = limiteSemSinal ?? AppConfig.semSinalDepoisDe;

  final ApiClient _api;
  final Sessao sessao;
  final DateTime Function() _relogio;

  /// Sem heartbeat nem evento por mais que isto, o dispositivo está sem sinal.
  final Duration limiteSemSinal;

  /// Nomes de usuários já consultados (evita repetir chamadas).
  final Map<int, String?> _nomesDeUsuarios = {};

  /// Idosos visíveis para o usuário, sem a situação calculada.
  /// Mais leve que [listar]: serve para mostrar nomes.
  Future<List<Idoso>> listarBasico() async {
    if (sessao.ehGestao) {
      final corpo = await _api.get(
        '/api/idosos',
        parametros: ApiClient.pagina(ordenarPor: 'nome'),
      );
      return ApiClient.listaDaResposta(corpo).map(Idoso.fromJson).toList();
    }
    final ids = await _idsDosMeusIdosos();
    final respostas = await Future.wait(
      ids.map((id) => _api.get('/api/idosos/$id')),
    );
    return [
      for (final corpo in respostas)
        Idoso.fromJson(ApiClient.objetoDaResposta(corpo)),
    ];
  }

  /// Idosos visíveis, já com status, última atividade e alertas abertos.
  Future<List<Idoso>> listar() async {
    final List<int> ids;
    if (sessao.ehGestao) {
      ids = [
        for (final idoso in await listarBasico())
          if (idoso.id != null) idoso.id!,
      ];
    } else {
      ids = await _idsDosMeusIdosos();
    }
    final paineis = await Future.wait(ids.map(painel));
    return [for (final resultado in paineis) resultado.idoso];
  }

  /// GET /api/idosos/{id}/withAll + eventos recentes de cada dispositivo.
  Future<PainelIdoso> painel(int idosoId) async {
    final corpo = ApiClient.objetoDaResposta(
      await _api.get('/api/idosos/$idosoId/withAll'),
    );
    final dispositivos = lerLista(corpo['dispositivos'], Dispositivo.fromJson);
    final eventosPorDispositivo = await Future.wait([
      for (final dispositivo in dispositivos)
        if (dispositivo.id != null) eventosRecentes(dispositivo.id!),
    ]);

    return PainelIdoso.montar(
      corpo,
      [for (final eventos in eventosPorDispositivo) ...eventos],
      agora: _relogio(),
      limiteSemSinal: limiteSemSinal,
    );
  }

  /// GET /api/eventos/byOtherFilter — os mais recentes primeiro.
  Future<List<Evento>> eventosRecentes(
    int dispositivoId, {
    int quantidade = AppConfig.eventosPorDispositivo,
  }) async {
    final corpo = await _api.get(
      '/api/eventos/byOtherFilter',
      parametros: {
        'dispositivoId': '$dispositivoId',
        ...ApiClient.pagina(tamanho: quantidade, direcao: 'DESC'),
      },
    );
    return ApiClient.listaDaResposta(corpo).map(Evento.fromJson).toList();
  }

  /// POST /api/usuarios/{id}/idoso — cadastra o idoso e já cria o contato
  /// ligando o usuário logado a ele (primeiro da fila de aviso).
  Future<Idoso> cadastrar(Idoso idoso, {required String parentesco}) async {
    final corpo = await _api.post(
      '/api/usuarios/${sessao.usuario.id}/idoso',
      idoso.toJson(),
      parametros: {'parentesco': parentesco, 'ordemEscalonamento': '1'},
    );
    return Idoso.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// PUT /api/idosos/{id} — liga ou desliga o "fora de casa".
  /// A API exige o cadastro completo, então os outros dados são reenviados.
  /// Só ADMIN e MANAGER podem alterar.
  Future<Idoso> alterarModo(Idoso idoso, ModoIdoso modo) async {
    if (idoso.id == null || idoso.dataNascimento == null) {
      throw const ApiException('Cadastro do idoso incompleto.');
    }
    final corpo = await _api.put(
      '/api/idosos/${idoso.id}',
      idoso.copyWith(modo: modo).toJson(),
    );
    return Idoso.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// POST /api/idosos/{id}/dispositivo
  Future<Dispositivo> cadastrarDispositivo(
    int idosoId,
    Dispositivo dispositivo,
  ) async {
    final corpo = await _api.post(
      '/api/idosos/$idosoId/dispositivo',
      dispositivo.toJson(),
    );
    return Dispositivo.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// POST /api/idosos/{id}/rotina
  Future<Rotina> cadastrarRotina(int idosoId, Rotina rotina) async {
    final corpo = await _api.post(
      '/api/idosos/$idosoId/rotina',
      rotina.toJson(),
    );
    return Rotina.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// Completa os contatos com o nome de cada usuário.
  /// MEMBER só pode consultar a própria conta; os outros aparecem como
  /// "Usuário #id".
  Future<List<Contato>> comNomes(List<Contato> contatos) async {
    final resultado = <Contato>[];
    for (final contato in contatos) {
      final nome = await _nomeDoUsuario(contato.usuarioId);
      resultado.add(
        contato.copyWith(nomeUsuario: nome ?? 'Usuário #${contato.usuarioId}'),
      );
    }
    return resultado;
  }

  Future<String?> _nomeDoUsuario(int usuarioId) async {
    if (usuarioId == sessao.usuario.id) return '${sessao.usuario.nome} (você)';
    if (!sessao.ehGestao) return null;
    if (_nomesDeUsuarios.containsKey(usuarioId)) {
      return _nomesDeUsuarios[usuarioId];
    }

    String? nome;
    try {
      final corpo = await _api.get('/api/usuarios/$usuarioId');
      nome = lerTexto(ApiClient.objetoDaResposta(corpo)['nome']);
    } on NaoAutorizadoException {
      nome = null;
    }
    _nomesDeUsuarios[usuarioId] = nome;
    return nome;
  }

  /// GET /api/usuarios/{id}/withContatos — idosos em que o usuário é contato.
  Future<List<int>> _idsDosMeusIdosos() async {
    final corpo = ApiClient.objetoDaResposta(
      await _api.get('/api/usuarios/${sessao.usuario.id}/withContatos'),
    );
    final contatos = lerLista(corpo['contatos'], Contato.fromJson);
    return {for (final contato in contatos) contato.idosoId}.toList();
  }
}
