import 'package:monitor_idoso/monitor_idoso.dart';

/// Cria uma Entrada que "digita" as [respostas] em ordem e guarda tudo
/// o que seria mostrado na tela em [saida].
/// Quando as respostas acabam, simula o usuário encerrando a entrada.
Entrada entradaFalsa(List<String> respostas, List<String> saida) {
  final fila = List.of(respostas);
  return Entrada(
    lerLinha: () => fila.isEmpty ? null : fila.removeAt(0),
    escrever: saida.add,
    escreverPrompt: saida.add,
  );
}
