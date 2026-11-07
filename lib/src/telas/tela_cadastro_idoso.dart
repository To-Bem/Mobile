import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/idoso.dart';
import '../services/api_exception.dart';
import '../services/idoso_service.dart';
import 'comum/erros_api.dart';
import 'comum/formatacao.dart';
import 'tela_cadastro_contato.dart';

/// Formulário de cadastro de idoso.
/// Cada campo é validado na hora; no fim, mostra o resumo e pede confirmação.
class TelaCadastroIdoso {
  TelaCadastroIdoso({
    required IdosoService idosoService,
    required this.entrada,
  }) : _idosos = idosoService;

  final IdosoService _idosos;
  final Entrada entrada;

  /// Devolve o idoso salvo, ou null se o usuário cancelar ou a API recusar.
  Future<Idoso?> exibir() async {
    entrada.limparTela();
    entrada.escrever(Terminal.cabecalho('Cadastrar idoso'));
    entrada.escrever('Preencha os dados de quem vai ser acompanhado.');
    entrada.escrever('');

    final nome = entrada.perguntar('Nome completo', validar: validarNome);
    final nascimento = converterDataBr(entrada.perguntar(
      'Data de nascimento (dd/mm/aaaa)',
      validar: validarDataNascimento,
    ));
    final telefone =
        entrada.perguntar('Telefone com DDD', validar: validarTelefone);
    final endereco =
        entrada.perguntar('Endereço (rua e número)', validar: validarEndereco);

    final novo = Idoso(
      nome: nome,
      dataNascimento: nascimento,
      telefone: somenteDigitos(telefone),
      endereco: endereco,
    );

    entrada.escrever('');
    entrada.escrever(Terminal.colorir('Confira os dados:', Cor.negrito));
    entrada.escrever('  Nome: ${novo.nome}');
    if (nascimento != null) {
      entrada.escrever('  Nascimento: ${dataBr(nascimento)} (${novo.idade} anos)');
    }
    entrada.escrever('  Telefone: ${formatarTelefone(novo.telefone)}');
    entrada.escrever('  Endereço: ${novo.endereco}');
    entrada.escrever('');

    if (!entrada.confirmar('Salvar?')) {
      entrada.mostrarAviso('Cadastro cancelado. Nada foi salvo.');
      entrada.pausar();
      return null;
    }

    final Idoso salvo;
    try {
      salvo = await _idosos.cadastrar(novo);
    } on ApiException catch (erro) {
      mostrarErroDaApi(entrada, erro);
      entrada.pausar();
      return null;
    }

    entrada.mostrarSucesso('${salvo.nome} cadastrado(a) com sucesso!');
    entrada.mostrarAviso(
      'Sem contato de emergência, os alertas só chegam para você.',
    );

    final idosoId = salvo.id;
    if (idosoId != null &&
        entrada.confirmar('Cadastrar um contato de emergência agora?')) {
      await TelaCadastroContato(
        idosoId: idosoId,
        idosoNome: salvo.nome,
        idosoService: _idosos,
        entrada: entrada,
      ).exibir();
    } else {
      entrada.pausar();
    }
    return salvo;
  }
}
