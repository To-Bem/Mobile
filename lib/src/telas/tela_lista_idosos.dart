import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../models/idoso.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/formatacao.dart';
import 'tela_detalhe_idoso.dart';

/// Lista de idosos, dos mais urgentes para os que estão bem.
/// Escolher um número abre o detalhe; ao voltar, a lista é recarregada.
class TelaListaIdosos {
  TelaListaIdosos({
    required this.titulo,
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final String titulo;
  final IdosoService _idosos;
  final Entrada entrada;

  Future<void> exibir() async {
    while (true) {
      entrada.limparTela();
      entrada.escrever(Terminal.cabecalho(titulo));

      final List<Idoso> idosos;
      try {
        idosos = ordenarPorPrioridade(await _idosos.listar());
      } on ApiException catch (erro) {
        entrada.mostrarErro(erro.mensagem);
        entrada.pausar();
        return;
      }

      if (idosos.isEmpty) {
        entrada.mostrarAviso('Nenhum idoso vinculado a você ainda.');
        entrada.pausar();
        return;
      }

      for (var i = 0; i < idosos.length; i++) {
        _mostrarCartao(i + 1, idosos[i]);
      }
      entrada.escrever('  0) Voltar');

      final opcao = entrada.lerOpcao(idosos.length);
      if (opcao == 0) return;

      await TelaDetalheIdoso(
        idosoId: idosos[opcao - 1].id ?? 0,
        idosoService: _idosos,
        entrada: entrada,
      ).exibir();
    }
  }

  void _mostrarCartao(int numero, Idoso idoso) {
    final idade = idoso.idade == null ? '' : ', ${idoso.idade} anos';
    final ultima = idoso.ultimaAtividade;

    entrada.escrever(
      '  $numero) ${idoso.nome}$idade  ${etiquetaStatus(idoso.status)}',
    );
    entrada.escrever(
      Terminal.colorir(
        '     Última atividade: ${ultima == null ? 'sem registro' : tempoDesde(ultima)}'
        ' | Alertas abertos: ${idoso.alertasAbertos}'
        '${idoso.estaAusente ? ' | Fora de casa' : ''}',
        Cor.cinza,
      ),
    );
  }
}
