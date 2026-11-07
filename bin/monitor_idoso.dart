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

    await TelaMenuPrincipal(
      sessao: sessao,
      idosoService: IdosoService(api),
      entrada: entrada,
    ).exibir();

    auth.sair();
    entrada.escrever('Até logo, ${sessao.usuario.nome}!');
  } on EntradaEncerradaException {
    entrada.escrever('');
    entrada.escrever('Até logo!');
  } finally {
    api.fechar();
  }
}
