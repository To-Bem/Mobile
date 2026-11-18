import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import 'apoio/api_java_falsa.dart';
import 'apoio/entrada_falsa.dart';

void main() {
  late ApiJavaFalsa javaFalsa;
  late ApiClient api;
  late List<String> saida;

  setUp(() async {
    Terminal.usarCores = false;
    javaFalsa = await ApiJavaFalsa.iniciar();
    api = ApiClient(baseUrl: javaFalsa.url);
    saida = <String>[];
  });

  tearDown(() async {
    api.fechar();
    await javaFalsa.fechar();
  });

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  test('e-mail inválido pede de novo e depois entra', () async {
    // 1 = Entrar
    final entrada = entradaFalsa([
      '1',
      'ana@',
      'ana@email.com',
      'Senha12345',
    ], saida);

    final sessao = await TelaLogin(AuthService(api), entrada).exibir();

    expect(sessao?.usuario.nome, 'Ana Souza');
    expect(sessao?.perfil, Perfil.member);
    expect(api.token, 'token-falso-2');
    expect(mostrou('E-mail inválido'), isTrue);
    expect(mostrou('Bem-vindo(a), Ana Souza! (Familiar/cuidador)'), isTrue);
  });

  test('três senhas erradas encerram o login', () async {
    final entrada = entradaFalsa([
      '1',
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

  test('criar conta valida a senha, confere a repetição e já entra', () async {
    // 2 = Criar conta
    final entrada = entradaFalsa([
      '2',
      'Bia Nova',
      'bia@email.com',
      'curta', // menos de 8 caracteres
      'Senha12345',
      'Outra12345', // não confere
      'Senha12345',
    ], saida);

    final sessao = await TelaLogin(AuthService(api), entrada).exibir();

    expect(mostrou('A senha precisa ter pelo menos 8 caracteres.'), isTrue);
    expect(mostrou('As senhas não conferem.'), isTrue);
    expect(mostrou('Conta criada!'), isTrue);
    expect(sessao?.usuario.nome, 'Bia Nova');
    expect(javaFalsa.dados.usuarios.last.role, 'MEMBER');
  });

  test('e-mail já cadastrado volta para o menu inicial', () async {
    final entrada = entradaFalsa([
      '2',
      'Ana Repetida',
      'ana@email.com',
      'Senha12345',
      'Senha12345',
      '0', // Sair
    ], saida);

    final sessao = await TelaLogin(AuthService(api), entrada).exibir();

    expect(sessao, isNull);
    expect(mostrou('Já existe uma conta com este e-mail.'), isTrue);
  });

  test('API fora do ar mostra o erro e não insiste', () async {
    final temporario = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final semServidor = ApiClient(
      baseUrl: 'http://127.0.0.1:${temporario.port}',
    );
    await temporario.close(force: true);
    final entrada = entradaFalsa(['1', 'ana@email.com', 'Senha12345'], saida);

    final sessao = await TelaLogin(AuthService(semServidor), entrada).exibir();
    semServidor.fechar();

    expect(sessao, isNull);
    expect(mostrou('Não foi possível conectar à API'), isTrue);
  });
}
