import '../core/config/app_config.dart';
import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import 'comum/erros_api.dart';

/// Tela inicial: entrar com uma conta existente ou criar uma nova.
class TelaLogin {
  TelaLogin(this._auth, this.entrada, {this.tentativasMaximas = 3});

  final AuthService _auth;
  final Entrada entrada;
  final int tentativasMaximas;

  /// Devolve a sessão, ou null se o usuário sair, se a API estiver fora
  /// do ar ou se errar a senha [tentativasMaximas] vezes.
  Future<Sessao?> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('${AppConfig.nomeApp} - Login'));
    entrada.escrever('Acompanhe quem você ama, sem câmeras.');
    entrada.escrever('');

    try {
      while (true) {
        final opcao = entrada.escolherOpcao([
          'Entrar',
          'Criar conta',
        ], rotuloZero: 'Sair');

        switch (opcao) {
          case 0:
            return null;
          case 1:
            return await _entrar();
          case 2:
            final sessao = await _criarConta();
            if (sessao != null) return sessao;
        }
      }
    } on SemConexaoException catch (erro) {
      entrada.mostrarErro(erro.mensagem);
      return null;
    }
  }

  Future<Sessao?> _entrar() async {
    for (var tentativa = 1; tentativa <= tentativasMaximas; tentativa++) {
      final email = entrada.perguntar('E-mail', validar: validarEmail);
      final senha = entrada.perguntarSenha(
        'Senha',
        validar: (valor) => validarObrigatorio(valor, 'Senha'),
      );

      try {
        entrada.escrever(Terminal.colorir('Entrando...', Cor.cinza));
        final sessao = await _auth.login(email, senha);
        _darBoasVindas(sessao);
        return sessao;
      } on SemConexaoException {
        rethrow;
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

  /// Cadastro público da API: cria um usuário MEMBER (familiar/cuidador).
  Future<Sessao?> _criarConta() async {
    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Criar conta', Cor.negrito));

    final nome = entrada.perguntar('Nome completo', validar: validarNome);
    final email = entrada.perguntar('E-mail', validar: validarEmail);
    final senha = entrada.perguntarSenha(
      'Senha (mínimo 8 caracteres)',
      validar: validarSenha,
    );
    entrada.perguntarSenha(
      'Repita a senha',
      validar: (valor) => valor == senha ? null : 'As senhas não conferem.',
    );

    try {
      entrada.escrever(Terminal.colorir('Criando conta...', Cor.cinza));
      final sessao = await _auth.cadastrar(
        nome: nome,
        email: email,
        senha: senha,
      );
      entrada.mostrarSucesso('Conta criada!');
      _darBoasVindas(sessao);
      return sessao;
    } on SemConexaoException {
      rethrow;
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
      entrada.escrever('');
      return null;
    }
  }

  void _darBoasVindas(Sessao sessao) {
    entrada.mostrarSucesso(
      'Bem-vindo(a), ${sessao.usuario.nome}! (${sessao.perfil.rotulo})',
    );
  }
}
