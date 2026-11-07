import '../models/contato.dart';
import '../models/enums.dart';
import '../models/idoso.dart';
import '../models/painel_idoso.dart';
import 'api_client.dart';

/// Operações sobre idosos e seus contatos.
class IdosoService {
  IdosoService(this._api);

  final ApiClient _api;

  /// GET /idosos — a API já devolve só os idosos ligados ao usuário logado.
  Future<List<Idoso>> listar() async {
    final corpo = await _api.get('/idosos');
    return ApiClient.listaDaResposta(corpo).map(Idoso.fromJson).toList();
  }

  /// GET /idosos/{id}/painel
  Future<PainelIdoso> painel(int idosoId) async {
    final corpo = await _api.get('/idosos/$idosoId/painel');
    return PainelIdoso.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// POST /idosos
  Future<Idoso> cadastrar(Idoso idoso) async {
    final corpo = await _api.post('/idosos', idoso.toJson());
    return Idoso.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// PATCH /idosos/{id}/modo — liga ou desliga o "fora de casa".
  Future<Idoso> alterarModo(int idosoId, ModoIdoso modo) async {
    final corpo = await _api.patch(
      '/idosos/$idosoId/modo',
      {'modo': enumParaApi(modo)},
    );
    return Idoso.fromJson(ApiClient.objetoDaResposta(corpo));
  }

  /// GET /idosos/{id}/contatos — na ordem em que serão avisados.
  Future<List<Contato>> listarContatos(int idosoId) async {
    final corpo = await _api.get('/idosos/$idosoId/contatos');
    return ApiClient.listaDaResposta(corpo).map(Contato.fromJson).toList()
      ..sort((a, b) => a.ordemEscalonamento.compareTo(b.ordemEscalonamento));
  }

  /// POST /idosos/{id}/contatos
  Future<Contato> cadastrarContato(int idosoId, Contato contato) async {
    final corpo =
        await _api.post('/idosos/$idosoId/contatos', contato.toJson());
    return Contato.fromJson(ApiClient.objetoDaResposta(corpo));
  }
}
