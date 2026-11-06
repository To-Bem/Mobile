import 'dart:convert';
import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

/// Servidor HTTP local que faz o papel da API Java nos testes.
/// Responde com [status] e [corpo] e guarda a última requisição recebida.
class ServidorFalso {
  ServidorFalso._(this._servidor);

  final HttpServer _servidor;

  int status = 200;
  Object? corpo;

  String? ultimoMetodo;
  String? ultimoCaminho;
  String? ultimoAuthorization;
  String? ultimoCorpoRecebido;
  Map<String, String> ultimosParametros = {};

  static Future<ServidorFalso> iniciar() async {
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final falso = ServidorFalso._(servidor);
    servidor.listen(falso._responder);
    return falso;
  }

  String get url => 'http://${_servidor.address.address}:${_servidor.port}';

  Future<void> _responder(HttpRequest requisicao) async {
    ultimoMetodo = requisicao.method;
    ultimoCaminho = requisicao.uri.path;
    ultimosParametros = requisicao.uri.queryParameters;
    ultimoAuthorization = requisicao.headers.value(
      HttpHeaders.authorizationHeader,
    );
    ultimoCorpoRecebido = await utf8.decoder.bind(requisicao).join();

    requisicao.response.statusCode = status;
    final resposta = corpo;
    if (resposta != null) {
      requisicao.response.headers.contentType = ContentType.json;
      requisicao.response.write(jsonEncode(resposta));
    }
    await requisicao.response.close();
  }

  Future<void> fechar() => _servidor.close(force: true);
}

Map<String, dynamic> idosoJson(int id, String nome) => {
  'id': id,
  'nome': nome,
  'modo': 'NORMAL',
  'status': 'OK',
};

void main() {
  late ServidorFalso servidor;
  late ApiClient api;

  setUp(() async {
    servidor = await ServidorFalso.iniciar();
    api = ApiClient(baseUrl: servidor.url);
  });

  tearDown(() async {
    api.fechar();
    await servidor.fechar();
  });

  group('ApiClient', () {
    test('envia o token e lê o JSON', () async {
      servidor.corpo = {'ok': true};
      api.token = 'abc';

      final corpo = await api.get('/teste');

      expect(corpo, {'ok': true});
      expect(servidor.ultimoAuthorization, 'Bearer abc');
    });

    test('erro 400 traz a mensagem e os campos da API', () async {
      servidor
        ..status = 400
        ..corpo = {
          'mensagem': 'Dados inválidos',
          'campos': {'telefone': 'obrigatório'},
        };

      await expectLater(
        api.post('/idosos', {'nome': 'X'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.mensagem, 'mensagem', 'Dados inválidos')
              .having((e) => e.campos['telefone'], 'campo', 'obrigatório'),
        ),
      );
    });

    test('erro 404 sem corpo usa mensagem padrão', () async {
      servidor.status = 404;

      await expectLater(
        api.get('/idosos/99/painel'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Registro não encontrado.',
          ),
        ),
      );
    });

    test('401 vira NaoAutorizadoException', () async {
      servidor.status = 401;

      await expectLater(
        api.get('/idosos'),
        throwsA(isA<NaoAutorizadoException>()),
      );
    });

    test('API fora do ar vira SemConexaoException', () async {
      final temporario = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final urlSemServidor = 'http://127.0.0.1:${temporario.port}';
      await temporario.close(force: true);

      final semServidor = ApiClient(baseUrl: urlSemServidor);
      await expectLater(
        semServidor.get('/idosos'),
        throwsA(isA<SemConexaoException>()),
      );
      semServidor.fechar();
    });

    test('listaDaResposta aceita lista, página e _embedded', () {
      final item = {'id': 1};
      expect(ApiClient.listaDaResposta([item]), [item]);
      expect(
        ApiClient.listaDaResposta({
          'content': [item],
          'totalElements': 1,
        }),
        [item],
      );
      expect(
        ApiClient.listaDaResposta({
          '_embedded': {
            'idosos': [item],
          },
        }),
        [item],
      );
      expect(ApiClient.listaDaResposta(null), isEmpty);
    });
  });

  group('AuthService', () {
    test('login guarda o token e envia e-mail sem espaços', () async {
      servidor.corpo = {
        'token': 'jwt123',
        'usuario': {
          'id': 1,
          'nome': 'Ana',
          'email': 'ana@email.com',
          'papel': 'FAMILIAR',
        },
      };
      final auth = AuthService(api);

      final sessao = await auth.login('  ana@email.com ', '123456');

      expect(sessao.usuario.nome, 'Ana');
      expect(api.token, 'jwt123');
      expect(auth.logado, isTrue);
      expect(servidor.ultimoMetodo, 'POST');
      expect(servidor.ultimoCaminho, '/auth/login');
      expect(jsonDecode(servidor.ultimoCorpoRecebido!), {
        'email': 'ana@email.com',
        'senha': '123456',
      });
    });

    test('senha errada vira mensagem amigável', () async {
      servidor.status = 401;
      final auth = AuthService(api);

      await expectLater(
        auth.login('ana@email.com', 'errada'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensagem,
            'mensagem',
            'E-mail ou senha inválidos.',
          ),
        ),
      );
      expect(auth.logado, isFalse);
    });

    test('sair apaga o token', () {
      api.token = 'jwt123';
      AuthService(api).sair();
      expect(api.token, isNull);
    });
  });

  group('IdosoService', () {
    test('lista idosos vindos em _embedded', () async {
      servidor.corpo = {
        '_embedded': {
          'idosos': [idosoJson(1, 'Dona Maria'), idosoJson(2, 'Seu João')],
        },
      };

      final idosos = await IdosoService(api).listar();

      expect(idosos.map((i) => i.nome), ['Dona Maria', 'Seu João']);
    });

    test('alterarModo envia PATCH com o modo', () async {
      servidor.corpo = idosoJson(7, 'Dona Maria')..['modo'] = 'AUSENTE';

      final idoso = await IdosoService(api).alterarModo(7, ModoIdoso.ausente);

      expect(servidor.ultimoMetodo, 'PATCH');
      expect(servidor.ultimoCaminho, '/idosos/7/modo');
      expect(jsonDecode(servidor.ultimoCorpoRecebido!), {'modo': 'AUSENTE'});
      expect(idoso.estaAusente, isTrue);
    });
  });

  group('AlertaService', () {
    test('envia só os filtros informados e ordena do mais recente', () async {
      servidor.corpo = [
        {
          'id': 1,
          'idosoId': 7,
          'nivel': 'ATENCAO',
          'status': 'ABERTO',
          'criadoEm': '2026-11-06T08:00:00',
        },
        {
          'id': 2,
          'idosoId': 7,
          'nivel': 'CRITICO',
          'status': 'ABERTO',
          'criadoEm': '2026-11-06T10:00:00',
        },
      ];

      final alertas = await AlertaService(api)
          .listar(status: StatusAlerta.aberto, idosoId: 7);

      expect(servidor.ultimosParametros, {'status': 'ABERTO', 'idosoId': '7'});
      expect(alertas.first.id, 2);
    });

    test('confirmar chama a rota certa', () async {
      servidor.corpo = {
        'id': 2,
        'idosoId': 7,
        'nivel': 'CRITICO',
        'status': 'RESOLVIDO',
        'criadoEm': '2026-11-06T10:00:00',
      };

      final alerta = await AlertaService(api).confirmar(2);

      expect(servidor.ultimoCaminho, '/alertas/2/confirmar');
      expect(alerta.estaAberto, isFalse);
    });
  });
}
