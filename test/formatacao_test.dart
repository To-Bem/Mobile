import 'package:monitor_idoso/monitor_idoso.dart';
import 'package:test/test.dart';

void main() {
  final agora = DateTime(2026, 11, 7, 10, 0);

  group('tempoDesde', () {
    test('minutos, horas e dias', () {
      expect(tempoDesde(agora, agora: agora), 'agora mesmo');
      expect(
        tempoDesde(agora.subtract(const Duration(minutes: 23)), agora: agora),
        'há 23 min',
      );
      expect(
        tempoDesde(agora.subtract(const Duration(hours: 2)), agora: agora),
        'há 2 h',
      );
      expect(
        tempoDesde(
          agora.subtract(const Duration(hours: 2, minutes: 10)),
          agora: agora,
        ),
        'há 2 h 10 min',
      );
      expect(
        tempoDesde(agora.subtract(const Duration(days: 1)), agora: agora),
        'há 1 dia',
      );
      expect(
        tempoDesde(agora.subtract(const Duration(days: 3)), agora: agora),
        'há 3 dias',
      );
    });
  });

  group('horario', () {
    test('mostra só a hora quando é hoje', () {
      expect(horario(DateTime(2026, 11, 7, 9, 5), agora: agora), '09:05');
    });

    test('mostra a data quando é outro dia', () {
      expect(
        horario(DateTime(2026, 11, 6, 23, 40), agora: agora),
        '06/11 23:40',
      );
    });
  });

  test('dataBr', () {
    expect(dataBr(DateTime(1948, 3, 12)), '12/03/1948');
  });

  group('formatarTelefone', () {
    test('celular e fixo', () {
      expect(formatarTelefone('11988887777'), '(11) 98888-7777');
      expect(formatarTelefone('1133334444'), '(11) 3333-4444');
    });

    test('formato desconhecido fica como veio', () {
      expect(formatarTelefone('190'), '190');
    });
  });

  test('formatarDecimal usa vírgula', () {
    expect(formatarDecimal(31.5), '31,5');
    expect(formatarDecimal(30), '30,0');
  });

  test('ordenarPorPrioridade põe os urgentes primeiro', () {
    final ordenados = ordenarPorPrioridade(const [
      Idoso(nome: 'Bia', status: StatusIdoso.ok),
      Idoso(nome: 'Ari', status: StatusIdoso.ok),
      Idoso(nome: 'Caio', status: StatusIdoso.critico),
      Idoso(nome: 'Davi', status: StatusIdoso.atencao),
      Idoso(nome: 'Eva', status: StatusIdoso.offline),
    ]);

    expect(ordenados.map((idoso) => idoso.nome), [
      'Caio',
      'Eva',
      'Davi',
      'Ari',
      'Bia',
    ]);
  });

  group('alertas', () {
    Alerta alerta(int id, NivelAlerta nivel, StatusAlerta status, int hora) =>
        Alerta(
          id: id,
          idosoId: 1,
          tipo: 'X',
          nivel: nivel,
          status: status,
          criadoEm: DateTime(2026, 11, 7, hora),
        );

    test('ordenarAlertas: abertos por gravidade, depois resolvidos', () {
      final ordenados = ordenarAlertas([
        alerta(1, NivelAlerta.critico, StatusAlerta.resolvido, 9),
        alerta(2, NivelAlerta.atencao, StatusAlerta.aberto, 8),
        alerta(3, NivelAlerta.atencao, StatusAlerta.aberto, 10),
        alerta(4, NivelAlerta.critico, StatusAlerta.escalonado, 7),
        alerta(5, NivelAlerta.alerta, StatusAlerta.resolvido, 11),
      ]);

      expect(ordenados.map((a) => a.id), [4, 3, 2, 5, 1]);
    });

    test('textos de escalonamento e contagem', () {
      expect(textoEscalonamento(1), 'familiar avisado');
      expect(textoEscalonamento(2), '2º contato avisado');
      expect(textoEscalonamento(3), 'cuidador/agente de saúde avisado');
      expect(textoAbertos(0), 'nenhum aberto');
      expect(textoAbertos(1), '1 aberto');
      expect(textoAbertos(4), '4 abertos');
    });

    test('tipo desconhecido aparece com o próprio nome', () {
      expect(
        tituloDoAlerta(alerta(1, NivelAlerta.alerta, StatusAlerta.aberto, 9)),
        'X',
      );
    });
  });
}
