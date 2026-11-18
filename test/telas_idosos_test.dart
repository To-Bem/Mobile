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

  /// Entra com o usuário e devolve os serviços já ligados à sessão.
  Future<(IdosoService, AlertaService)> entrarComo(String email) async {
    final senha = email == 'admin@tobem.com' ? 'Admin@12345' : 'Senha12345';
    final sessao = await AuthService(api).login(email, senha);
    final idosos = IdosoService(api, sessao);
    return (idosos, AlertaService(api, idosos));
  }

  bool mostrou(String trecho) => saida.any((linha) => linha.contains(trecho));

  int primeiraLinhaCom(String trecho) =>
      saida.indexWhere((linha) => linha.contains(trecho));

  Future<void> abrirLista(String email, List<String> respostas) async {
    final (idosos, alertas) = await entrarComo(email);
    await TelaListaIdosos(
      titulo: 'Meus idosos',
      idosoService: idosos,
      alertaService: alertas,
      entrada: entradaFalsa(respostas, saida),
    ).exibir();
  }

  Future<void> abrirDetalhe(
    String email,
    int idosoId,
    List<String> respostas,
  ) async {
    final (idosos, alertas) = await entrarComo(email);
    await TelaDetalheIdoso(
      idosoId: idosoId,
      idosoService: idosos,
      alertaService: alertas,
      entrada: entradaFalsa(respostas, saida),
    ).exibir();
  }

  group('TelaListaIdosos', () {
    test('familiar vê os seus idosos, do mais urgente ao que está bem',
        () async {
      await abrirLista('ana@email.com', ['0']);

      expect(mostrou('1) Dona Lurdes'), isTrue);
      expect(mostrou('2) Seu João'), isTrue);
      expect(mostrou('3) Dona Maria'), isTrue);
      expect(mostrou('[ CRÍTICO ]'), isTrue);
      expect(mostrou('Seu Antônio'), isFalse);
    });

    test('cuidador vê só os idosos em que é contato', () async {
      await abrirLista('carlos@email.com', ['0']);

      expect(mostrou('1) Dona Lurdes'), isTrue);
      expect(mostrou('2) Seu Antônio'), isTrue);
      expect(mostrou('[ SEM SINAL ]'), isTrue);
      expect(mostrou('Fora de casa'), isTrue);
      expect(mostrou('Dona Maria'), isFalse);
    });

    test('escolher um idoso abre o detalhe e voltar recarrega a lista',
        () async {
      // 1 = Dona Lurdes · 0 = voltar do detalhe · 0 = voltar da lista
      await abrirLista('ana@email.com', ['1', '0', '0']);

      expect(mostrou('DONA LURDES'), isTrue);
      expect(saida.where((linha) => linha.contains('MEUS IDOSOS')).length, 2);
    });
  });

  group('TelaDetalheIdoso', () {
    test('mostra status, dispositivos, contatos e linha do tempo', () async {
      await abrirDetalhe('ana@email.com', 3, ['0']);

      expect(mostrou('DONA LURDES'), isTrue);
      expect(mostrou('Status: [ CRÍTICO ] Crítico'), isTrue);
      expect(mostrou('(11) 96666-5555'), isTrue);
      expect(mostrou('Alertas abertos: 1'), isTrue);
      expect(mostrou('#3 Lâmpada (Banheiro) [ ONLINE ]'), isTrue);
      expect(mostrou('1º Ana Souza (você) (Filho(a))'), isTrue);
      expect(mostrou('2º Usuário #3 (Cuidador(a))'), isTrue);
      expect(mostrou('Possível queda (família avisada) (Banheiro)'), isTrue);
      expect(
        primeiraLinhaCom('Possível queda'),
        lessThan(primeiraLinhaCom('Pessoa parada no cômodo')),
      );
      // MEMBER não altera o modo: a opção nem aparece.
      expect(mostrou('fora de casa'), isFalse);
    });

    test('ambiente e rotina da Dona Maria; Atualizar recarrega', () async {
      await abrirDetalhe('ana@email.com', 1, ['1', '0']);

      expect(saida.where((linha) => linha.contains('DONA MARIA')).length, 2);
      expect(mostrou('Ambiente: 27,0 °C'), isTrue);
      expect(mostrou('Calor perigoso'), isFalse);
      expect(mostrou('Todos os dias: acorda às 07:00 | 2 levantadas'), isTrue);
    });

    test('idoso de outra família mostra o erro da API', () async {
      await abrirDetalhe('ana@email.com', 4, ['']);

      expect(
        mostrou('Você não tem permissão para executar esta ação'),
        isTrue,
      );
    });

    test('administrador marca que o idoso voltou para casa', () async {
      // 5 = marcar que voltou · s = sim · Enter · 0 = voltar
      await abrirDetalhe('admin@tobem.com', 4, ['5', 's', '', '0']);

      expect(mostrou('5) Marcar que voltou para casa'), isTrue);
      expect(mostrou('Pronto! Agora: Em casa.'), isTrue);
      expect(mostrou('5) Marcar como fora de casa'), isTrue);
      expect(javaFalsa.dados.idoso(4)!.modo, 'NORMAL');
      expect(javaFalsa.rotasChamadas, contains('PUT /api/idosos/4'));
    });
  });
}
