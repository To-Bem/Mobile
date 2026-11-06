import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

void main() {
  group('enums', () {
    test('converte texto da API e volta', () {
      expect(
        enumDaApi(NivelAlerta.values, 'CRITICO', NivelAlerta.atencao),
        NivelAlerta.critico,
      );
      expect(enumParaApi(StatusIdoso.atencao), 'ATENCAO');
    });

    test('valor desconhecido usa o padrão', () {
      expect(
        enumDaApi(Papel.values, 'SUPERUSER', Papel.familiar),
        Papel.familiar,
      );
      expect(enumDaApi(Papel.values, null, Papel.cuidador), Papel.cuidador);
    });
  });

  group('Sessao', () {
    test('lê token e usuário do login', () {
      final sessao = Sessao.fromJson({
        'token': 'abc.def.ghi',
        'usuario': {
          'id': 1,
          'nome': 'Ana',
          'email': 'ana@email.com',
          'papel': 'FAMILIAR',
        },
      });
      expect(sessao.token, 'abc.def.ghi');
      expect(sessao.usuario.papel, Papel.familiar);
    });
  });

  group('Idoso', () {
    test('lê campos calculados pela API e ignora _links', () {
      final idoso = Idoso.fromJson({
        'id': 7,
        'nome': 'Dona Maria',
        'dataNascimento': '1948-03-12',
        'modo': 'NORMAL',
        'status': 'ATENCAO',
        'ultimaAtividade': '2026-11-06T09:40:00',
        'alertasAbertos': 2,
        '_links': {
          'self': {'href': 'http://api/idosos/7'},
        },
      });
      expect(idoso.id, 7);
      expect(idoso.status, StatusIdoso.atencao);
      expect(idoso.alertasAbertos, 2);
      expect(idoso.ultimaAtividade, DateTime(2026, 11, 6, 9, 40));
    });

    test('calcula a idade', () {
      final hoje = DateTime.now();
      final idoso = Idoso(nome: 'X', dataNascimento: DateTime(hoje.year - 70));
      expect(idoso.idade, 70);
    });

    test(
      'toJson envia data no formato do Java e não envia campos calculados',
      () {
        final json = Idoso(
          nome: 'Seu João',
          dataNascimento: DateTime(1950, 1, 5),
          status: StatusIdoso.critico,
        ).toJson();
        expect(json['dataNascimento'], '1950-01-05');
        expect(json['modo'], 'NORMAL');
        expect(json.containsKey('status'), isFalse);
      },
    );

    test('copyWith troca só o modo', () {
      const idoso = Idoso(id: 1, nome: 'Dona Maria');
      final ausente = idoso.copyWith(modo: ModoIdoso.ausente);
      expect(ausente.estaAusente, isTrue);
      expect(ausente.nome, 'Dona Maria');
    });
  });

  group('Alerta', () {
    test('lê alerta e confirma com copyWith', () {
      final alerta = Alerta.fromJson({
        'id': 3,
        'idosoId': 7,
        'idosoNome': 'Dona Maria',
        'tipo': 'pessoa_parada',
        'nivel': 'CRITICO',
        'status': 'ABERTO',
        'criadoEm': '2026-11-06T10:05:00.123',
      });
      expect(alerta.tipo, 'PESSOA_PARADA');
      expect(alerta.estaAberto, isTrue);
      expect(
        alerta.copyWith(status: StatusAlerta.resolvido).estaAberto,
        isFalse,
      );
    });
  });

  group('PainelIdoso', () {
    test('ordena a linha do tempo do mais recente para o mais antigo', () {
      final painel = PainelIdoso.fromJson({
        'idoso': {'id': 7, 'nome': 'Dona Maria'},
        'temperatura': 31,
        'eventosHoje': [
          {'id': 1, 'tipo': 'PRESENCA', 'dataHora': '2026-11-06T07:10:00'},
          {
            'id': 2,
            'tipo': 'PORTA_GELADEIRA',
            'dataHora': '2026-11-06T08:30:00',
          },
        ],
      });
      expect(painel.temperatura, 31.0);
      expect(painel.eventosHoje.first.descricao, 'Abriu a geladeira');
    });
  });

  group('Contato', () {
    test('não envia usuarioId quando é alguém sem conta', () {
      final json = const Contato(
        nome: 'Vizinha Rosa',
        telefone: '11999990000',
        parentesco: 'Vizinha',
        ordemEscalonamento: 2,
      ).toJson();
      expect(json.containsKey('usuarioId'), isFalse);
    });
  });

  test('lerLista ignora itens que não são objetos', () {
    final lista = lerLista([
      {'id': 1, 'nome': 'A'},
      'lixo',
      null,
    ], Idoso.fromJson);
    expect(lista.length, 1);
  });
}
