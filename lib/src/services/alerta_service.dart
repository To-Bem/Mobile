import '../models/alerta.dart';
import '../models/enums.dart';
import 'api_client.dart';

/// Consulta e confirmação de alertas.
class AlertaService {
  AlertaService(this._api);

  final ApiClient _api;

  /// GET /alertas?status=&nivel=&idosoId= — filtros opcionais.
  /// Devolve do mais recente para o mais antigo.
  Future<List<Alerta>> listar({
    StatusAlerta? status,
    NivelAlerta? nivel,
    int? idosoId,
  }) async {
    final corpo = await _api.get('/alertas', parametros: {
      if (status != null) 'status': enumParaApi(status),
      if (nivel != null) 'nivel': enumParaApi(nivel),
      if (idosoId != null) 'idosoId': '$idosoId',
    });
    return ApiClient.listaDaResposta(corpo).map(Alerta.fromJson).toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  }

  /// PATCH /alertas/{id}/confirmar
  Future<Alerta> confirmar(int alertaId) async {
    final corpo = await _api.patch('/alertas/$alertaId/confirmar');
    return Alerta.fromJson(ApiClient.objetoDaResposta(corpo));
  }
}
