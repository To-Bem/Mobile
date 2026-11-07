import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import '../tool/api_fake.dart';

const Idoso maria = Idoso(id: 1, nome: 'Dona Maria', status: StatusIdoso.ok);
const Idoso joao = Idoso(
  id: 2,
  nome: 'Seu João',
  status: StatusIdoso.atencao,
  alertasAbertos: 1,
);

void main() {
  group('compararLeituras', () {
    test('sem mudanças devolve lista vazia', () {
      expect(compararLeituras([maria, joao], [maria, joao]), isEmpty);
    });

    test('status que piora, com alerta novo', () {
      final mudancas = compararLeituras(
        [maria, joao],
        [maria.copyWith(status: StatusIdoso.critico, alertasAbertos: 1), joao],
      );

      final mudanca = mudancas.single;
      expect(mudanca.atual.nome, 'Dona Maria');
      expect(mudanca.statusMudou, isTrue);
      expect(mudanca.piorou, isTrue);
      expect(mudanca.novosAlertas, 1);
    });

    test('status que melhora não é piora', () {
      final mudanca = compararLeituras(
        [joao],
        [joao.copyWith(status: StatusIdoso.ok, alertasAbertos: 0)],
      ).single;

      expect(mudanca.piorou, isFalse);
      expect(mudanca.novosAlertas, 0);
    });

    test('mudança de modo conta como mudança', () {
      final mudanca = compararLeituras(
        [maria],
        [maria.copyWith(modo: ModoIdoso.ausente)],
      ).single;

      expect(mudanca.modoMudou, isTrue);
      expect(mudanca.statusMudou, isFalse);
    });

    test('idoso novo na segunda leitura é ignorado', () {
      expect(compararLeituras([maria], [maria, joao]), isEmpty);
    });
  });

  test('gravidadeDoStatus: crítico é o mais grave', () {
    final ordem = [...StatusIdoso.values]
      ..sort((a, b) => gravidadeDoStatus(b).compareTo(gravidadeDoStatus(a)));
    expect(ordem.first, StatusIdoso.critico);
    expect(ordem.last, StatusIdoso.ok);
  });

  group('MonitorService', () {
    late HttpServer apiFalsa;
    late ApiClient api;

    setUp(() async {
      apiFalsa = await iniciarApiFalsa(porta: 0, registrarLog: false);
      api = ApiClient(baseUrl: 'http://127.0.0.1:${apiFalsa.port}');
      await AuthService(api).login('ana@email.com', '123456');
    });

    tearDown(() async {
      api.fechar();
      await apiFalsa.close(force: true);
    });

    test('leiturasPara conta a primeira consulta, que é imediata', () {
      final monitor = MonitorService(
        IdosoService(api),
        intervalo: const Duration(seconds: 10),
      );
      expect(monitor.leiturasPara(const Duration(minutes: 2)), 13);
    });

    test('intervalo zero não é aceito', () {
      expect(
        () => MonitorService(IdosoService(api), intervalo: Duration.zero),
        throwsArgumentError,
      );
    });

    test('o Stream entrega a mudança feita entre duas consultas', () async {
      final monitor = MonitorService(
        IdosoService(api),
        intervalo: const Duration(milliseconds: 10),
      );
      final leituras = <LeituraMonitor>[];

      await for (final leitura in monitor.leituras(2)) {
        leituras.add(leitura);
        if (leituras.length == 1) {
          // Enquanto o monitor espera, o "sensor" detecta uma queda.
          await api.post('/simulador/queda/1', null);
        }
      }

      expect(leituras, hasLength(2));
      final antes = (leituras[0] as LeituraOk).idosos;
      final depois = (leituras[1] as LeituraOk).idosos;
      final mudanca = compararLeituras(antes, depois).single;
      expect(mudanca.atual.nome, 'Dona Maria');
      expect(mudanca.anterior.status, StatusIdoso.ok);
      expect(mudanca.atual.status, StatusIdoso.critico);
    });

    test('API fora do ar vira LeituraFalhou e o Stream continua', () async {
      final temporario =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final semServidor =
          ApiClient(baseUrl: 'http://127.0.0.1:${temporario.port}');
      await temporario.close(force: true);

      final monitor = MonitorService(
        IdosoService(semServidor),
        intervalo: const Duration(milliseconds: 10),
      );
      final leituras = await monitor.leituras(2).toList();
      semServidor.fechar();

      expect(leituras, hasLength(2));
      expect(leituras, everyElement(isA<LeituraFalhou>()));
    });
  });

  group('Simulador da API falsa', () {
    late HttpServer apiFalsa;
    late ApiClient api;

    setUp(() async {
      apiFalsa = await iniciarApiFalsa(porta: 0, registrarLog: false);
      api = ApiClient(baseUrl: 'http://127.0.0.1:${apiFalsa.port}');
      await AuthService(api).login('ana@email.com', '123456');
    });

    tearDown(() async {
      api.fechar();
      await apiFalsa.close(force: true);
    });

    test('saiu e voltou mudam o modo', () async {
      await api.post('/simulador/saiu/1', null);
      var maria = (await IdosoService(api).listar()).first;
      expect(maria.estaAusente, isTrue);

      await api.post('/simulador/voltou/1', null);
      maria = (await IdosoService(api).listar()).first;
      expect(maria.estaAusente, isFalse);
    });

    test('calor cria um alerta de atenção recente', () async {
      await api.post('/simulador/calor/2', null);

      final alertas = await AlertaService(api).listar(idosoId: 2);
      expect(alertas.first.tipo, 'CALOR');
      expect(alertas.first.nivel, NivelAlerta.atencao);
      expect(alertas.where((alerta) => alerta.estaAberto), hasLength(2));
    });

    test('idoso inexistente dá 404', () async {
      await expectLater(
        api.post('/simulador/queda/99', null),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
