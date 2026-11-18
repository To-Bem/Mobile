import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';

Future<void> main(List<String> argumentos) async {
  final api = ApiClient();
  final auth = AuthService(api);
  final entrada = Entrada();

  try {
    final sessao = await TelaLogin(auth, entrada).exibir();
    if (sessao == null) {
      entrada.escrever('Encerrando.');
      exitCode = 1;
      return;
    }

    // Os serviços dependem da sessão: o perfil (ADMIN, MANAGER ou MEMBER)
    // decide quais idosos e alertas o usuário enxerga.
    final idosoService = IdosoService(api, sessao);
    await TelaMenuPrincipal(
      sessao: sessao,
      idosoService: idosoService,
      alertaService: AlertaService(api, idosoService),
      entrada: entrada,
    ).exibir();

    auth.sair();
    entrada.escrever('Até logo, ${sessao.usuario.nome}!');
  } on EntradaEncerradaException {
    entrada.escrever('');
    entrada.escrever('Até logo!');
  } on NaoAutorizadoException catch (erro) {
    entrada.mostrarErro('${erro.mensagem} Abra o app de novo para entrar.');
    exitCode = 1;
  } finally {
    api.fechar();
  }
}
