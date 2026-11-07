import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../models/contato.dart';
import '../models/enums.dart';
import '../models/idoso.dart';
import '../models/painel_idoso.dart';
import '../services/alerta_service.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/erros_api.dart';
import 'comum/formatacao.dart';
import 'tela_alertas.dart';
import 'tela_cadastro_contato.dart';

/// Detalhe do idoso: status agora, contatos de emergência, ambiente e
/// linha do tempo. Também liga/desliga o "fora de casa" e cadastra contatos.
class TelaDetalheIdoso {
  TelaDetalheIdoso({
    required this.idosoId,
    required IdosoService idosoService,
    required AlertaService alertaService,
    required this.entrada,
  })  : _idosos = idosoService,
        _alertas = alertaService;

  final int idosoId;
  final IdosoService _idosos;
  final AlertaService _alertas;
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

      final idoso = painel.idoso;
      _mostrarPainel(painel);
      await _mostrarContatos();
      _mostrarLinhaDoTempo(painel);
      entrada.escrever('');

      final opcao = entrada.escolherOpcao([
        'Atualizar',
        'Ver alertas (${textoAbertos(idoso.alertasAbertos)})',
        idoso.estaAusente
            ? 'Marcar que voltou para casa'
            : 'Marcar como fora de casa',
        'Cadastrar contato de emergência',
      ]);

      switch (opcao) {
        case 0:
          return;
        case 2:
          await TelaAlertas(
            alertaService: _alertas,
            entrada: entrada,
            idosoId: idosoId,
            titulo: 'Alertas de ${idoso.nome}',
          ).exibir();
        case 3:
          await _alternarModo(idoso);
        case 4:
          await TelaCadastroContato(
            idosoId: idosoId,
            idosoNome: idoso.nome,
            idosoService: _idosos,
            entrada: entrada,
          ).exibir();
      }
      // Depois de qualquer opção (inclusive 1, Atualizar) o painel é recarregado.
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
    entrada.escrever([
      if (idade != null) '$idade anos',
      if (idoso.telefone.isNotEmpty) formatarTelefone(idoso.telefone),
      idoso.modo.rotulo,
    ].join(' | '));
    if (idoso.endereco.isNotEmpty) {
      entrada.escrever('Endereço: ${idoso.endereco}');
    }

    entrada.escrever(ultima == null
        ? 'Última atividade: sem registro'
        : 'Última atividade: ${horario(ultima)} (${tempoDesde(ultima)})');

    final alertas = idoso.alertasAbertos;
    entrada.escrever(Terminal.colorir(
      'Alertas abertos: $alertas',
      alertas > 0 ? Cor.vermelho : Cor.verde,
    ));

    final temperatura = painel.temperatura;
    if (temperatura != null) {
      final umidade = painel.umidade;
      entrada.escrever('Ambiente: ${formatarDecimal(temperatura)} °C'
          '${umidade == null ? '' : ' | umidade ${umidade.round()}%'}');
      if (temperatura >= temperaturaDePerigo) {
        entrada.mostrarAviso(
          'Calor perigoso dentro de casa. Lembre a pessoa de beber água.',
        );
      }
    }

    if (idoso.estaAusente) {
      entrada.mostrarAviso(
        'Fora de casa: alertas de falta de atividade estão pausados.',
      );
    }
  }

  void _mostrarLinhaDoTempo(PainelIdoso painel) {
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

  Future<void> _mostrarContatos() async {
    entrada.escrever('');
    entrada.escrever(
      Terminal.colorir('Contatos de emergência (ordem de aviso)', Cor.negrito),
    );

    final List<Contato> contatos;
    try {
      contatos = await _idosos.listarContatos(idosoId);
    } on ApiException catch (erro) {
      entrada.mostrarErro('Não foi possível carregar os contatos: '
          '${erro.mensagem}');
      return;
    }

    if (contatos.isEmpty) {
      entrada.mostrarAviso(
        'Nenhum contato cadastrado. Use a opção 4 para cadastrar.',
      );
      return;
    }
    for (final contato in contatos) {
      entrada.escrever(
        '  ${contato.ordemEscalonamento}º ${contato.nome} '
        '(${contato.parentesco}) - ${formatarTelefone(contato.telefone)}',
      );
    }
  }

  Future<void> _alternarModo(Idoso idoso) async {
    final novoModo = idoso.estaAusente ? ModoIdoso.normal : ModoIdoso.ausente;
    final pergunta = idoso.estaAusente
        ? 'Confirmar que ${idoso.nome} voltou para casa?'
        : 'Marcar ${idoso.nome} como fora de casa? Os alertas de falta de '
            'atividade ficam pausados até a volta.';

    if (!entrada.confirmar(pergunta)) {
      entrada.mostrarAviso('Nada foi alterado.');
      entrada.pausar();
      return;
    }

    try {
      final atualizado = await _idosos.alterarModo(idosoId, novoModo);
      entrada.mostrarSucesso('Pronto! Agora: ${atualizado.modo.rotulo}.');
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
    }
    entrada.pausar();
  }
}
