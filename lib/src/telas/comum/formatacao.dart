import '../../core/ui/terminal.dart';
import '../../models/enums.dart';
import '../../models/idoso.dart';

// Funções de apresentação usadas pelas telas: cores de status, datas,
// telefone e ordenação por prioridade.

/// Acima desta temperatura dentro de casa, a tela mostra aviso de calor.
const double temperaturaDePerigo = 32;

Cor corDoStatus(StatusIdoso status) => switch (status) {
      StatusIdoso.ok => Cor.verde,
      StatusIdoso.atencao => Cor.amarelo,
      StatusIdoso.alerta => Cor.vermelho,
      StatusIdoso.critico => Cor.vermelhoForte,
      StatusIdoso.offline => Cor.cinza,
    };

/// Etiqueta curta e colorida, ex.: [ CRÍTICO ].
String etiquetaStatus(StatusIdoso status) {
  final texto = switch (status) {
    StatusIdoso.ok => 'OK',
    StatusIdoso.atencao => 'ATENÇÃO',
    StatusIdoso.alerta => 'ALERTA',
    StatusIdoso.critico => 'CRÍTICO',
    StatusIdoso.offline => 'SEM SINAL',
  };
  return Terminal.etiqueta(texto, corDoStatus(status));
}

/// Quanto menor, mais urgente.
int prioridadeDoStatus(StatusIdoso status) => switch (status) {
      StatusIdoso.critico => 0,
      StatusIdoso.alerta => 1,
      StatusIdoso.offline => 2,
      StatusIdoso.atencao => 3,
      StatusIdoso.ok => 4,
    };

/// Os mais urgentes primeiro; empate em ordem alfabética.
List<Idoso> ordenarPorPrioridade(List<Idoso> idosos) => [...idosos]
  ..sort((a, b) {
    final porStatus =
        prioridadeDoStatus(a.status).compareTo(prioridadeDoStatus(b.status));
    return porStatus != 0 ? porStatus : a.nome.compareTo(b.nome);
  });

String _doisDigitos(int numero) => numero.toString().padLeft(2, '0');

/// "agora mesmo", "há 23 min", "há 2 h 10 min", "há 3 dias".
String tempoDesde(DateTime momento, {DateTime? agora}) {
  final diferenca = (agora ?? DateTime.now()).difference(momento);
  if (diferenca.inMinutes < 1) return 'agora mesmo';
  if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
  if (diferenca.inHours < 24) {
    final horas = diferenca.inHours;
    final minutos = diferenca.inMinutes % 60;
    return minutos == 0 ? 'há $horas h' : 'há $horas h $minutos min';
  }
  final dias = diferenca.inDays;
  return dias == 1 ? 'há 1 dia' : 'há $dias dias';
}

/// "09:40" se for hoje; "06/11 09:40" se for outro dia.
String horario(DateTime momento, {DateTime? agora}) {
  final hoje = agora ?? DateTime.now();
  final horaMinuto =
      '${_doisDigitos(momento.hour)}:${_doisDigitos(momento.minute)}';
  final mesmoDia = momento.year == hoje.year &&
      momento.month == hoje.month &&
      momento.day == hoje.day;
  if (mesmoDia) return horaMinuto;
  return '${_doisDigitos(momento.day)}/${_doisDigitos(momento.month)} $horaMinuto';
}

String dataBr(DateTime data) =>
    '${_doisDigitos(data.day)}/${_doisDigitos(data.month)}/${data.year}';

/// 11988887777 -> (11) 98888-7777 · 1133334444 -> (11) 3333-4444.
String formatarTelefone(String telefone) {
  final digitos = telefone.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 11) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7)}';
  }
  if (digitos.length == 10) {
    return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6)}';
  }
  return telefone;
}

/// 31.5 -> "31,5".
String formatarDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');
