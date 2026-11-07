import '../core/config/app_config.dart';
import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

/// Tela de login: pede e-mail e senha, valida e chama a API.
class TelaLogin {
  TelaLogin(this._auth, this._entrada, {this.tentativasMaximas = 3});

  final AuthService _auth;
  final Entrada _entrada;
  final int tentativasMaximas;

  /// Devolve a sessão, ou null se a API estiver fora do ar
  /// ou se o usuário errar a senha [tentativasMaximas] vezes.
  Future<Sessao?> exibir() async {
    _entrada.limparTela();
    _entrada.escrever(Terminal.cabecalho('${AppConfig.nomeApp} - Login'));
    _entrada.escrever('Acompanhe quem você ama, sem câmeras.');
    _entrada.escrever('');

    for (var tentativa = 1; tentativa <= tentativasMaximas; tentativa++) {
      final email = _entrada.perguntar('E-mail', validar: validarEmail);
      final senha = _entrada.perguntarSenha('Senha', validar: validarSenha);

      try {
        _entrada.escrever(Terminal.colorir('Entrando...', Cor.cinza));
        final sessao = await _auth.login(email, senha);
        _entrada.mostrarSucesso(
          'Bem-vindo(a), ${sessao.usuario.nome}! '
          '(${sessao.usuario.papel.rotulo})',
        );
        return sessao;
      } on SemConexaoException catch (erro) {
        _entrada.mostrarErro(erro.mensagem);
        return null;
      } on ApiException catch (erro) {
        _entrada.mostrarErro(erro.mensagem);
        final restantes = tentativasMaximas - tentativa;
        if (restantes > 0) {
          _entrada.mostrarAviso('Tentativas restantes: $restantes');
          _entrada.escrever('');
        }
      }
    }

    _entrada.mostrarErro('Número máximo de tentativas atingido.');
    return null;
  }
}
