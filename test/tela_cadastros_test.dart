import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import '../tool/api_fake.dart';
import 'apoio/entrada_falsa.dart';

/// Respostas válidas para o formulário de idoso, na ordem dos campos.
const List<String> idosoValido = [
  'José da Silva',
  '15/08/1950',
  '(11) 95555-4444',
  'Rua das Acácias, 77',
];

void main() {
  late HttpServer apiFalsa;
  late ApiClient api;
  late List<String> saida;

  setUp(() async {
    Terminal.usarCores = false;
    apiFalsa = await iniciarApiFalsa(porta: 0, registrarLog: false);
    api = ApiClient(baseUrl: 'http://127.0.0.1:${apiFalsa.port}');
    saida = <String>[];
    await AuthService(api).login('ana@email.com', '123456');
  });

  tearDown(() async {
    api.fechar();
    await apiFalsa.close(force: true);
  });

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  Future<Idoso?> cadastrarIdoso(List<String> respostas) => TelaCadastroIdoso(
        idosoService: IdosoService(api),
        entrada: entradaFalsa(respostas, saida),
      ).exibir();

  Future<void> abrirDetalhe(int idosoId, List<String> respostas) =>
      TelaDetalheIdoso(
        idosoId: idosoId,
        idosoService: IdosoService(api),
        alertaService: AlertaService(api),
        entrada: entradaFalsa(respostas, saida),
      ).exibir();

  group('Cadastro de idoso', () {
    test('valida cada campo, mostra o resumo e salva', () async {
      final idoso = await cadastrarIdoso([
        'Jo', 'José da Silva', //
        '31/02/1950', '12/03/2000', '15/08/1950', //
        '123', '(11) 95555-4444', //
        'Rua das Acácias', 'Rua das Acácias, 77', //
        's', // salvar
        'n', // não cadastrar contato agora
        '', // Enter
      ]);

      expect(mostrou('Nome muito curto'), isTrue);
      expect(mostrou('Data inválida'), isTrue);
      expect(mostrou('60 anos ou mais'), isTrue);
      expect(mostrou('Telefone inválido'), isTrue);
      expect(mostrou('Inclua o número da casa'), isTrue);
      expect(mostrou('Confira os dados:'), isTrue);
      expect(mostrou('Nascimento: 15/08/1950'), isTrue);
      expect(mostrou('Telefone: (11) 95555-4444'), isTrue);
      expect(mostrou('José da Silva cadastrado(a) com sucesso!'), isTrue);
      expect(mostrou('Sem contato de emergência'), isTrue);

      expect(idoso?.id, 5);
      final jose = (await IdosoService(api).listar())
          .firstWhere((item) => item.nome == 'José da Silva');
      expect(jose.telefone, '11955554444');
      expect(jose.dataNascimento, DateTime(1950, 8, 15));
      expect(jose.status, StatusIdoso.offline);
      expect(jose.ultimaAtividade, isNull);
    });

    test('responder não ao salvar não grava nada', () async {
      final idoso = await cadastrarIdoso([...idosoValido, 'n', '']);

      expect(idoso, isNull);
      expect(mostrou('Cadastro cancelado. Nada foi salvo.'), isTrue);
      expect(await IdosoService(api).listar(), hasLength(3));
    });

    test('já emenda o cadastro do contato de emergência', () async {
      await cadastrarIdoso([
        ...idosoValido,
        's', // salvar idoso
        's', // cadastrar contato agora
        'Marta Silva', '11944443333', '1', '1', // nome, tel, Filho(a), ordem 1
        's', // salvar contato
        '', // Enter
      ]);

      expect(mostrou('NOVO CONTATO DE JOSÉ DA SILVA'), isTrue);
      expect(mostrou('Contato Marta Silva salvo. Será o 1º a ser avisado.'),
          isTrue);

      final contatos = await IdosoService(api).listarContatos(5);
      expect(contatos.single.nome, 'Marta Silva');
      expect(contatos.single.parentesco, 'Filho(a)');
    });

    test('a API recusa dados inválidos e a tela mostra cada campo', () async {
      try {
        await IdosoService(api).cadastrar(const Idoso(nome: '', telefone: '1'));
        fail('A API deveria recusar.');
      } on ApiException catch (erro) {
        mostrarErroDaApi(entradaFalsa([], saida), erro);
      }

      expect(mostrou('[ERRO] Dados inválidos.'), isTrue);
      expect(mostrou('- nome: obrigatório'), isTrue);
      expect(mostrou('- telefone: use DDD + número'), isTrue);
      expect(mostrou('- endereco: obrigatório'), isTrue);
      expect(mostrou('- dataNascimento:'), isTrue);
    });
  });

  group('Permissões', () {
    test('cuidador não vê a opção e a API recusa', () async {
      final sessao = await AuthService(api).login('carlos@email.com', '123456');

      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: IdosoService(api),
        alertaService: AlertaService(api),
        entrada: entradaFalsa(['0'], saida),
      ).exibir();
      expect(mostrou('Cadastrar idoso'), isFalse);

      await expectLater(
        IdosoService(api).cadastrar(Idoso(
          nome: 'Teste Silva',
          dataNascimento: DateTime(1950),
          telefone: '11955554444',
          endereco: 'Rua A, 1',
        )),
        throwsA(isA<NaoAutorizadoException>().having((e) => e.mensagem,
            'mensagem', 'Cuidadores não podem cadastrar idosos.')),
      );
    });

    test('familiar cadastra pelo menu e o resumo já conta o novo', () async {
      final sessao = await AuthService(api).login('ana@email.com', '123456');

      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: IdosoService(api),
        alertaService: AlertaService(api),
        entrada: entradaFalsa(['3', ...idosoValido, 's', 'n', '', '0'], saida),
      ).exibir();

      expect(mostrou('3) Cadastrar idoso'), isTrue);
      expect(mostrou('Você acompanha 4 idosos'), isTrue);
      expect(mostrou('sem sinal do dispositivo'), isTrue);
    });
  });

  group('Contatos no detalhe', () {
    test('mostra os contatos e cadastra um novo com parentesco "Outro"',
        () async {
      await abrirDetalhe(2, [
        '4', // cadastrar contato
        'Pedro Alves', '11922221111',
        '8', 'Porteiro', // Outro -> Qual?
        '9', '2', // ordem inválida, depois 2
        's', '', // salvar, Enter
        '0', // voltar
      ]);

      expect(mostrou('1º Ana Souza (Sobrinha) - (11) 99999-0001'), isTrue);
      expect(mostrou('Use um número de 1 a 5'), isTrue);
      expect(mostrou('Contato Pedro Alves salvo. Será o 2º a ser avisado.'),
          isTrue);
      expect(mostrou('2º Pedro Alves (Porteiro) - (11) 92222-1111'), isTrue);
    });

    test('cancelar no parentesco não grava nada', () async {
      final contato = await TelaCadastroContato(
        idosoId: 2,
        idosoNome: 'Seu João',
        idosoService: IdosoService(api),
        entrada: entradaFalsa(['Pedro Alves', '11922221111', '0', ''], saida),
      ).exibir();

      expect(contato, isNull);
      expect(mostrou('Cadastro cancelado. Nada foi salvo.'), isTrue);
      expect(await IdosoService(api).listarContatos(2), hasLength(1));
    });

    test('idoso recém-cadastrado avisa que falta contato e sinal', () async {
      await IdosoService(api).cadastrar(Idoso(
        nome: 'Teste Silva',
        dataNascimento: DateTime(1950),
        telefone: '11955554444',
        endereco: 'Rua A, 1',
      ));

      await abrirDetalhe(5, ['0']);

      expect(mostrou('Sem sinal do dispositivo'), isTrue);
      expect(mostrou('Última atividade: sem registro'), isTrue);
      expect(mostrou('Nenhum contato cadastrado.'), isTrue);
      expect(mostrou('Nenhum evento registrado hoje.'), isTrue);
    });
  });

  group('Fora de casa', () {
    test('liga a chave, o painel muda e a API guarda', () async {
      await abrirDetalhe(1, ['3', 's', '', '0']);

      expect(mostrou('3) Marcar como fora de casa'), isTrue);
      expect(mostrou('Pronto! Agora: Fora de casa.'), isTrue);
      expect(mostrou('3) Marcar que voltou para casa'), isTrue);
      expect(mostrou('alertas de falta de atividade estão pausados'), isTrue);

      final maria = (await IdosoService(api).listar())
          .firstWhere((idoso) => idoso.id == 1);
      expect(maria.estaAusente, isTrue);
    });

    test('responder não deixa como estava', () async {
      await abrirDetalhe(1, ['3', 'n', '', '0']);

      expect(mostrou('Nada foi alterado.'), isTrue);
      final maria = (await IdosoService(api).listar())
          .firstWhere((idoso) => idoso.id == 1);
      expect(maria.estaAusente, isFalse);
    });

    test('quem está fora pode voltar', () async {
      // Seu Antônio começa "fora de casa"; Carlos é o cuidador dele.
      await AuthService(api).login('carlos@email.com', '123456');

      await abrirDetalhe(4, ['3', 's', '', '0']);

      expect(mostrou('Confirmar que Seu Antônio voltou para casa?'), isTrue);
      expect(mostrou('Pronto! Agora: Em casa.'), isTrue);
    });
  });
}
