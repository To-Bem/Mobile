import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import 'apoio/api_java_falsa.dart';

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
    late ApiJavaFalsa javaFalsa;
    late ApiClient api;
    late Sessao sessao;

    setUp(() async {
      javaFalsa = await ApiJavaFalsa.iniciar();
      api = ApiClient(baseUrl: javaFalsa.url);
      sessao = await AuthService(api).login('ana@email.com', 'Senha12345');
    });

    tearDown(() async {
      api.fechar();
      await javaFalsa.fechar();
    });

    test('leiturasPara conta a primeira consulta, que é imediata', () {
      final monitor = MonitorService(
        IdosoService(api, sessao),
        intervalo: const Duration(seconds: 10),
      );
      expect(monitor.leiturasPara(const Duration(minutes: 2)), 13);
    });

    test('intervalo zero não é aceito', () {
      expect(
        () => MonitorService(IdosoService(api, sessao), intervalo: Duration.zero),
        throwsArgumentError,
      );
    });

    test('o Stream entrega a mudança feita entre duas consultas', () async {
      final monitor = MonitorService(
        IdosoService(api, sessao),
        intervalo: const Duration(milliseconds: 10),
      );
      final leituras = <LeituraMonitor>[];

      await for (final leitura in monitor.leituras(2)) {
        leituras.add(leitura);
        if (leituras.length == 1) {
          // Enquanto o monitor espera, a lâmpada da Dona Maria detecta
          // uma possível queda e a API abre um alerta crítico.
          javaFalsa.dados.abrirAlerta(1, 'QUEDA', 'CRITICO');
        }
      }

      expect(leituras, hasLength(2));
      final antes = (leituras[0] as LeituraOk).idosos;
      final depois = (leituras[1] as LeituraOk).idosos;
      final mudanca = compararLeituras(antes, depois).single;
      expect(mudanca.atual.nome, 'Dona Maria');
      expect(mudanca.anterior.status, StatusIdoso.ok);
      expect(mudanca.atual.status, StatusIdoso.critico);
      expect(mudanca.novosAlertas, 1);
    });

    test('API fora do ar vira LeituraFalhou e o Stream continua', () async {
      final temporario = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final semServidor = ApiClient(
        baseUrl: 'http://127.0.0.1:${temporario.port}',
      );
      await temporario.close(force: true);

      final monitor = MonitorService(
        IdosoService(semServidor, sessao),
        intervalo: const Duration(milliseconds: 10),
      );
      final leituras = await monitor.leituras(2).toList();
      semServidor.fechar();

      expect(leituras, hasLength(2));
      expect(leituras, everyElement(isA<LeituraFalhou>()));
    });
  });
}
