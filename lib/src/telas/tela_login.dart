import '../core/config/app_config.dart';
import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';

/// Tela de login: pede e-mail e senha, valida e chama a API.
class TelaLogin {
  TelaLogin(this._auth, this.entrada, {this.tentativasMaximas = 3});

  final AuthService _auth;
  final Entrada entrada;
  final int tentativasMaximas;

  /// Devolve a sessão, ou null se a API estiver fora do ar
  /// ou se o usuário errar a senha [tentativasMaximas] vezes.
  Future<Sessao?> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('${AppConfig.nomeApp} - Login'));
    entrada.escrever('Acompanhe quem você ama, sem câmeras.');
    entrada.escrever('');

    for (var tentativa = 1; tentativa <= tentativasMaximas; tentativa++) {
      final email = entrada.perguntar('E-mail', validar: validarEmail);
      final senha = entrada.perguntarSenha('Senha', validar: validarSenha);

      try {
        entrada.escrever(Terminal.colorir('Entrando...', Cor.cinza));
        final sessao = await _auth.login(email, senha);
        entrada.mostrarSucesso(
          'Bem-vindo(a), ${sessao.usuario.nome}! '
          '(${sessao.usuario.papel.rotulo})',
        );
        return sessao;
      } on SemConexaoException catch (erro) {
        entrada.mostrarErro(erro.mensagem);
        return null;
      } on ApiException catch (erro) {
        entrada.mostrarErro(erro.mensagem);
        final restantes = tentativasMaximas - tentativa;
        if (restantes > 0) {
          entrada.mostrarAviso('Tentativas restantes: $restantes');
          entrada.escrever('');
        }
      }
    }

    entrada.mostrarErro('Número máximo de tentativas atingido.');
    return null;
  }
}
