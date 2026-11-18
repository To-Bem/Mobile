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
import 'tela_cadastro_dispositivo.dart';
import 'tela_cadastro_rotina.dart';

/// Detalhe do idoso: situação agora, dispositivos, rotina, contatos de
/// emergência, ambiente e linha do tempo. Também cadastra dispositivo e
/// rotina e (para ADMIN/MANAGER) liga/desliga o "fora de casa".
class TelaDetalheIdoso {
  TelaDetalheIdoso({
    required this.idosoId,
    required IdosoService idosoService,
    required AlertaService alertaService,
    required this.entrada,
  }) : _idosos = idosoService,
       _alertas = alertaService;

  final int idosoId;
  final IdosoService _idosos;
  final AlertaService _alertas;
  final Entrada entrada;

  /// Quantos eventos aparecem na linha do tempo.
  static const int eventosNaLinhaDoTempo = 10;

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
      _mostrarSituacao(painel);
      _mostrarDispositivos(painel);
      _mostrarRotina(painel);
      await _mostrarContatos(painel.contatos);
      _mostrarLinhaDoTempo(painel);
      entrada.escrever('');

      // Opções como pares (texto, ação). "Atualizar" não faz nada: o painel
      // é recarregado no começo do laço depois de qualquer opção.
      final opcoes = <(String, Future<void> Function())>[
        ('Atualizar', () async {}),
        (
          'Ver alertas (${textoAbertos(idoso.alertasAbertos)})',
          () => TelaAlertas(
            alertaService: _alertas,
            entrada: entrada,
            idosoId: idosoId,
            titulo: 'Alertas de ${idoso.nome}',
          ).exibir(),
        ),
        (
          'Cadastrar dispositivo (lâmpada ou base)',
          () => TelaCadastroDispositivo(
            idosoId: idosoId,
            idosoNome: idoso.nome,
            idosoService: _idosos,
            entrada: entrada,
          ).exibir(),
        ),
        (
          'Cadastrar rotina',
          () => TelaCadastroRotina(
            idosoId: idosoId,
            idosoNome: idoso.nome,
            idosoService: _idosos,
            entrada: entrada,
          ).exibir(),
        ),
        if (_idosos.sessao.ehGestao)
          (
            idoso.estaAusente
                ? 'Marcar que voltou para casa'
                : 'Marcar como fora de casa',
            () => _alternarModo(idoso),
          ),
      ];

      final opcao = entrada.escolherOpcao([
        for (final (rotulo, _) in opcoes) rotulo,
      ]);
      if (opcao == 0) return;

      final (_, abrir) = opcoes[opcao - 1];
      await abrir();
    }
  }

  void _mostrarSituacao(PainelIdoso painel) {
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
      entrada.escrever('Ambiente: ${formatarDecimal(temperatura)} °C');
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

  void _mostrarDispositivos(PainelIdoso painel) {
    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Dispositivos', Cor.negrito));
    if (painel.dispositivos.isEmpty) {
      entrada.mostrarAviso(
        'Nenhum dispositivo cadastrado: a casa ainda não está sendo '
        'monitorada.',
      );
      return;
    }

    final agora = DateTime.now();
    for (final dispositivo in painel.dispositivos) {
      final online = dispositivo.estaOnline(agora, _idosos.limiteSemSinal);
      final sinal = dispositivo.ultimoSinal;
      final etiqueta = online
          ? Terminal.etiqueta('ONLINE', Cor.verde)
          : Terminal.etiqueta('SEM SINAL', Cor.cinza);
      entrada.escrever(
        '  #${dispositivo.id} ${dispositivo.nome} $etiqueta'
        '${sinal == null ? '' : ' último sinal ${tempoDesde(sinal)}'}',
      );
    }
  }

  void _mostrarRotina(PainelIdoso painel) {
    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Rotina', Cor.negrito));
    if (painel.rotinas.isEmpty) {
      entrada.escrever('  Nenhuma rotina cadastrada.');
      return;
    }
    for (final rotina in painel.rotinas) {
      final levantadas = rotina.mediaLevantadasPorNoite == 1
          ? '1 levantada'
          : '${rotina.mediaLevantadasPorNoite} levantadas';
      entrada.escrever(
        '  ${rotuloDiaSemana(rotina.diaSemana)}: acorda às '
        '${rotina.horaCurta} | $levantadas por noite',
      );
    }
  }

  Future<void> _mostrarContatos(List<Contato> contatosDaApi) async {
    entrada.escrever('');
    entrada.escrever(
      Terminal.colorir('Contatos de emergência (ordem de aviso)', Cor.negrito),
    );
    if (contatosDaApi.isEmpty) {
      entrada.mostrarAviso('Nenhum contato vinculado.');
      return;
    }

    final List<Contato> contatos;
    try {
      contatos = await _idosos.comNomes(contatosDaApi);
    } on ApiException catch (erro) {
      entrada.mostrarErro(
        'Não foi possível carregar os contatos: ${erro.mensagem}',
      );
      return;
    }
    for (final contato in contatos) {
      entrada.escrever(
        '  ${contato.ordemEscalonamento}º ${contato.nomeUsuario} '
        '(${contato.parentesco})',
      );
    }
  }

  void _mostrarLinhaDoTempo(PainelIdoso painel) {
    entrada.escrever('');
    entrada.escrever(
      Terminal.colorir('Linha do tempo (eventos recentes)', Cor.negrito),
    );
    if (painel.eventos.isEmpty) {
      entrada.escrever('  Nenhum evento registrado.');
      return;
    }
    for (final evento in painel.eventos.take(eventosNaLinhaDoTempo)) {
      final comodo = evento.comodo == null ? '' : ' (${evento.comodo})';
      final valor = evento.valor;
      final medida = evento.ehTemperatura && valor != null
          ? ': ${formatarDecimal(valor)} °C'
          : '';
      entrada.escrever(
        '  ${horario(evento.dataHora).padLeft(11)}  '
        '${evento.descricao}$medida$comodo',
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
      final atualizado = await _idosos.alterarModo(idoso, novoModo);
      entrada.mostrarSucesso('Pronto! Agora: ${atualizado.modo.rotulo}.');
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
    }
    entrada.pausar();
  }
}
