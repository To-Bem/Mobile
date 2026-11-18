import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/dispositivo.dart';
import '../models/enums.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/erros_api.dart';

/// Cadastro da lâmpada (ou base) instalada na casa do idoso.
/// O número gerado pela API é o que vai no firmware do ESP32.
class TelaCadastroDispositivo {
  TelaCadastroDispositivo({
    required this.idosoId,
    required this.idosoNome,
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final int idosoId;
  final String idosoNome;
  final IdosoService _idosos;
  final Entrada entrada;

  static const List<String> comodos = [
    'Sala',
    'Quarto',
    'Banheiro',
    'Cozinha',
    'Corredor',
    'Outro',
  ];

  /// Devolve o dispositivo salvo, ou null se o usuário cancelar ou a API
  /// recusar.
  Future<Dispositivo?> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('Novo dispositivo de $idosoNome'));
    entrada.escrever('Qual aparelho vai ser instalado?');
    final tipoEscolhido = entrada.escolherOpcao([
      for (final tipo in TipoDispositivo.values) tipo.rotulo,
    ], rotuloZero: 'Cancelar');
    if (tipoEscolhido == 0) return _cancelar();
    final tipo = TipoDispositivo.values[tipoEscolhido - 1];

    entrada.escrever('Em qual cômodo?');
    final comodoEscolhido = entrada.escolherOpcao(
      comodos,
      rotuloZero: 'Cancelar',
    );
    if (comodoEscolhido == 0) return _cancelar();
    var comodo = comodos[comodoEscolhido - 1];
    if (comodo == 'Outro') {
      comodo = entrada.perguntar('Qual cômodo?', validar: validarComodo);
    }

    final novo = Dispositivo(tipo: tipo, comodo: comodo);

    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Confira os dados:', Cor.negrito));
    entrada.escrever('  Aparelho: ${novo.tipo.rotulo}');
    entrada.escrever('  Cômodo: ${novo.comodo}');
    entrada.escrever('');
    if (!entrada.confirmar('Salvar?')) return _cancelar();

    try {
      final salvo = await _idosos.cadastrarDispositivo(idosoId, novo);
      entrada.mostrarSucesso('${salvo.nome} cadastrado(a) com o número ${salvo.id}.');
      entrada.escrever(
        Terminal.colorir(
          'Use DISPOSITIVO_ID ${salvo.id} no firmware da lâmpada (ESP32).',
          Cor.cinza,
        ),
      );
      entrada.pausar();
      return salvo;
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
      entrada.pausar();
      return null;
    }
  }

  Dispositivo? _cancelar() {
    entrada.mostrarAviso('Cadastro cancelado. Nada foi salvo.');
    entrada.pausar();
    return null;
  }
}
