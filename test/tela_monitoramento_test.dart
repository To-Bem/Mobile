import 'dart:io';
import 'dart:math';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import '../tool/api_fake.dart';
import 'apoio/entrada_falsa.dart';

/// IdosoService que devolve uma lista diferente a cada consulta, seguindo
/// um roteiro. Um passo do roteiro pode ser um erro (ApiException).
/// Quando o roteiro acaba, repete o último passo.
class IdosoServiceRoteirizado extends IdosoService {
  IdosoServiceRoteirizado(this.roteiro)
      : super(ApiClient(baseUrl: 'http://127.0.0.1:9'));

  final List<Object> roteiro;
  int _passo = 0;

  @override
  Future<List<Idoso>> listar() async {
    final passo = roteiro[min(_passo, roteiro.length - 1)];
    _passo++;
    if (passo is ApiException) throw passo;
    return passo as List<Idoso>;
  }
}

const Idoso maria = Idoso(id: 1, nome: 'Dona Maria', status: StatusIdoso.ok);
const Idoso joao = Idoso(
  id: 2,
  nome: 'Seu João',
  status: StatusIdoso.atencao,
  alertasAbertos: 1,
);

void main() {
  late List<String> saida;

  setUp(() {
    Terminal.usarCores = false;
    saida = <String>[];
  });

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  test('mostra a situação, as mudanças, a falha e o resumo final', () async {
    final roteiro = <Object>[
      [maria, joao], // situação inicial
      [maria, joao], // sem mudanças
      const SemConexaoException('Não foi possível conectar à API.'),
      [
        maria.copyWith(status: StatusIdoso.critico, alertasAbertos: 1),
        joao.copyWith(modo: ModoIdoso.ausente),
      ],
    ];

    await TelaMonitoramento(
      monitor: MonitorService(
        IdosoServiceRoteirizado(roteiro),
        intervalo: const Duration(milliseconds: 1),
      ),
      entrada: entradaFalsa(['abc', '1', ''], saida),
      // "1 minuto" = 3 ms -> 4 verificações com intervalo de 1 ms.
      duracaoDeUmMinuto: const Duration(milliseconds: 3),
    ).exibir();

    expect(mostrou('Digite um número de 1 a 30.'), isTrue);
    expect(mostrou('Monitorando por 1 min (4 verificações)'), isTrue);

    expect(mostrou('Situação inicial:'), isTrue);
    expect(mostrou('[ ATENÇÃO ] Seu João (1 alerta aberto)'), isTrue);
    expect(mostrou('[ OK ] Dona Maria'), isTrue);

    expect(mostrou('sem mudanças'), isTrue);
    expect(mostrou('[ERRO]'), isTrue);
    expect(mostrou('Tentando de novo...'), isTrue);
    expect(mostrou('Conexão restabelecida.'), isTrue);

    expect(mostrou('[!]'), isTrue);
    expect(mostrou('Dona Maria: Tudo bem → Crítico | +1 alerta'), isTrue);
    expect(mostrou('Seu João: saiu de casa'), isTrue);

    expect(
      mostrou('Monitoramento encerrado: 4 verificações, 2 mudanças, 1 falha.'),
      isTrue,
    );
  });

  test('melhora não vira aviso amarelo', () async {
    await TelaMonitoramento(
      monitor: MonitorService(
        IdosoServiceRoteirizado([
          [joao],
          [joao.copyWith(status: StatusIdoso.ok, alertasAbertos: 0)],
        ]),
        intervalo: const Duration(milliseconds: 1),
      ),
      entrada: entradaFalsa(['1', ''], saida),
      duracaoDeUmMinuto: const Duration(milliseconds: 1),
    ).exibir();

    final linha =
        saida.firstWhere((linha) => linha.contains('Seu João: Atenção → Tudo bem'));
    expect(linha.contains('[!]'), isFalse);
    expect(mostrou('1 mudança, 0 falhas'), isTrue);
  });

  group('Menu', () {
    late HttpServer apiFalsa;
    late ApiClient api;

    setUp(() async {
      apiFalsa = await iniciarApiFalsa(porta: 0, registrarLog: false);
      api = ApiClient(baseUrl: 'http://127.0.0.1:${apiFalsa.port}');
    });

    tearDown(() async {
      api.fechar();
      await apiFalsa.close(force: true);
    });

    Future<void> abrirMenuComo(String email) async {
      final sessao = await AuthService(api).login(email, '123456');
      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: IdosoService(api),
        alertaService: AlertaService(api),
        entrada: entradaFalsa(['0'], saida),
      ).exibir();
    }

    test('familiar: monitoramento é a opção 4', () async {
      await abrirMenuComo('ana@email.com');
      expect(mostrou('3) Cadastrar idoso'), isTrue);
      expect(mostrou('4) Monitoramento ao vivo'), isTrue);
    });

    test('cuidador: sem cadastro, monitoramento vira a opção 3', () async {
      await abrirMenuComo('carlos@email.com');
      expect(mostrou('Cadastrar idoso'), isFalse);
      expect(mostrou('3) Monitoramento ao vivo'), isTrue);
    });
  });
}
