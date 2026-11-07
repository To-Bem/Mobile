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

  Future<Sessao> entrarComo(String email) =>
      AuthService(api).login(email, email == 'admin@email.com' ? 'admin123' : '123456');

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  int primeiraLinhaCom(String trecho) =>
      saida.indexWhere((linha) => linha.contains(trecho));

  group('TelaListaIdosos', () {
    test('familiar vê os seus idosos, do mais urgente ao que está bem',
        () async {
      await entrarComo('ana@email.com');
      final entrada = entradaFalsa(['0'], saida);

      await TelaListaIdosos(
        titulo: 'Meus idosos',
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('1) Dona Lurdes'), isTrue);
      expect(mostrou('2) Seu João'), isTrue);
      expect(mostrou('3) Dona Maria'), isTrue);
      expect(mostrou('Seu Antônio'), isFalse);
    });

    test('cuidador vê só os idosos atribuídos a ele', () async {
      await entrarComo('carlos@email.com');
      final entrada = entradaFalsa(['0'], saida);

      await TelaListaIdosos(
        titulo: 'Idosos que acompanho',
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('Dona Lurdes'), isTrue);
      expect(mostrou('Seu Antônio'), isTrue);
      expect(mostrou('Fora de casa'), isTrue);
      expect(mostrou('Dona Maria'), isFalse);
    });

    test('escolher um idoso abre o detalhe e voltar recarrega a lista',
        () async {
      await entrarComo('ana@email.com');
      // 1 = Dona Lurdes · 0 = voltar do detalhe · 0 = voltar da lista
      final entrada = entradaFalsa(['1', '0', '0'], saida);

      await TelaListaIdosos(
        titulo: 'Meus idosos',
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('DONA LURDES'), isTrue);
      expect(saida.where((linha) => linha.contains('MEUS IDOSOS')).length, 2);
    });
  });

  group('TelaDetalheIdoso', () {
    test('mostra status, ambiente e linha do tempo', () async {
      await entrarComo('ana@email.com');
      final entrada = entradaFalsa(['0'], saida);

      await TelaDetalheIdoso(
        idosoId: 3,
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('DONA LURDES'), isTrue);
      expect(mostrou('Crítico'), isTrue);
      expect(mostrou('(11) 97777-6666'), isTrue);
      expect(mostrou('Alertas abertos: 2'), isTrue);
      expect(mostrou('33,5 °C'), isTrue);
      expect(mostrou('Calor perigoso'), isTrue);
      expect(mostrou('Pessoa parada por muito tempo (Banheiro)'), isTrue);
      expect(
        primeiraLinhaCom('Pessoa parada'),
        lessThan(primeiraLinhaCom('Leitura de temperatura')),
      );
    });

    test('Atualizar busca o painel de novo', () async {
      await entrarComo('ana@email.com');
      final entrada = entradaFalsa(['1', '0'], saida);

      await TelaDetalheIdoso(
        idosoId: 1,
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(saida.where((linha) => linha.contains('DONA MARIA')).length, 2);
      expect(mostrou('Calor perigoso'), isFalse);
    });

    test('idoso de outra família mostra erro', () async {
      await entrarComo('ana@email.com');
      final entrada = entradaFalsa([''], saida);

      await TelaDetalheIdoso(
        idosoId: 4,
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('Idoso não encontrado.'), isTrue);
    });
  });

  group('TelaMenuPrincipal', () {
    test('familiar vê o resumo e o aviso de urgência', () async {
      final sessao = await entrarComo('ana@email.com');
      final entrada = entradaFalsa(['0'], saida);

      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('Olá, Ana Souza (Familiar)'), isTrue);
      expect(mostrou('Você acompanha 3 idosos'), isTrue);
      expect(mostrou('1 idoso precisa de atenção agora.'), isTrue);
      expect(mostrou('1) Meus idosos'), isTrue);
      expect(mostrou('0) Sair'), isTrue);
    });

    test('o texto do menu muda conforme o papel', () async {
      final sessao = await entrarComo('admin@email.com');
      final entrada = entradaFalsa(['0'], saida);

      await TelaMenuPrincipal(
        sessao: sessao,
        idosoService: IdosoService(api),
        entrada: entrada,
      ).exibir();

      expect(mostrou('1) Todos os idosos'), isTrue);
      expect(mostrou('Você acompanha 4 idosos'), isTrue);
    });
  });
}
