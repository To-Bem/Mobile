import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../models/painel_idoso.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/formatacao.dart';

/// Detalhe do idoso: status agora, dados de contato, ambiente e linha do tempo.
class TelaDetalheIdoso {
  TelaDetalheIdoso({
    required this.idosoId,
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final int idosoId;
  final IdosoService _idosos;
  final Entrada entrada;

  Future<void> exibir() async {
    while (true) {
      entrada.limparTela();

      final PainelIdoso painel;
      try {
        painel = await _idosos.painel(idosoId);
      } on ApiException catch (erro) {
        entrada.mostrarErro(erro.mensagem);
        entrada.pausar();
        return;
      }

      _mostrarPainel(painel);
      entrada.escrever('');

      final opcao = entrada.escolherOpcao(['Atualizar']);
      if (opcao == 0) return;
    }
  }

  void _mostrarPainel(PainelIdoso painel) {
    final idoso = painel.idoso;
    final idade = idoso.idade;
    final ultima = idoso.ultimaAtividade;

    entrada.escrever(Terminal.cabecalho(idoso.nome));
    entrada.escrever(
      'Status: ${etiquetaStatus(idoso.status)} ${idoso.status.rotulo}',
    );
    entrada.escrever(
      [
        if (idade != null) '$idade anos',
        if (idoso.telefone.isNotEmpty) formatarTelefone(idoso.telefone),
        idoso.modo.rotulo,
      ].join(' | '),
    );
    if (idoso.endereco.isNotEmpty) {
      entrada.escrever('Endereço: ${idoso.endereco}');
    }

    entrada.escrever(
      ultima == null
          ? 'Última atividade: sem registro'
          : 'Última atividade: ${horario(ultima)} (${tempoDesde(ultima)})',
    );

    final alertas = idoso.alertasAbertos;
    entrada.escrever(
      Terminal.colorir(
        'Alertas abertos: $alertas',
        alertas > 0 ? Cor.vermelho : Cor.verde,
      ),
    );

    final temperatura = painel.temperatura;
    if (temperatura != null) {
      final umidade = painel.umidade;
      entrada.escrever(
        'Ambiente: ${formatarDecimal(temperatura)} °C'
        '${umidade == null ? '' : ' | umidade ${umidade.round()}%'}',
      );
      if (temperatura >= temperaturaDePerigo) {
        entrada.mostrarAviso(
          'Calor perigoso dentro de casa. Lembre a pessoa de beber água.',
        );
      }
    }

    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Linha do tempo', Cor.negrito));
    if (painel.eventosHoje.isEmpty) {
      entrada.escrever('  Nenhum evento registrado hoje.');
      return;
    }
    for (final evento in painel.eventosHoje) {
      final comodo = evento.comodo == null ? '' : ' (${evento.comodo})';
      final valor = evento.tipo == 'TEMPERATURA' && evento.valor != null
          ? ': ${formatarDecimal(evento.valor!)} °C'
          : '';
      entrada.escrever(
        '  ${horario(evento.dataHora).padLeft(11)}  '
        '${evento.descricao}$valor$comodo',
      );
    }
  }
}
