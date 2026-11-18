import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import 'apoio/api_java_falsa.dart';
import 'apoio/entrada_falsa.dart';

void main() {
  late ApiJavaFalsa javaFalsa;
  late ApiClient api;
  late List<String> saida;
  late Sessao sessao;
  late IdosoService idosos;
  late AlertaService alertas;

  setUp(() async {
    Terminal.usarCores = false;
    javaFalsa = await ApiJavaFalsa.iniciar();
    api = ApiClient(baseUrl: javaFalsa.url);
    saida = <String>[];
    sessao = await AuthService(api).login('ana@email.com', 'Senha12345');
    idosos = IdosoService(api, sessao);
    alertas = AlertaService(api, idosos);
  });

  tearDown(() async {
    api.fechar();
    await javaFalsa.fechar();
  });

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  /// Linhas da última vez que a lista de alertas foi desenhada.
  List<String> ultimaTela() =>
      saida.sublist(saida.lastIndexWhere((linha) => linha.contains('Filtro:')));

  Future<void> abrirAlertas(List<String> respostas, {int? idosoId}) =>
      TelaAlertas(
        alertaService: alertas,
        entrada: entradaFalsa(respostas, saida),
        idosoId: idosoId,
      ).exibir();

  group('TelaAlertas', () {
    test('mostra os abertos, do mais grave ao mais leve, com o contador',
        () async {
      await abrirAlertas(['0']);

      expect(mostrou('Filtro: Abertos | Nível: todos'), isTrue);
      expect(mostrou('Alertas abertos: 2'), isTrue);
      expect(mostrou('1) [ CRÍTICO ] Dona Lurdes - Possível queda'), isTrue);
      expect(
        mostrou('2) [ ATENÇÃO ] Seu João - Sem movimento fora da rotina'),
        isTrue,
      );
      expect(mostrou('Escalonado: 2º contato avisado'), isTrue);
      expect(mostrou('Aberto: 1º contato avisado'), isTrue);
      expect(mostrou('Dona Maria'), isFalse);
    });

    test('confirmar atualiza o contador na hora e a situação na API',
        () async {
      // 1 = confirmar · 1 = primeiro alerta · s = sim · Enter · 0 = voltar
      await abrirAlertas(['1', '1', 's', '', '0']);

      expect(mostrou('Alerta confirmado. Alertas abertos: 2 → 1'), isTrue);
      expect(ultimaTela(), contains('Alertas abertos: 1'));
      expect(
        ultimaTela().any((linha) => linha.contains('Possível queda')),
        isFalse,
      );
      expect(javaFalsa.rotasChamadas, contains('PUT /api/alertas/3'));

      final lurdes = (await idosos.listar()).firstWhere(
        (idoso) => idoso.nome == 'Dona Lurdes',
      );
      expect(lurdes.alertasAbertos, 0);
      expect(lurdes.status, StatusIdoso.ok);
    });

    test('responder não deixa tudo como estava', () async {
      await abrirAlertas(['1', '1', 'n', '', '0']);

      expect(mostrou('Nada foi alterado.'), isTrue);
      expect(mostrou('→'), isFalse);
      expect(javaFalsa.rotasChamadas.where((r) => r.startsWith('PUT')), isEmpty);
    });

    test('alerta já confirmado não pode ser escolhido', () async {
      // 2 = filtrar status · 3 = Todos · 1 = confirmar · 3 = alerta resolvido
      // 0 = cancelar · 0 = voltar
      await abrirAlertas(['2', '3', '1', '3', '0', '0']);

      expect(mostrou('Filtro: Todos'), isTrue);
      expect(
        mostrou('3) [ ATENÇÃO ] Dona Maria - Calor perigoso dentro de casa'),
        isTrue,
      );
      expect(mostrou('Confirmado'), isTrue);
      expect(mostrou('Esse alerta já foi confirmado.'), isTrue);
      expect(mostrou('Alerta confirmado'), isFalse);
    });

    test('filtro por nível mostra só os críticos', () async {
      // 3 = filtrar nível · 2 = Crítico · 0 = voltar
      await abrirAlertas(['3', '2', '0']);

      final tela = ultimaTela();
      expect(tela.first, 'Filtro: Abertos | Nível: Crítico');
      expect(tela.any((linha) => linha.contains('Possível queda')), isTrue);
      expect(tela.any((linha) => linha.contains('Sem movimento')), isFalse);
      // O contador continua contando todos os abertos, não só os filtrados.
      expect(tela, contains('Alertas abertos: 2'));
    });

    test('alertas de um idoso só', () async {
      await abrirAlertas(['0'], idosoId: 2);

      expect(mostrou('Seu João - Sem movimento'), isTrue);
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
        idosoService: idosos,
        alertaService: alertas,
        entrada: entradaFalsa(['2', '1', '1', 's', '', '0', '0'], saida),
      ).exibir();

      expect(mostrou('2) Ver alertas (1 aberto)'), isTrue);
      expect(mostrou('ALERTAS DE DONA LURDES'), isTrue);
      expect(mostrou('Alertas abertos: 1 → 0'), isTrue);
      expect(mostrou('2) Ver alertas (nenhum aberto)'), isTrue);
    });

    test('pelo menu principal', () async {
      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: idosos,
        alertaService: alertas,
        entrada: entradaFalsa(['2', '0', '0'], saida),
      ).exibir();

      expect(mostrou('2) Alertas (2 abertos)'), isTrue);
      expect(mostrou('Filtro: Abertos'), isTrue);
    });
  });

  group('Regras da API', () {
    test('MEMBER não confirma alerta de idoso que não acompanha', () async {
      final carlos = await AuthService(
        api,
      ).login('carlos@email.com', 'Senha12345');
      final servico = AlertaService(api, IdosoService(api, carlos));
      final daMaria = Alerta(
        id: 1,
        idosoId: 1,
        tipo: 'TEMPERATURA_ALTA',
        nivel: NivelAlerta.atencao,
        status: StatusAlerta.aberto,
        criadoEm: DateTime.now(),
      );

      await expectLater(
        servico.confirmar(daMaria),
        throwsA(isA<NaoAutorizadoException>()),
      );
    });

    test('ADMIN lista todos os alertas pela rota geral', () async {
      final admin = await AuthService(api).login('admin@tobem.com', 'Admin@12345');
      final todos = await AlertaService(api, IdosoService(api, admin)).listar();

      expect(todos, hasLength(3));
      expect(javaFalsa.rotasChamadas, contains('GET /api/alertas'));
    });
  });
}
