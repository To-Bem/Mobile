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
    apiFalsa = await iniciarApiFalsa(porta: 0, registrarLog: false);
    api = ApiClient(baseUrl: 'http://127.0.0.1:${apiFalsa.port}');
    saida = <String>[];
  });

  tearDown(() async {
    api.fechar();
    await apiFalsa.close(force: true);
  });

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  test('e-mail inválido pede de novo e depois entra', () async {
    final entrada = entradaFalsa(['ana@', 'ana@email.com', '123456'], saida);

    final sessao = await TelaLogin(AuthService(api), entrada).exibir();

    expect(sessao?.usuario.nome, 'Ana Souza');
    expect(sessao?.usuario.papel, Papel.familiar);
    expect(api.token, 'token-falso-1');
    expect(mostrou('E-mail inválido'), isTrue);
    expect(mostrou('Bem-vindo(a), Ana Souza!'), isTrue);
  });

  test('três senhas erradas encerram o login', () async {
    final entrada = entradaFalsa([
      'ana@email.com', 'errada1', //
      'ana@email.com', 'errada2', //
      'ana@email.com', 'errada3',
    ], saida);

    final sessao = await TelaLogin(AuthService(api), entrada).exibir();

    expect(sessao, isNull);
    expect(mostrou('E-mail ou senha inválidos.'), isTrue);
    expect(mostrou('Tentativas restantes: 2'), isTrue);
    expect(mostrou('Tentativas restantes: 1'), isTrue);
    expect(mostrou('Número máximo de tentativas atingido.'), isTrue);
  });

  test('API fora do ar mostra o erro e não insiste', () async {
    final temporario = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final semServidor =
        ApiClient(baseUrl: 'http://127.0.0.1:${temporario.port}');
    await temporario.close(force: true);
    final entrada = entradaFalsa(['ana@email.com', '123456'], saida);

    final sessao = await TelaLogin(AuthService(semServidor), entrada).exibir();
    semServidor.fechar();

    expect(sessao, isNull);
    expect(mostrou('Não foi possível conectar à API'), isTrue);
  });
}
