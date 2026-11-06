import '../models/usuario.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Login e logout. Guarda a sessão e entrega o token ao ApiClient.
class AuthService {
  AuthService(this._api);

  final ApiClient _api;
  Sessao? _sessao;

  Sessao? get sessao => _sessao;
  Usuario? get usuario => _sessao?.usuario;
  bool get logado => _sessao != null;

  /// POST /auth/login
  Future<Sessao> login(String email, String senha) async {
    try {
      final corpo = await _api.post('/auth/login', {
        'email': email.trim(),
        'senha': senha,
      });
      final sessao = Sessao.fromJson(ApiClient.objetoDaResposta(corpo));
      _api.token = sessao.token;
      _sessao = sessao;
      return sessao;
    } on NaoAutorizadoException {
      throw const ApiException('E-mail ou senha inválidos.', statusCode: 401);
    }
  }

  void sair() {
    _api.token = null;
    _sessao = null;
  }
}
