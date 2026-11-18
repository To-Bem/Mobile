import '../core/utils/json_utils.dart';
import '../models/enums.dart';
import '../models/usuario.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Login, cadastro e logout. Guarda a sessão e entrega o token ao ApiClient.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;
  Sessao? _sessao;

  Sessao? get sessao => _sessao;
  Usuario? get usuario => _sessao?.usuario;
  bool get logado => _sessao != null;

  /// POST /api/auth/login e, com o token, GET /api/auth/me
  /// (o login devolve só token, e-mail e role; o id e o nome vêm do /me).
  Future<Sessao> login(String email, String senha) async {
    final Map<String, dynamic> resposta;
    try {
      resposta = ApiClient.objetoDaResposta(
        await _api.post('/api/auth/login', {
          'email': email.trim(),
          'password': senha,
        }),
      );
    } on NaoAutorizadoException {
      throw const ApiException('E-mail ou senha inválidos.', statusCode: 401);
    }

    final token = lerTexto(resposta['token']);
    if (token.isEmpty) throw const ApiException('A API não devolveu o token.');
    _api.token = token;

    try {
      final usuario = Usuario.fromJson(
        ApiClient.objetoDaResposta(await _api.get('/api/auth/me')),
      );
      final sessao = Sessao(
        token: token,
        perfil: enumDaApi(Perfil.values, resposta['role'], Perfil.member),
        usuario: usuario,
      );
      _sessao = sessao;
      return sessao;
    } on ApiException {
      _api.token = null;
      rethrow;
    }
  }

  /// POST /api/auth/register (cria um usuário MEMBER) e já faz o login.
  Future<Sessao> cadastrar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    try {
      await _api.post('/api/auth/register', {
        'name': nome.trim(),
        'email': email.trim(),
        'password': senha,
      });
    } on ApiException catch (erro) {
      if (erro.statusCode == 409) {
        throw const ApiException(
          'Já existe uma conta com este e-mail.',
          statusCode: 409,
        );
      }
      rethrow;
    }
    return login(email, senha);
  }

  void sair() {
    _api.token = null;
    _sessao = null;
  }
}
