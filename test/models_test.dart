import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

void main() {
  group('enums', () {
    test('converte texto da API e volta', () {
      expect(
        enumDaApi(NivelAlerta.values, 'CRITICO', NivelAlerta.atencao),
        NivelAlerta.critico,
      );
      expect(enumParaApi(StatusAlerta.resolvido), 'RESOLVIDO');
      expect(enumParaApi(TipoDispositivo.lampada), 'LAMPADA');
    });

    test('valor desconhecido usa o padrão ou null', () {
      expect(
        enumDaApi(Perfil.values, 'SUPERUSER', Perfil.member),
        Perfil.member,
      );
      expect(enumDaApiOuNulo(Papel.values, null), isNull);
      expect(enumDaApiOuNulo(Papel.values, 'CUIDADOR'), Papel.cuidador);
    });

    test('ADMIN e MANAGER são gestão; MEMBER não', () {
      expect(Perfil.admin.ehGestao, isTrue);
      expect(Perfil.manager.ehGestao, isTrue);
      expect(Perfil.member.ehGestao, isFalse);
    });
  });

  group('datas da API Java', () {
    test('lê dd/MM/yyyy e dd/MM/yyyy HH:mm:ss', () {
      expect(lerData('12/03/1948'), DateTime(1948, 3, 12));
      expect(lerData('17/11/2026 14:05:09'), DateTime(2026, 11, 17, 14, 5, 9));
    });

    test('também lê ISO e ignora vazio', () {
      expect(lerData('2026-11-17T14:05:09'), DateTime(2026, 11, 17, 14, 5, 9));
      expect(lerData(''), isNull);
      expect(lerData(null), isNull);
    });

    test('escreve no formato que o Java espera', () {
      expect(dataParaApi(DateTime(1948, 3, 2)), '1948-03-02');
      expect(
        dataHoraParaApi(DateTime(2026, 11, 7, 9, 5, 3)),
        '2026-11-07T09:05:03',
      );
      expect(horaParaApi(7, 5), '07:05:00');
    });
  });

  group('Usuario', () {
    test('papel pode vir nulo (cadastro público)', () {
      final usuario = Usuario.fromJson({
        'id': 5,
        'nome': 'Bia',
        'email': 'bia@email.com',
        'papel': null,
      });
      expect(usuario.id, 5);
      expect(usuario.papel, isNull);
    });
  });

  group('Idoso', () {
    test('lê o IdosoResponse do Java', () {
      final idoso = Idoso.fromJson({
        'id': 7,
        'nome': 'Dona Maria',
        'dataNascimento': '12/03/1948',
        'telefone': '11988887777',
        'endereco': 'Rua das Flores, 120',
        'modo': 'AUSENTE',
      });
      expect(idoso.id, 7);
      expect(idoso.dataNascimento, DateTime(1948, 3, 12));
      expect(idoso.estaAusente, isTrue);
      // Calculados pelo app, não pela API.
      expect(idoso.status, StatusIdoso.ok);
      expect(idoso.alertasAbertos, 0);
    });

    test('toJson vira IdosoRequest com data ISO', () {
      final json = Idoso(
        id: 7,
        nome: 'Dona Maria',
        dataNascimento: DateTime(1948, 3, 12),
        telefone: '11988887777',
        endereco: 'Rua das Flores, 120',
        status: StatusIdoso.critico,
      ).toJson();

      expect(json, {
        'nome': 'Dona Maria',
        'dataNascimento': '1948-03-12',
        'telefone': '11988887777',
        'endereco': 'Rua das Flores, 120',
        'modo': 'NORMAL',
      });
    });

    test('calcula a idade', () {
      final hoje = DateTime.now();
      final idoso = Idoso(
        nome: 'X',
        dataNascimento: DateTime(hoje.year - 70, hoje.month, hoje.day),
      );
      expect(idoso.idade, 70);
    });
  });

  group('Alerta', () {
    final json = {
      'id': 3,
      'tipo': 'queda',
      'nivel': 'CRITICO',
      'status': 'ESCALONADO',
      'nivelEscalonamento': 2,
      'criadoEm': '17/11/2026 14:00:00',
      'usuarioId': 3,
      'idosoId': 1,
    };

    test('lê o AlertaResponse do Java', () {
      final alerta = Alerta.fromJson(json);
      expect(alerta.tipo, 'QUEDA');
      expect(alerta.nivel, NivelAlerta.critico);
      expect(alerta.status, StatusAlerta.escalonado);
      expect(alerta.estaAberto, isTrue);
      expect(alerta.criadoEm, DateTime(2026, 11, 17, 14));
    });

    test('paraAtualizar reenvia tudo e troca só o status', () {
      expect(
        Alerta.fromJson(
          json,
        ).paraAtualizar(novoStatus: StatusAlerta.resolvido),
        {
          'tipo': 'QUEDA',
          'nivel': 'CRITICO',
          'status': 'RESOLVIDO',
          'nivelEscalonamento': 2,
        },
      );
    });
  });

  group('Dispositivo e Evento', () {
    final agora = DateTime(2026, 11, 17, 12);

    test('online depende do status e do último sinal', () {
      final lampada = Dispositivo.fromJson({
        'id': 1,
        'tipo': 'LAMPADA',
        'comodo': 'Sala',
        'status': 'ONLINE',
        'ultimoHeartbeat': '17/11/2026 11:50:00',
        'idosoId': 1,
      });
      const limite = Duration(minutes: 15);

      expect(lampada.nome, 'Lâmpada (Sala)');
      expect(lampada.estaOnline(agora, limite), isTrue);
      expect(
        lampada.estaOnline(agora.add(const Duration(hours: 1)), limite),
        isFalse,
      );
    });

    test('tipos do firmware têm descrição e atividade', () {
      Evento evento(String tipo) =>
          Evento(id: 1, tipo: tipo, dataHora: agora);

      expect(evento('BOTAO_OK').descricao, 'Apertou "Estou bem"');
      expect(evento('MOVIMENTO').indicaAtividade, isTrue);
      expect(evento('HEARTBEAT').indicaAtividade, isFalse);
      expect(evento('TEMPERATURA').ehTemperatura, isTrue);
      expect(evento('DESCONHECIDO').descricao, 'DESCONHECIDO');
    });
  });

  group('PainelIdoso.montar', () {
    final agora = DateTime(2026, 11, 17, 12);
    const limite = Duration(minutes: 15);

    Map<String, dynamic> idosoComTudo({
      List<Map<String, dynamic>> alertas = const [],
      String heartbeat = '17/11/2026 11:55:00',
    }) => {
      'id': 1,
      'nome': 'Dona Maria',
      'dataNascimento': '12/03/1948',
      'telefone': '11988887777',
      'endereco': 'Rua das Flores, 120',
      'modo': 'NORMAL',
      'contatos': [
        {
          'id': 2,
          'parentesco': 'Vizinho(a)',
          'ordemEscalonamento': 2,
          'usuarioId': 9,
          'idosoId': 1,
        },
        {
          'id': 1,
          'parentesco': 'Filho(a)',
          'ordemEscalonamento': 1,
          'usuarioId': 8,
          'idosoId': 1,
        },
      ],
      'alertas': alertas,
      'rotinas': [],
      'dispositivos': [
        {
          'id': 5,
          'tipo': 'LAMPADA',
          'comodo': 'Quarto',
          'status': 'ONLINE',
          'ultimoHeartbeat': heartbeat,
          'idosoId': 1,
        },
      ],
    };

    final eventos = [
      Evento(
        id: 1,
        tipo: 'MOVIMENTO',
        dataHora: DateTime(2026, 11, 17, 11, 30),
        dispositivoId: 5,
      ),
      Evento(
        id: 2,
        tipo: 'TEMPERATURA',
        dataHora: DateTime(2026, 11, 17, 11, 40),
        valor: 33,
        dispositivoId: 5,
      ),
    ];

    test('ordena, preenche cômodo e calcula a situação', () {
      final painel = PainelIdoso.montar(
        idosoComTudo(),
        eventos,
        agora: agora,
        limiteSemSinal: limite,
      );

      expect(painel.contatos.map((c) => c.ordemEscalonamento), [1, 2]);
      expect(painel.eventos.first.tipo, 'TEMPERATURA');
      expect(painel.eventos.first.comodo, 'Quarto');
      expect(painel.temperatura, 33);
      expect(painel.idoso.ultimaAtividade, DateTime(2026, 11, 17, 11, 30));
      expect(painel.idoso.status, StatusIdoso.ok);
    });

    test('alerta aberto mais grave define o status', () {
      Map<String, dynamic> alerta(int id, String nivel, String status) => {
        'id': id,
        'tipo': 'X',
        'nivel': nivel,
        'status': status,
        'nivelEscalonamento': 1,
        'criadoEm': '17/11/2026 11:00:00',
        'idosoId': 1,
      };

      final painel = PainelIdoso.montar(
        idosoComTudo(
          alertas: [
            alerta(1, 'CRITICO', 'RESOLVIDO'),
            alerta(2, 'ALERTA', 'ABERTO'),
            alerta(3, 'ATENCAO', 'ESCALONADO'),
          ],
        ),
        eventos,
        agora: agora,
        limiteSemSinal: limite,
      );

      expect(painel.idoso.status, StatusIdoso.alerta);
      expect(painel.idoso.alertasAbertos, 2);
      expect(painel.alertas.first.idosoNome, 'Dona Maria');
    });

    test('sem sinal: heartbeat e eventos antigos', () {
      final painel = PainelIdoso.montar(
        idosoComTudo(heartbeat: '17/11/2026 08:00:00'),
        const [],
        agora: agora,
        limiteSemSinal: limite,
      );
      expect(painel.idoso.status, StatusIdoso.offline);
    });

    test('evento recente mantém o dispositivo online', () {
      final painel = PainelIdoso.montar(
        idosoComTudo(heartbeat: '17/11/2026 08:00:00'),
        [
          Evento(
            id: 9,
            tipo: 'HEARTBEAT',
            dataHora: DateTime(2026, 11, 17, 11, 58),
            dispositivoId: 5,
          ),
        ],
        agora: agora,
        limiteSemSinal: limite,
      );
      expect(painel.idoso.status, StatusIdoso.ok);
      expect(painel.dispositivos.single.ultimoSinal, DateTime(2026, 11, 17, 11, 58));
    });

    test('sem nenhum dispositivo também é sem sinal', () {
      expect(
        calcularStatus(
          alertas: const [],
          dispositivos: const [],
          agora: agora,
          limiteSemSinal: limite,
        ),
        StatusIdoso.offline,
      );
    });
  });
}
