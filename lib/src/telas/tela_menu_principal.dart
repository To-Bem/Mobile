import '../core/config/app_config.dart';
import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../models/enums.dart';
import '../models/usuario.dart';
import '../services/alerta_service.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import '../services/monitor_service.dart';
import 'comum/formatacao.dart';
import 'tela_alertas.dart';
import 'tela_cadastro_idoso.dart';
import 'tela_lista_idosos.dart';
import 'tela_monitoramento.dart';

/// Menu principal. As opções e os textos mudam conforme o papel do usuário.
class TelaMenuPrincipal {
  TelaMenuPrincipal({
    required this.sessao,
    required IdosoService idosoService,
    required AlertaService alertaService,
    required this.entrada,
  })  : _idosos = idosoService,
        _alertas = alertaService;

  final Sessao sessao;
  final IdosoService _idosos;
  final AlertaService _alertas;
  final Entrada entrada;

  Usuario get _usuario => sessao.usuario;

  String get _rotuloIdosos => switch (_usuario.papel) {
        Papel.familiar => 'Meus idosos',
        Papel.cuidador => 'Idosos que acompanho',
        Papel.admin => 'Todos os idosos',
      };

  /// O cuidador acompanha idosos atribuídos a ele; quem cadastra é a família
  /// (ou o administrador).
  bool get _podeCadastrarIdoso => _usuario.papel != Papel.cuidador;

  /// Volta quando o usuário escolhe "Sair".
  Future<void> exibir() async {
    while (true) {
      entrada.limparTela();
      entrada.escrever(Terminal.cabecalho(AppConfig.nomeApp));
      entrada.escrever('Olá, ${_usuario.nome} (${_usuario.papel.rotulo})');
      final abertos = await _mostrarResumo();
      entrada.escrever('');

      // Cada opção é um par (texto, ação). A numeração se ajusta sozinha
      // quando uma opção não aparece para o papel do usuário.
      final opcoes = <(String, Future<void> Function())>[
        (
          _rotuloIdosos,
          () => TelaListaIdosos(
                titulo: _rotuloIdosos,
                idosoService: _idosos,
                alertaService: _alertas,
                entrada: entrada,
              ).exibir(),
        ),
        (
          abertos == null ? 'Alertas' : 'Alertas (${textoAbertos(abertos)})',
          () => TelaAlertas(alertaService: _alertas, entrada: entrada).exibir(),
        ),
        if (_podeCadastrarIdoso)
          (
            'Cadastrar idoso',
            () => TelaCadastroIdoso(idosoService: _idosos, entrada: entrada)
                .exibir(),
          ),
        (
          'Monitoramento ao vivo',
          () => TelaMonitoramento(
                monitor: MonitorService(_idosos),
                entrada: entrada,
              ).exibir(),
        ),
      ];

      final opcao = entrada.escolherOpcao(
        [for (final (rotulo, _) in opcoes) rotulo],
        rotuloZero: 'Sair',
      );
      if (opcao == 0) return;

      final (_, abrir) = opcoes[opcao - 1];
      await abrir();
    }
  }

  /// Ex.: "Você acompanha 3 idosos: 1 tudo bem, 1 atenção, 1 crítico."
  /// Devolve o total de alertas abertos, ou null se a API falhar.
  Future<int?> _mostrarResumo() async {
    try {
      final idosos = await _idosos.listar();
      if (idosos.isEmpty) {
        entrada.mostrarAviso('Nenhum idoso vinculado a você ainda.');
        return 0;
      }

      final porStatus = idosos.fold<Map<StatusIdoso, int>>(
        {},
        (contagem, idoso) =>
            contagem..update(idoso.status, (n) => n + 1, ifAbsent: () => 1),
      );
      final partes = [
        for (final status in StatusIdoso.values)
          if (porStatus.containsKey(status))
            '${porStatus[status]} ${status.rotulo.toLowerCase()}',
      ];
      final plural = idosos.length == 1 ? 'idoso' : 'idosos';
      entrada.escrever(
        'Você acompanha ${idosos.length} $plural: ${partes.join(', ')}.',
      );

      final urgentes = (porStatus[StatusIdoso.critico] ?? 0) +
          (porStatus[StatusIdoso.alerta] ?? 0);
      if (urgentes > 0) {
        entrada.mostrarAviso(urgentes == 1
            ? '1 idoso precisa de atenção agora.'
            : '$urgentes idosos precisam de atenção agora.');
      }

      return idosos.fold<int>(0, (soma, idoso) => soma + idoso.alertasAbertos);
    } on ApiException catch (erro) {
      entrada.mostrarErro('Não foi possível carregar o resumo: ${erro.mensagem}');
      return null;
    }
  }
}
