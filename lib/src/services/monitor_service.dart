import '../core/config/app_config.dart';
import '../models/enums.dart';
import '../models/idoso.dart';
import 'api_exception.dart';
import 'idoso_service.dart';

/// Resultado de uma consulta do monitoramento.
/// É `sealed`: toda leitura é obrigatoriamente [LeituraOk] ou [LeituraFalhou],
/// e o `switch` de quem usa precisa tratar os dois casos.
sealed class LeituraMonitor {
  const LeituraMonitor(this.momento);

  final DateTime momento;
}

final class LeituraOk extends LeituraMonitor {
  const LeituraOk(this.idosos, super.momento);

  final List<Idoso> idosos;
}

final class LeituraFalhou extends LeituraMonitor {
  const LeituraFalhou(this.erro, super.momento);

  final ApiException erro;
}

/// O que mudou com um idoso entre duas leituras.
class Mudanca {
  const Mudanca({required this.anterior, required this.atual});

  final Idoso anterior;
  final Idoso atual;

  bool get statusMudou => atual.status != anterior.status;

  bool get piorou =>
      gravidadeDoStatus(atual.status) > gravidadeDoStatus(anterior.status);

  int get novosAlertas => atual.alertasAbertos > anterior.alertasAbertos
      ? atual.alertasAbertos - anterior.alertasAbertos
      : 0;

  bool get modoMudou => atual.modo != anterior.modo;

  bool get relevante => statusMudou || novosAlertas > 0 || modoMudou;
}

/// Quanto maior, mais grave.
int gravidadeDoStatus(StatusIdoso status) => switch (status) {
      StatusIdoso.ok => 0,
      StatusIdoso.atencao => 1,
      StatusIdoso.offline => 2,
      StatusIdoso.alerta => 3,
      StatusIdoso.critico => 4,
    };

/// Compara duas leituras e devolve só os idosos em que algo importante mudou.
/// Idosos que aparecem pela primeira vez em [depois] são ignorados.
List<Mudanca> compararLeituras(List<Idoso> antes, List<Idoso> depois) {
  final anteriores = <int?, Idoso>{
    for (final idoso in antes) idoso.id: idoso,
  };

  final mudancas = <Mudanca>[];
  for (final atual in depois) {
    final anterior = anteriores[atual.id];
    if (anterior == null) continue;
    final mudanca = Mudanca(anterior: anterior, atual: atual);
    if (mudanca.relevante) mudancas.add(mudanca);
  }
  return mudancas;
}

/// Consulta a API de tempos em tempos e entrega cada resultado num [Stream].
class MonitorService {
  MonitorService(this._idosos, {Duration? intervalo})
      : intervalo = intervalo ?? AppConfig.intervaloMonitor {
    if (this.intervalo <= Duration.zero) {
      throw ArgumentError.value(
        this.intervalo,
        'intervalo',
        'precisa ser maior que zero',
      );
    }
  }

  final IdosoService _idosos;
  final Duration intervalo;

  /// Quantas consultas cabem em [duracao] (a primeira é imediata).
  int leiturasPara(Duration duracao) =>
      duracao.inMicroseconds ~/ intervalo.inMicroseconds + 1;

  /// Faz [quantidade] consultas, uma a cada [intervalo].
  ///
  /// Uma falha na API não encerra o Stream: vira um [LeituraFalhou]
  /// e o monitoramento continua tentando.
  Stream<LeituraMonitor> leituras(int quantidade) async* {
    for (var i = 0; i < quantidade; i++) {
      if (i > 0) await Future<void>.delayed(intervalo);
      yield await _ler();
    }
  }

  Future<LeituraMonitor> _ler() async {
    try {
      return LeituraOk(await _idosos.listar(), DateTime.now());
    } on ApiException catch (erro) {
      return LeituraFalhou(erro, DateTime.now());
    }
  }
}
