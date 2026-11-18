import '../models/alerta.dart';
import '../models/enums.dart';
import 'api_client.dart';
import 'idoso_service.dart';

/// Consulta e confirmação de alertas.
class AlertaService {
  AlertaService(this._api, this._idosos);

  final ApiClient _api;

  /// Usado para saber quais idosos o usuário enxerga e os nomes deles
  /// (a API devolve só o idosoId em cada alerta).
  final IdosoService _idosos;

  /// Alertas visíveis para o usuário, do mais recente para o mais antigo.
  ///
  /// - com [idosoId]: GET /api/alertas/byOtherFilter?idosoId=
  /// - ADMIN/MANAGER: GET /api/alertas (todos)
  /// - MEMBER: um byOtherFilter para cada idoso em que ele é contato
  Future<List<Alerta>> listar({int? idosoId}) async {
    final idosos = await _idosos.listarBasico();
    final nomes = <int, String>{
      for (final idoso in idosos)
        if (idoso.id != null) idoso.id!: idoso.nome,
    };

    final List<Map<String, dynamic>> brutos;
    if (idosoId != null) {
      brutos = await _doIdoso(idosoId);
    } else if (_idosos.sessao.ehGestao) {
      brutos = ApiClient.listaDaResposta(
        await _api.get(
          '/api/alertas',
          parametros: ApiClient.pagina(direcao: 'DESC'),
        ),
      );
    } else {
      final porIdoso = await Future.wait(nomes.keys.map(_doIdoso));
      brutos = [for (final lista in porIdoso) ...lista];
    }

    return [
      for (final json in brutos)
        _comNome(Alerta.fromJson(json), nomes),
    ]..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  }

  /// PUT /api/alertas/{id} com status RESOLVIDO.
  /// A API exige o alerta completo, então os outros campos são reenviados.
  Future<Alerta> confirmar(Alerta alerta) async {
    final corpo = await _api.put(
      '/api/alertas/${alerta.id}',
      alerta.paraAtualizar(novoStatus: StatusAlerta.resolvido),
    );
    return Alerta.fromJson(
      ApiClient.objetoDaResposta(corpo),
    ).copyWith(idosoNome: alerta.idosoNome);
  }

  Future<List<Map<String, dynamic>>> _doIdoso(int idosoId) async {
    final corpo = await _api.get(
      '/api/alertas/byOtherFilter',
      parametros: {
        'idosoId': '$idosoId',
        ...ApiClient.pagina(direcao: 'DESC'),
      },
    );
    return ApiClient.listaDaResposta(corpo);
  }

  Alerta _comNome(Alerta alerta, Map<int, String> nomes) {
    final nome = nomes[alerta.idosoId];
    return nome == null ? alerta : alerta.copyWith(idosoNome: nome);
  }
}
