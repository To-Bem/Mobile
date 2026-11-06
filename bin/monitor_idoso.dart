import 'package:monitor_idoso/monitor_idoso.dart';

/// Tela provisória só para conferir as cores no seu terminal.
/// Será substituída pelo login na camada 05.
void main(List<String> argumentos) {
  Terminal.limparTela();
  print(Terminal.cabecalho(AppConfig.nomeApp));
  print('Monitoramento sem câmera para idosos que moram sozinhos');
  print('');
  print('Legenda de status:');
  print(
    '  ${Terminal.etiqueta('OK', Cor.verde)}  '
    '${Terminal.etiqueta('ATENÇÃO', Cor.amarelo)}  '
    '${Terminal.etiqueta('ALERTA', Cor.vermelho)}  '
    '${Terminal.etiqueta('CRÍTICO', Cor.vermelhoForte)}  '
    '${Terminal.etiqueta('SEM SINAL', Cor.cinza)}',
  );
  print('');
  print(Terminal.colorir('API configurada: ${AppConfig.apiBaseUrl}', Cor.azul));
}
