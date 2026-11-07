import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/contato.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/erros_api.dart';
import 'comum/formatacao.dart';

/// Formulário de contato de emergência: quem é avisado, e em que ordem,
/// quando um alerta não é confirmado.
class TelaCadastroContato {
  TelaCadastroContato({
    required this.idosoId,
    required this.idosoNome,
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final int idosoId;
  final String idosoNome;
  final IdosoService _idosos;
  final Entrada entrada;

  static const List<String> parentescos = [
    'Filho(a)',
    'Neto(a)',
    'Irmão(ã)',
    'Sobrinho(a)',
    'Vizinho(a)',
    'Amigo(a)',
    'Cuidador(a)',
    'Outro',
  ];

  /// Devolve o contato salvo, ou null se o usuário cancelar ou a API recusar.
  Future<Contato?> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('Novo contato de $idosoNome'));
    entrada.escrever(
      'Quem deve ser avisado quando um alerta não for confirmado?',
    );
    entrada.escrever('');

    final nome = entrada.perguntar('Nome', validar: validarNome);
    final telefone =
        entrada.perguntar('Telefone com DDD', validar: validarTelefone);

    entrada.escrever('Parentesco ou relação:');
    final opcao = entrada.escolherOpcao(parentescos, rotuloZero: 'Cancelar');
    if (opcao == 0) return _cancelar();

    var parentesco = parentescos[opcao - 1];
    if (parentesco == 'Outro') {
      parentesco = entrada.perguntar(
        'Qual?',
        validar: (valor) => validarObrigatorio(valor, 'Parentesco'),
      );
    }

    entrada.escrever(Terminal.colorir(
      'Ordem de aviso: 1 = avisado primeiro; 2 = avisado se o 1º não '
      'confirmar; e assim por diante.',
      Cor.cinza,
    ));
    final ordem = int.parse(entrada.perguntar(
      'Ordem de aviso (1 a $maximoOrdemEscalonamento)',
      validar: validarOrdemEscalonamento,
    ));

    final contato = Contato(
      nome: nome,
      telefone: somenteDigitos(telefone),
      parentesco: parentesco,
      ordemEscalonamento: ordem,
    );

    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Confira os dados:', Cor.negrito));
    entrada.escrever('  Nome: ${contato.nome}');
    entrada.escrever('  Telefone: ${formatarTelefone(contato.telefone)}');
    entrada.escrever('  Parentesco: ${contato.parentesco}');
    entrada.escrever('  Ordem de aviso: ${contato.ordemEscalonamento}º');
    entrada.escrever('');
    if (!entrada.confirmar('Salvar?')) return _cancelar();

    try {
      final salvo = await _idosos.cadastrarContato(idosoId, contato);
      entrada.mostrarSucesso(
        'Contato ${salvo.nome} salvo. Será o ${salvo.ordemEscalonamento}º '
        'a ser avisado.',
      );
      entrada.pausar();
      return salvo;
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
      entrada.pausar();
      return null;
    }
  }

  Contato? _cancelar() {
    entrada.mostrarAviso('Cadastro cancelado. Nada foi salvo.');
    entrada.pausar();
    return null;
  }
}
