import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import '../tool/api_fake.dart';
import 'apoio/entrada_falsa.dart';

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

  /// Linhas da última vez que a lista de alertas foi desenhada.
  List<String> ultimaTela() =>
      saida.sublist(saida.lastIndexWhere((linha) => linha.contains('Filtro:')));

  Future<void> abrirAlertas(List<String> respostas, {int? idosoId}) =>
      TelaAlertas(
        alertaService: AlertaService(api),
        entrada: entradaFalsa(respostas, saida),
        idosoId: idosoId,
      ).exibir();

  group('TelaAlertas', () {
    test('mostra os abertos, do mais grave ao mais leve, com o contador',
        () async {
      await abrirAlertas(['0']);

      expect(mostrou('Filtro: Abertos | Nível: todos'), isTrue);
      expect(mostrou('Alertas abertos: 3'), isTrue);
      expect(mostrou('1) [ CRÍTICO ] Dona Lurdes - Pessoa parada'), isTrue);
      expect(mostrou('2) [ ATENÇÃO ] Seu João - Sem atividade'), isTrue);
      expect(mostrou('3) [ ATENÇÃO ] Dona Lurdes - Calor perigoso'), isTrue);
      expect(mostrou('Escalonado: 2º contato avisado'), isTrue);
      expect(mostrou('Dona Maria'), isFalse);
    });

    test('confirmar atualiza o contador na hora e o status do idoso na API',
        () async {
      // 1 = confirmar · 1 = primeiro alerta · s = sim · Enter · 0 = voltar
      await abrirAlertas(['1', '1', 's', '', '0']);

      expect(mostrou('Alerta confirmado. Alertas abertos: 3 → 2'), isTrue);
      expect(ultimaTela(), contains('Alertas abertos: 2'));
      expect(
        ultimaTela().any((linha) => linha.contains('Pessoa parada')),
        isFalse,
      );

      final lurdes = (await IdosoService(api).listar())
          .firstWhere((idoso) => idoso.nome == 'Dona Lurdes');
      expect(lurdes.alertasAbertos, 1);
      expect(lurdes.status, StatusIdoso.atencao);
    });

    test('responder não deixa tudo como estava', () async {
      await abrirAlertas(['1', '1', 'n', '', '0']);

      expect(mostrou('Nada foi alterado.'), isTrue);
      expect(mostrou('→'), isFalse);

      final alertas = await AlertaService(api).listar();
      expect(alertas.where((alerta) => alerta.estaAberto).length, 3);
    });

    test('alerta já confirmado não pode ser escolhido', () async {
      // 2 = filtrar status · 3 = Todos · 1 = confirmar · 4 = alerta resolvido
      // 0 = cancelar · 0 = voltar
      await abrirAlertas(['2', '3', '1', '4', '0', '0']);

      expect(mostrou('Filtro: Todos'), isTrue);
      expect(mostrou('4) [ ALERTA ] Dona Maria - Levantou muitas vezes'),
          isTrue);
      expect(mostrou('Confirmado:'), isTrue);
      expect(mostrou('Esse alerta já foi confirmado.'), isTrue);
      expect(mostrou('Alerta confirmado'), isFalse);
    });

    test('filtro por nível mostra só os críticos', () async {
      // 3 = filtrar nível · 2 = Crítico · 0 = voltar
      await abrirAlertas(['3', '2', '0']);

      final tela = ultimaTela();
      expect(tela.first, 'Filtro: Abertos | Nível: Crítico');
      expect(tela.any((linha) => linha.contains('Pessoa parada')), isTrue);
      expect(tela.any((linha) => linha.contains('Sem atividade')), isFalse);
      // O contador continua contando todos os abertos, não só os filtrados.
      expect(tela, contains('Alertas abertos: 3'));
    });

    test('alertas de um idoso só', () async {
      await abrirAlertas(['0'], idosoId: 2);

      expect(mostrou('Seu João - Sem atividade'), isTrue);
      expect(mostrou('Dona Lurdes'), isFalse);
      expect(mostrou('Alertas abertos: 1'), isTrue);
    });

    test('sem alertas abertos avisa ao tentar confirmar', () async {
      await abrirAlertas(['1', '', '0'], idosoId: 1);

      expect(mostrou('Alertas abertos: 0'), isTrue);
      expect(mostrou('Nenhum alerta com esse filtro.'), isTrue);
      expect(mostrou('Não há alertas abertos para confirmar.'), isTrue);
    });
  });

  group('Navegação até os alertas', () {
    test('pelo detalhe do idoso, e o painel volta atualizado', () async {
      // 2 = ver alertas · 1 = confirmar · 1 = primeiro · s · Enter
      // 0 = voltar dos alertas · 0 = voltar do detalhe
      await TelaDetalheIdoso(
        idosoId: 3,
        idosoService: IdosoService(api),
        alertaService: AlertaService(api),
        entrada: entradaFalsa(['2', '1', '1', 's', '', '0', '0'], saida),
      ).exibir();

      expect(mostrou('2) Ver alertas (2 abertos)'), isTrue);
      expect(mostrou('ALERTAS DE DONA LURDES'), isTrue);
      expect(mostrou('Alertas abertos: 2 → 1'), isTrue);
      expect(mostrou('2) Ver alertas (1 aberto)'), isTrue);
    });

    test('pelo menu principal', () async {
      final sessao = await AuthService(api).login('ana@email.com', '123456');

      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: IdosoService(api),
        alertaService: AlertaService(api),
        entrada: entradaFalsa(['2', '0', '0'], saida),
      ).exibir();

      expect(mostrou('2) Alertas (3 abertos)'), isTrue);
      expect(mostrou('Filtro: Abertos'), isTrue);
    });
  });

  group('Regras da API falsa', () {
    test('confirmar duas vezes dá erro', () async {
      final servico = AlertaService(api);
      await servico.confirmar(3);

      await expectLater(
        servico.confirmar(3),
        throwsA(isA<ApiException>().having(
            (e) => e.mensagem, 'mensagem', 'Este alerta já foi confirmado.')),
      );
    });

    test('não dá para confirmar alerta de outra família', () async {
      await expectLater(
        AlertaService(api).confirmar(5),
        throwsA(isA<ApiException>()
            .having((e) => e.mensagem, 'mensagem', 'Alerta não encontrado.')),
      );
    });

    test('filtros enviados para a API', () async {
      final resolvidos =
          await AlertaService(api).listar(status: StatusAlerta.resolvido);
      expect(resolvidos.map((alerta) => alerta.idosoNome), ['Dona Maria']);

      final criticos =
          await AlertaService(api).listar(nivel: NivelAlerta.critico);
      expect(criticos.single.tipo, 'PESSOA_PARADA');
    });
  });
}
