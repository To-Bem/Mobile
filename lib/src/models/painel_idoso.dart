import '../core/utils/json_utils.dart';
import 'alerta.dart';
import 'contato.dart';
import 'dispositivo.dart';
import 'enums.dart';
import 'evento.dart';
import 'idoso.dart';
import 'rotina.dart';

/// Tudo o que o detalhe do idoso precisa, montado a partir de
/// GET /api/idosos/{id}/withAll + os eventos recentes de cada dispositivo.
class PainelIdoso {
  const PainelIdoso({
    required this.idoso,
    this.contatos = const [],
    this.rotinas = const [],
    this.dispositivos = const [],
    this.alertas = const [],
    this.eventos = const [],
  });

  /// Já com status, última atividade e alertas abertos calculados.
  final Idoso idoso;

  /// Na ordem em que serão avisados.
  final List<Contato> contatos;
  final List<Rotina> rotinas;

  /// Com [Dispositivo.ultimoSinal] preenchido.
  final List<Dispositivo> dispositivos;

  /// Do mais recente para o mais antigo.
  final List<Alerta> alertas;

  /// Do mais recente para o mais antigo, com o cômodo preenchido.
  final List<Evento> eventos;

  /// Última leitura de temperatura enviada pela lâmpada.
  double? get temperatura {
    for (final evento in eventos) {
      if (evento.ehTemperatura && evento.valor != null) return evento.valor;
    }
    return null;
  }

  /// Junta a resposta do withAll com os eventos e calcula a situação.
  factory PainelIdoso.montar(
    Map<String, dynamic> idosoComTudo,
    List<Evento> eventosDosDispositivos, {
    required DateTime agora,
    required Duration limiteSemSinal,
  }) {
    final base = Idoso.fromJson(idosoComTudo);

    final contatos = lerLista(idosoComTudo['contatos'], Contato.fromJson)
      ..sort((a, b) => a.ordemEscalonamento.compareTo(b.ordemEscalonamento));
    final rotinas = lerLista(idosoComTudo['rotinas'], Rotina.fromJson);
    final alertas = [
      for (final alerta in lerLista(idosoComTudo['alertas'], Alerta.fromJson))
        alerta.copyWith(idosoNome: base.nome),
    ]..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));

    final dispositivosDaApi = lerLista(
      idosoComTudo['dispositivos'],
      Dispositivo.fromJson,
    );
    final comodos = <int?, String>{
      for (final dispositivo in dispositivosDaApi)
        dispositivo.id: dispositivo.comodo,
    };
    final eventos = [
      for (final evento in eventosDosDispositivos)
        evento.copyWith(comodo: comodos[evento.dispositivoId]),
    ]..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    final dispositivos = [
      for (final dispositivo in dispositivosDaApi)
        dispositivo.copyWith(
          ultimoSinal: ultimoSinalDoDispositivo(dispositivo, eventos),
        ),
    ];

    DateTime? ultimaAtividade;
    for (final evento in eventos) {
      if (evento.indicaAtividade) {
        ultimaAtividade = evento.dataHora;
        break;
      }
    }

    final idoso = base.copyWith(
      status: calcularStatus(
        alertas: alertas,
        dispositivos: dispositivos,
        agora: agora,
        limiteSemSinal: limiteSemSinal,
      ),
      ultimaAtividade: ultimaAtividade,
      alertasAbertos: alertas.where((alerta) => alerta.estaAberto).length,
    );

    return PainelIdoso(
      idoso: idoso,
      contatos: contatos,
      rotinas: rotinas,
      dispositivos: dispositivos,
      alertas: alertas,
      eventos: eventos,
    );
  }
}

/// O mais recente entre o heartbeat registrado na API e o último evento
/// enviado pelo dispositivo.
DateTime? ultimoSinalDoDispositivo(
  Dispositivo dispositivo,
  List<Evento> eventos,
) {
  DateTime? sinal = dispositivo.ultimoHeartbeat;
  for (final evento in eventos) {
    if (evento.dispositivoId != dispositivo.id) continue;
    if (sinal == null || evento.dataHora.isAfter(sinal)) {
      sinal = evento.dataHora;
    }
  }
  return sinal;
}

/// Situação do idoso, do mais grave para o mais leve:
/// 1. o nível do alerta aberto mais grave (crítico, alerta, atenção);
/// 2. sem sinal: nenhum dispositivo cadastrado ou nenhum deles online;
/// 3. tudo bem.
StatusIdoso calcularStatus({
  required List<Alerta> alertas,
  required List<Dispositivo> dispositivos,
  required DateTime agora,
  required Duration limiteSemSinal,
}) {
  final niveisAbertos = {
    for (final alerta in alertas)
      if (alerta.estaAberto) alerta.nivel,
  };
  if (niveisAbertos.contains(NivelAlerta.critico)) return StatusIdoso.critico;
  if (niveisAbertos.contains(NivelAlerta.alerta)) return StatusIdoso.alerta;
  if (niveisAbertos.contains(NivelAlerta.atencao)) return StatusIdoso.atencao;

  final algumOnline = dispositivos.any(
    (dispositivo) => dispositivo.estaOnline(agora, limiteSemSinal),
  );
  return algumOnline ? StatusIdoso.ok : StatusIdoso.offline;
}
