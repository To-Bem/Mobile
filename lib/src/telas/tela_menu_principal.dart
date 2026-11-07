import '../core/config/app_config.dart';
import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../models/enums.dart';
import '../models/usuario.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'tela_lista_idosos.dart';

/// Menu principal. As opções e os textos mudam conforme o papel do usuário.
class TelaMenuPrincipal {
  TelaMenuPrincipal({
    required this.sessao,
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final Sessao sessao;
  final IdosoService _idosos;
  final Entrada entrada;

  Usuario get _usuario => sessao.usuario;

  String get _rotuloIdosos => switch (_usuario.papel) {
    Papel.familiar => 'Meus idosos',
    Papel.cuidador => 'Idosos que acompanho',
    Papel.admin => 'Todos os idosos',
  };

  /// Volta quando o usuário escolhe "Sair".
  Future<void> exibir() async {
    while (true) {
      entrada.limparTela();
      entrada.escrever(Terminal.cabecalho(AppConfig.nomeApp));
      entrada.escrever('Olá, ${_usuario.nome} (${_usuario.papel.rotulo})');
      await _mostrarResumo();
      entrada.escrever('');

      final opcao = entrada.escolherOpcao([_rotuloIdosos], rotuloZero: 'Sair');

      switch (opcao) {
        case 0:
          return;
        case 1:
          await TelaListaIdosos(
            titulo: _rotuloIdosos,
            idosoService: _idosos,
            entrada: entrada,
          ).exibir();
      }
    }
  }

  /// Ex.: "Você acompanha 3 idosos: 1 tudo bem, 1 atenção, 1 crítico."
  Future<void> _mostrarResumo() async {
    try {
      final idosos = await _idosos.listar();
      if (idosos.isEmpty) {
        entrada.mostrarAviso('Nenhum idoso vinculado a você ainda.');
        return;
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

      final urgentes =
          (porStatus[StatusIdoso.critico] ?? 0) +
          (porStatus[StatusIdoso.alerta] ?? 0);
      if (urgentes > 0) {
        entrada.mostrarAviso(
          urgentes == 1
              ? '1 idoso precisa de atenção agora.'
              : '$urgentes idosos precisam de atenção agora.',
        );
      }
    } on ApiException catch (erro) {
      entrada.mostrarErro(
        'Não foi possível carregar o resumo: ${erro.mensagem}',
      );
    }
  }
}
