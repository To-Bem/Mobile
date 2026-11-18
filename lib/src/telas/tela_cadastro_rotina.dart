import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/utils/json_utils.dart';
import '../core/validacao/validadores.dart';
import '../models/rotina.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/erros_api.dart';
import 'comum/formatacao.dart';

/// Cadastro da rotina do idoso: a que horas costuma acordar e quantas vezes
/// se levanta à noite. É a referência para saber quando a falta de
/// movimento é estranha.
class TelaCadastroRotina {
  TelaCadastroRotina({
    required this.idosoId,
    required this.idosoNome,
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final int idosoId;
  final String idosoNome;
  final IdosoService _idosos;
  final Entrada entrada;

  static const int maximoLevantadas = 10;

  /// Devolve a rotina salva, ou null se o usuário cancelar ou a API recusar.
  Future<Rotina?> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('Rotina de $idosoNome'));

    entrada.escrever('Para qual dia?');
    final dias = diasDaSemana.keys.toList();
    final diaEscolhido = entrada.escolherOpcao([
      for (final dia in dias) rotuloDiaSemana(dia),
    ], rotuloZero: 'Cancelar');
    if (diaEscolhido == 0) return _cancelar();
    final dia = dias[diaEscolhido - 1];

    final (hora, minuto) = converterHora(
      entrada.perguntar(
        'A que horas costuma se levantar? (hh:mm)',
        validar: validarHora,
      ),
    )!;
    final levantadas = int.parse(
      entrada.perguntar(
        'Quantas vezes costuma se levantar à noite? (0 a $maximoLevantadas)',
        validar: (valor) => validarNumeroEntre(valor, 0, maximoLevantadas),
      ),
    );

    final nova = Rotina(
      diaSemana: dia,
      horaPrimeiraAtividade: horaParaApi(hora, minuto),
      mediaLevantadasPorNoite: levantadas,
    );

    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Confira os dados:', Cor.negrito));
    entrada.escrever('  Dia: ${rotuloDiaSemana(nova.diaSemana)}');
    entrada.escrever('  Primeira atividade: ${nova.horaCurta}');
    entrada.escrever('  Levantadas por noite: ${nova.mediaLevantadasPorNoite}');
    entrada.escrever('');
    if (!entrada.confirmar('Salvar?')) return _cancelar();

    try {
      final salva = await _idosos.cadastrarRotina(idosoId, nova);
      entrada.mostrarSucesso(
        'Rotina salva: ${rotuloDiaSemana(salva.diaSemana)}, '
        'acorda às ${salva.horaCurta}.',
      );
      entrada.pausar();
      return salva;
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
      entrada.pausar();
      return null;
    }
  }

  Rotina? _cancelar() {
    entrada.mostrarAviso('Cadastro cancelado. Nada foi salvo.');
    entrada.pausar();
    return null;
  }
}
