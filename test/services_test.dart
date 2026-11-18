import 'dart:convert';
import 'dart:io';

import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

import 'apoio/api_java_falsa.dart';

/// Servidor mínimo que devolve sempre a mesma resposta e guarda a última
/// requisição. Serve para testar o ApiClient sozinho.
class ServidorFixo {
  ServidorFixo._(this._servidor);

  final HttpServer _servidor;

  int status = 200;
  Object? corpo;

  String? ultimoMetodo;
  String? ultimoCaminho;
  String? ultimoAuthorization;
  String? ultimoCorpoRecebido;
  Map<String, String> ultimosParametros = {};

  static Future<ServidorFixo> iniciar() async {
    final servidor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixo = ServidorFixo._(servidor);
    servidor.listen(fixo._responder);
    return fixo;
  }

  String get url => 'http://127.0.0.1:${_servidor.port}';

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

void main() {
  group('ApiClient', () {
    late ServidorFixo servidor;
    late ApiClient api;

    setUp(() async {
      servidor = await ServidorFixo.iniciar();
      api = ApiClient(baseUrl: servidor.url);
    });

    tearDown(() async {
      api.fechar();
      await servidor.fechar();
    });

    test('envia o token, os parâmetros e lê o JSON', () async {
      servidor.corpo = {'ok': true};
      api.token = 'abc';

      final corpo = await api.get(
        '/api/idosos',
        parametros: ApiClient.pagina(ordenarPor: 'nome'),
      );

      expect(corpo, {'ok': true});
      expect(servidor.ultimoAuthorization, 'Bearer abc');
      expect(servidor.ultimosParametros, {
        'page': '0',
        'size': '100',
        'sort': 'nome',
        'direction': 'ASC',
      });
    });

    test('PUT envia o corpo em JSON', () async {
      servidor.corpo = {'id': 1};

      await api.put('/api/alertas/1', {'status': 'RESOLVIDO'});

      expect(servidor.ultimoMetodo, 'PUT');
      expect(servidor.ultimoCaminho, '/api/alertas/1');
      expect(jsonDecode(servidor.ultimoCorpoRecebido!), {
        'status': 'RESOLVIDO',
      });
    });

    test('400 de validação do Java vira mensagem + campos', () async {
      servidor
        ..status = 400
        ..corpo = {
          'timestamp': '2026-11-17T10:00:00',
          'status': 400,
          'error': 'Bad Request',
          'errors': [
            {'field': 'telefone', 'message': 'telefone é obrigatorio'},
          ],
        };

      await expectLater(
        api.post('/api/usuarios/1/idoso', {'nome': 'X'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 400)
              .having(
                (e) => e.mensagem,
                'mensagem',
                'Dados inválidos. Confira os campos:',
              )
              .having(
                (e) => e.campos['telefone'],
                'campo',
                'telefone é obrigatorio',
              ),
        ),
      );
    });

    test('erro do Java traz o campo "message"', () async {
      servidor
        ..status = 409
        ..corpo = {
          'status': 409,
          'error': 'Conflict',
          'message': 'Um alerta resolvido nao pode ser reaberto.',
        };

      await expectLater(
        api.put('/api/alertas/1', {}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Um alerta resolvido nao pode ser reaberto.',
          ),
        ),
      );
    });

    test('404 sem corpo usa mensagem padrão', () async {
      servidor.status = 404;

      await expectLater(
        api.get('/api/idosos/99'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensagem,
            'mensagem',
            'Registro não encontrado.',
          ),
        ),
      );
    });

    test('401 e 403 viram NaoAutorizadoException', () async {
      servidor.status = 401;
      await expectLater(
        api.get('/api/idosos'),
        throwsA(isA<NaoAutorizadoException>()),
      );

      servidor.status = 403;
      await expectLater(
        api.get('/api/idosos'),
        throwsA(isA<NaoAutorizadoException>()),
      );
    });

    test('API fora do ar vira SemConexaoException', () async {
      final temporario = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final urlSemServidor = 'http://127.0.0.1:${temporario.port}';
      await temporario.close(force: true);

      final semServidor = ApiClient(baseUrl: urlSemServidor);
      await expectLater(
        semServidor.get('/api/idosos'),
        throwsA(isA<SemConexaoException>()),
      );
      semServidor.fechar();
    });

    test('listaDaResposta aceita lista e PageResponse', () {
      final item = {'id': 1};
      expect(ApiClient.listaDaResposta([item]), [item]);
      expect(
        ApiClient.listaDaResposta({
          'content': [item],
          'page': 0,
          'size': 10,
          'totalElements': 1,
          'totalPages': 1,
          'last': true,
        }),
        [item],
      );
      expect(ApiClient.listaDaResposta(null), isEmpty);
    });
  });

  group('Serviços contra a API Java (imitação)', () {
    late ApiJavaFalsa javaFalsa;
    late ApiClient api;
    late AuthService auth;

    setUp(() async {
      javaFalsa = await ApiJavaFalsa.iniciar();
      api = ApiClient(baseUrl: javaFalsa.url);
      auth = AuthService(api);
    });

    tearDown(() async {
      api.fechar();
      await javaFalsa.fechar();
    });

    group('AuthService', () {
      test('login usa email/password, guarda o token e busca o /me', () async {
        final sessao = await auth.login(' ana@email.com ', 'Senha12345');

        expect(sessao.token, 'token-falso-2');
        expect(sessao.perfil, Perfil.member);
        expect(sessao.ehGestao, isFalse);
        expect(sessao.usuario.id, 2);
        expect(sessao.usuario.nome, 'Ana Souza');
        expect(sessao.usuario.papel, Papel.familiar);
        expect(api.token, 'token-falso-2');
        expect(javaFalsa.rotasChamadas, [
          'POST /api/auth/login',
          'GET /api/auth/me',
        ]);
      });

      test('admin é gestão', () async {
        final sessao = await auth.login('admin@tobem.com', 'Admin@12345');
        expect(sessao.perfil, Perfil.admin);
        expect(sessao.ehGestao, isTrue);
      });

      test('senha errada vira mensagem amigável', () async {
        await expectLater(
          auth.login('ana@email.com', 'errada123'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.mensagem,
              'mensagem',
              'E-mail ou senha inválidos.',
            ),
          ),
        );
        expect(auth.logado, isFalse);
        expect(api.token, isNull);
      });

      test('cadastrar cria a conta MEMBER e já entra', () async {
        final sessao = await auth.cadastrar(
          nome: 'Bia Nova',
          email: 'bia@email.com',
          senha: 'Senha12345',
        );

        expect(sessao.usuario.nome, 'Bia Nova');
        expect(sessao.perfil, Perfil.member);
        expect(sessao.usuario.papel, isNull);
      });

      test('e-mail repetido no cadastro', () async {
        await expectLater(
          auth.cadastrar(
            nome: 'Ana',
            email: 'ana@email.com',
            senha: 'Senha12345',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.mensagem,
              'mensagem',
              'Já existe uma conta com este e-mail.',
            ),
          ),
        );
      });

      test('sair apaga o token', () async {
        await auth.login('ana@email.com', 'Senha12345');
        auth.sair();
        expect(auth.logado, isFalse);
        expect(api.token, isNull);
      });
    });

    group('IdosoService', () {
      Future<IdosoService> servicoDe(String email, [String? senha]) async {
        final sessao = await auth.login(
          email,
          senha ?? (email == 'admin@tobem.com' ? 'Admin@12345' : 'Senha12345'),
        );
        return IdosoService(api, sessao);
      }

      test('MEMBER vê só os idosos em que é contato', () async {
        final idosos = await (await servicoDe('ana@email.com')).listar();
        expect(
          idosos.map((idoso) => idoso.nome),
          unorderedEquals(['Dona Maria', 'Seu João', 'Dona Lurdes']),
        );
        expect(
          javaFalsa.rotasChamadas,
          contains('GET /api/usuarios/2/withContatos'),
        );
        expect(javaFalsa.rotasChamadas, isNot(contains('GET /api/idosos')));
      });

      test('ADMIN vê todos pela listagem paginada', () async {
        final idosos = await (await servicoDe('admin@tobem.com')).listar();
        expect(idosos, hasLength(4));
        expect(javaFalsa.rotasChamadas, contains('GET /api/idosos'));
      });

      test('situação calculada a partir de alertas e dispositivos', () async {
        final idosos = await (await servicoDe('admin@tobem.com')).listar();
        final porNome = {for (final idoso in idosos) idoso.nome: idoso};

        expect(porNome['Dona Maria']!.status, StatusIdoso.ok);
        expect(porNome['Dona Maria']!.alertasAbertos, 0);
        expect(porNome['Seu João']!.status, StatusIdoso.atencao);
        expect(porNome['Seu João']!.alertasAbertos, 1);
        expect(porNome['Dona Lurdes']!.status, StatusIdoso.critico);
        expect(porNome['Seu Antônio']!.status, StatusIdoso.offline);
        expect(porNome['Seu Antônio']!.estaAusente, isTrue);
      });

      test('painel junta withAll e os eventos dos dispositivos', () async {
        final painel = await (await servicoDe('ana@email.com')).painel(1);

        expect(painel.idoso.nome, 'Dona Maria');
        expect(painel.idoso.dataNascimento, DateTime(1948, 3, 12));
        expect(painel.contatos.single.parentesco, 'Filho(a)');
        expect(painel.rotinas.single.horaCurta, '07:00');
        expect(painel.dispositivos.single.comodo, 'Sala');
        expect(painel.eventos.first.tipo, 'TEMPERATURA');
        expect(painel.eventos.first.comodo, 'Sala');
        expect(painel.temperatura, 27);
        // A temperatura não conta como atividade; o movimento, sim.
        expect(
          painel.idoso.ultimaAtividade,
          painel.eventos.firstWhere((e) => e.tipo == 'MOVIMENTO').dataHora,
        );
        expect(
          javaFalsa.rotasChamadas,
          containsAll([
            'GET /api/idosos/1/withAll',
            'GET /api/eventos/byOtherFilter',
          ]),
        );
      });

      test('MEMBER não abre idoso de outra família', () async {
        await expectLater(
          (await servicoDe('carlos@email.com')).painel(1),
          throwsA(isA<NaoAutorizadoException>()),
        );
      });

      test('cadastrar envia parentesco e ordem como parâmetros', () async {
        final servico = await servicoDe('ana@email.com');
        final salvo = await servico.cadastrar(
          Idoso(
            nome: 'Dona Cida',
            dataNascimento: DateTime(1945, 8, 9),
            telefone: '11944443333',
            endereco: 'Rua Nova, 10',
          ),
          parentesco: 'Filho(a)',
        );

        expect(salvo.id, isNotNull);
        expect(salvo.dataNascimento, DateTime(1945, 8, 9));
        expect(javaFalsa.rotasChamadas.last, 'POST /api/usuarios/2/idoso');
        final contato = javaFalsa.dados.contatos.last;
        expect(contato.idosoId, salvo.id);
        expect(contato.usuarioId, 2);
        expect(contato.ordemEscalonamento, 1);
        // Já aparece na lista da Ana.
        expect(
          (await servico.listar()).map((idoso) => idoso.nome),
          contains('Dona Cida'),
        );
      });

      test('cadastrar dispositivo e rotina', () async {
        final servico = await servicoDe('ana@email.com');

        final dispositivo = await servico.cadastrarDispositivo(
          2,
          const Dispositivo(tipo: TipoDispositivo.base, comodo: 'Cozinha'),
        );
        expect(dispositivo.id, isNotNull);
        expect(dispositivo.tipo, TipoDispositivo.base);
        expect(dispositivo.status, StatusDispositivo.online);

        final rotina = await servico.cadastrarRotina(
          2,
          const Rotina(
            diaSemana: 'SEGUNDA',
            horaPrimeiraAtividade: '06:45:00',
            mediaLevantadasPorNoite: 1,
          ),
        );
        expect(rotina.horaCurta, '06:45');
      });

      test('alterar modo é só para ADMIN/MANAGER', () async {
        final membro = await servicoDe('ana@email.com');
        final maria = (await membro.painel(1)).idoso;
        await expectLater(
          membro.alterarModo(maria, ModoIdoso.ausente),
          throwsA(isA<NaoAutorizadoException>()),
        );

        final gerente = await servicoDe('gerente@email.com');
        final atualizado = await gerente.alterarModo(maria, ModoIdoso.ausente);
        expect(atualizado.modo, ModoIdoso.ausente);
        expect(javaFalsa.dados.idoso(1)!.dataNascimento, '12/03/1948');
      });

      test('nomes dos contatos: MEMBER só sabe o próprio nome', () async {
        final membro = await servicoDe('ana@email.com');
        final contatos = await membro.comNomes((await membro.painel(3)).contatos);
        expect(contatos.map((c) => c.nomeUsuario), [
          'Ana Souza (você)',
          'Usuário #3',
        ]);

        final admin = await servicoDe('admin@tobem.com');
        final todos = await admin.comNomes((await admin.painel(3)).contatos);
        expect(todos.map((c) => c.nomeUsuario), ['Ana Souza', 'Carlos Lima']);
      });
    });

    group('AlertaService', () {
      Future<AlertaService> servicoDe(String email, String senha) async {
        final sessao = await auth.login(email, senha);
        return AlertaService(api, IdosoService(api, sessao));
      }

      test('MEMBER recebe os alertas dos seus idosos, com nome', () async {
        final alertas = await (await servicoDe(
          'ana@email.com',
          'Senha12345',
        )).listar();

        expect(alertas.map((a) => a.id), [3, 2, 1]); // mais recente primeiro
        expect(alertas.first.idosoNome, 'Dona Lurdes');
      });

      test('alertas de um idoso só', () async {
        final alertas = await (await servicoDe(
          'carlos@email.com',
          'Senha12345',
        )).listar(idosoId: 3);
        expect(alertas.single.tipo, 'QUEDA');
        expect(alertas.single.nivelEscalonamento, 2);
      });

      test('confirmar manda PUT com status RESOLVIDO', () async {
        final servico = await servicoDe('ana@email.com', 'Senha12345');
        final aberto = (await servico.listar()).firstWhere((a) => a.id == 2);

        final confirmado = await servico.confirmar(aberto);

        expect(confirmado.status, StatusAlerta.resolvido);
        expect(confirmado.idosoNome, 'Seu João');
        expect(javaFalsa.rotasChamadas.last, 'PUT /api/alertas/2');
        expect(javaFalsa.dados.alertas[1].status, 'RESOLVIDO');
      });
    });
  });
}
