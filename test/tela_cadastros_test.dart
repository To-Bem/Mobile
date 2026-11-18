import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import 'apoio/api_java_falsa.dart';
import 'apoio/entrada_falsa.dart';

/// Respostas válidas para o formulário de idoso, na ordem dos campos,
/// terminando com o parentesco (1 = Filho(a)).
const List<String> idosoValido = [
  'José da Silva',
  '15/08/1950',
  '(11) 95555-4444',
  'Rua das Acácias, 77',
  '1',
];

void main() {
  late ApiJavaFalsa javaFalsa;
  late ApiClient api;
  late List<String> saida;
  late IdosoService idosos;
  late AlertaService alertas;

  setUp(() async {
    Terminal.usarCores = false;
    javaFalsa = await ApiJavaFalsa.iniciar();
    api = ApiClient(baseUrl: javaFalsa.url);
    saida = <String>[];
    final sessao = await AuthService(api).login('ana@email.com', 'Senha12345');
    idosos = IdosoService(api, sessao);
    alertas = AlertaService(api, idosos);
  });

  tearDown(() async {
    api.fechar();
    await javaFalsa.fechar();
  });

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  Future<Idoso?> cadastrarIdoso(List<String> respostas) => TelaCadastroIdoso(
    idosoService: idosos,
    entrada: entradaFalsa(respostas, saida),
  ).exibir();

  Future<void> abrirDetalhe(int idosoId, List<String> respostas) =>
      TelaDetalheIdoso(
        idosoId: idosoId,
        idosoService: idosos,
        alertaService: alertas,
        entrada: entradaFalsa(respostas, saida),
      ).exibir();

  group('Cadastro de idoso', () {
    test('valida cada campo, mostra o resumo e salva na API', () async {
      final idoso = await cadastrarIdoso([
        'Jo', 'José da Silva', //
        '31/02/1950', '12/03/2000', '15/08/1950', //
        '123', '(11) 95555-4444', //
        'Rua das Acácias', 'Rua das Acácias, 77', //
        '1', // Filho(a)
        's', // salvar
        'n', // não cadastrar a lâmpada agora
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
      expect(mostrou('Sua relação: Filho(a)'), isTrue);
      expect(mostrou('José da Silva cadastrado(a) com sucesso!'), isTrue);
      expect(mostrou('Sem dispositivo cadastrado'), isTrue);

      expect(idoso?.id, isNotNull);
      expect(javaFalsa.rotasChamadas, contains('POST /api/usuarios/2/idoso'));
      final contato = javaFalsa.dados.contatos.last;
      expect(contato.idosoId, idoso?.id);
      expect(contato.parentesco, 'Filho(a)');

      final jose = (await idosos.listar()).firstWhere(
        (item) => item.nome == 'José da Silva',
      );
      expect(jose.telefone, '11955554444');
      expect(jose.dataNascimento, DateTime(1950, 8, 15));
      expect(jose.status, StatusIdoso.offline); // ainda sem dispositivo
      expect(jose.ultimaAtividade, isNull);
    });

    test('parentesco "Outro" pede o texto', () async {
      await cadastrarIdoso([
        ...idosoValido.take(4),
        '8', // Outro
        'Afilhado',
        's',
        'n',
        '',
      ]);

      expect(javaFalsa.dados.contatos.last.parentesco, 'Afilhado');
    });

    test('responder não ao salvar não grava nada', () async {
      final idoso = await cadastrarIdoso([...idosoValido, 'n', '']);

      expect(idoso, isNull);
      expect(mostrou('Cadastro cancelado. Nada foi salvo.'), isTrue);
      expect(await idosos.listar(), hasLength(3));
    });

    test('já emenda o cadastro da lâmpada', () async {
      final idoso = await cadastrarIdoso([
        ...idosoValido,
        's', // salvar idoso
        's', // cadastrar a lâmpada agora
        '1', // Lâmpada
        '2', // Quarto
        's', // salvar
        '', // Enter
      ]);

      expect(mostrou('NOVO DISPOSITIVO DE JOSÉ DA SILVA'), isTrue);
      expect(mostrou('Lâmpada (Quarto) cadastrado(a) com o número'), isTrue);
      expect(mostrou('DISPOSITIVO_ID'), isTrue);

      final painel = await idosos.painel(idoso!.id!);
      expect(painel.dispositivos.single.comodo, 'Quarto');
      // Lâmpada recém-cadastrada: a API registra o heartbeat na hora.
      expect(painel.idoso.status, StatusIdoso.ok);
    });

    test('a API recusa dados inválidos e a tela mostra cada campo', () async {
      try {
        await idosos.cadastrar(
          const Idoso(nome: '', telefone: '1'),
          parentesco: 'Filho(a)',
        );
        fail('A API deveria recusar.');
      } on ApiException catch (erro) {
        mostrarErroDaApi(entradaFalsa([], saida), erro);
      }

      expect(mostrou('[ERRO] Dados inválidos. Confira os campos:'), isTrue);
      expect(mostrou('- nome: nome não pode ser vazio'), isTrue);
      expect(mostrou('- dataNascimento: dataNascimento é obrigatorio'), isTrue);
      expect(mostrou('- endereco: endereco não pode ser vazio'), isTrue);
    });
  });

  group('Cadastro de dispositivo e rotina pelo detalhe', () {
    test('cômodo "Outro" é validado', () async {
      // 3 = cadastrar dispositivo · 2 = Base · 6 = Outro · "Ab" (curto)
      // "Lavanderia" · s · Enter · 0 = voltar do detalhe
      await abrirDetalhe(2, [
        '3',
        '2',
        '6',
        'Ab',
        'Lavanderia',
        's',
        '',
        '0',
      ]);

      expect(mostrou('Nome do cômodo muito curto.'), isTrue);
      expect(mostrou('Base (Lavanderia) cadastrado(a)'), isTrue);
      // O painel recarregado já mostra o novo dispositivo.
      expect(mostrou('Base (Lavanderia) [ ONLINE ]'), isTrue);
      expect(javaFalsa.dados.dispositivos.last.tipo, 'BASE');
    });

    test('cancelar o dispositivo não grava nada', () async {
      await abrirDetalhe(2, ['3', '0', '', '0']);

      expect(mostrou('Cadastro cancelado. Nada foi salvo.'), isTrue);
      expect(javaFalsa.dados.dispositivos, hasLength(4));
    });

    test('rotina valida horário e quantidade', () async {
      // 4 = cadastrar rotina · 2 = Segunda · horários · levantadas · s · Enter
      // 0 = voltar do detalhe
      await abrirDetalhe(2, [
        '4',
        '2',
        '25:00',
        '6:45',
        '11',
        '1',
        's',
        '',
        '0',
      ]);

      expect(mostrou('Horário inválido'), isTrue);
      expect(mostrou('Digite um número de 0 a 10.'), isTrue);
      expect(mostrou('Rotina salva: Segunda-feira, acorda às 06:45.'), isTrue);
      expect(mostrou('Segunda-feira: acorda às 06:45 | 1 levantada'), isTrue);

      final rotina = javaFalsa.dados.rotinas.last;
      expect(rotina.diaSemana, 'SEGUNDA');
      expect(rotina.hora, '06:45:00');
      expect(rotina.media, 1);
    });
  });
}
