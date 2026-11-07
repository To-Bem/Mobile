import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/idoso.dart';
import '../services/monitor_service.dart';
import 'comum/formatacao.dart';

/// Monitoramento ao vivo: consulta a API de tempos em tempos e avisa
/// (com bip) quando o status de alguém piora ou surge um alerta novo.
class TelaMonitoramento {
  TelaMonitoramento({
    required this.monitor,
    required this.entrada,
    this.duracaoDeUmMinuto = const Duration(minutes: 1),
  });

  final MonitorService monitor;
  final Entrada entrada;

  /// Só os testes mudam isto, para "um minuto" durar milissegundos.
  final Duration duracaoDeUmMinuto;

  static const int maximoMinutos = 30;

  Future<void> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('Monitoramento ao vivo'));
    entrada.escrever(
      'Verifica a cada ${_textoIntervalo()} e avisa quando algo muda.',
    );
    entrada.escrever('');

    final minutos = int.parse(
      entrada.perguntar(
        'Por quantos minutos? (1 a $maximoMinutos)',
        validar: (valor) => validarNumeroEntre(valor, 1, maximoMinutos),
      ),
    );
    final quantidade = monitor.leiturasPara(duracaoDeUmMinuto * minutos);

    entrada.escrever(
      Terminal.colorir(
        'Monitorando por $minutos min ($quantidade verificações). '
        'Ctrl+C fecha a aplicação.',
        Cor.cinza,
      ),
    );
    entrada.escrever('');

    List<Idoso>? anterior;
    var verificacoes = 0;
    var mudancas = 0;
    var falhas = 0;
    var semConexao = false;

    await for (final leitura in monitor.leituras(quantidade)) {
      verificacoes++;
      final hora = horaComSegundos(leitura.momento);

      switch (leitura) {
        case LeituraFalhou(:final erro):
          falhas++;
          semConexao = true;
          entrada.mostrarErro('$hora  ${erro.mensagem} Tentando de novo...');

        case LeituraOk(:final idosos):
          if (semConexao) {
            entrada.mostrarSucesso('$hora  Conexão restabelecida.');
            semConexao = false;
          }

          if (anterior == null) {
            entrada.escrever('$hora  Situação inicial:');
            _mostrarSituacao(idosos);
          } else {
            final lista = compararLeituras(anterior, idosos);
            if (lista.isEmpty) {
              entrada.escrever(
                Terminal.colorir('$hora  sem mudanças', Cor.cinza),
              );
            }
            for (final mudanca in lista) {
              _mostrarMudanca(hora, mudanca);
            }
            mudancas += lista.length;
          }
          anterior = idosos;
      }
    }

    entrada.escrever('');
    entrada.escrever(
      'Monitoramento encerrado: $verificacoes verificações, '
      '$mudancas ${mudancas == 1 ? 'mudança' : 'mudanças'}, '
      '$falhas ${falhas == 1 ? 'falha' : 'falhas'}.',
    );
    entrada.pausar();
  }

  String _textoIntervalo() {
    final intervalo = monitor.intervalo;
    return intervalo.inSeconds >= 1
        ? '${intervalo.inSeconds} s'
        : '${intervalo.inMilliseconds} ms';
  }

  void _mostrarSituacao(List<Idoso> idosos) {
    if (idosos.isEmpty) {
      entrada.escrever('  Nenhum idoso para monitorar.');
      return;
    }
    for (final idoso in ordenarPorPrioridade(idosos)) {
      final alertas = switch (idoso.alertasAbertos) {
        0 => '',
        1 => ' (1 alerta aberto)',
        final n => ' ($n alertas abertos)',
      };
      final fora = idoso.estaAusente ? ' | fora de casa' : '';
      entrada.escrever(
        '  ${etiquetaStatus(idoso.status)} ${idoso.nome}$alertas$fora',
      );
    }
  }

  void _mostrarMudanca(String hora, Mudanca mudanca) {
    final idoso = mudanca.atual;
    final partes = [
      if (mudanca.statusMudou)
        '${mudanca.anterior.status.rotulo} → ${idoso.status.rotulo}',
      if (mudanca.novosAlertas == 1) '+1 alerta',
      if (mudanca.novosAlertas > 1) '+${mudanca.novosAlertas} alertas',
      if (mudanca.modoMudou)
        idoso.estaAusente ? 'saiu de casa' : 'voltou para casa',
    ];
    final linha =
        '$hora  ${etiquetaStatus(idoso.status)} ${idoso.nome}: ${partes.join(' | ')}';

    if (mudanca.piorou || mudanca.novosAlertas > 0) {
      entrada.mostrarAviso(linha);
      entrada.bip();
    } else {
      entrada.escrever(linha);
    }
  }
}
