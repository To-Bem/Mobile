import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';

Future<void> main(List<String> argumentos) async {
  final api = ApiClient();
  final entrada = Entrada();

  try {
    final sessao = await TelaLogin(AuthService(api), entrada).exibir();
    if (sessao == null) {
      entrada.escrever('Encerrando.');
      exitCode = 1;
      return;
    }

    entrada.escrever('');
    entrada.mostrarAviso('O menu principal chega na camada 06.');
  } on EntradaEncerradaException {
    entrada.escrever('');
    entrada.escrever('Até logo!');
  } finally {
    api.fechar();
  }
}
