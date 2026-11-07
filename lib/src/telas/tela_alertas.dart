import '../core/ui/entrada.dart';
import '../core/ui/terminal.dart';
import '../core/validacao/validadores.dart';
import '../models/alerta.dart';
import '../models/enums.dart';
import '../services/alerta_service.dart';
import '../services/api_exception.dart';
import 'comum/formatacao.dart';

/// Quais alertas a tela mostra.
enum FiltroStatus {
  abertos('Abertos'),
  resolvidos('Resolvidos'),
  todos('Todos');

  const FiltroStatus(this.rotulo);
  final String rotulo;
}

/// Lista de alertas com filtros e confirmação.
///
/// Gerenciamento de estado: a tela guarda a lista de alertas e os filtros
/// escolhidos. Confirmar um alerta atualiza a lista em memória, e o contador
/// "Alertas abertos" muda na hora, sem buscar tudo de novo na API.
class TelaAlertas {
  TelaAlertas({
    required AlertaService alertaService,
    required this.entrada,
    this.idosoId,
    this.titulo = 'Alertas',
  }) : _servico = alertaService;

  final AlertaService _servico;
  final Entrada entrada;

  /// Quando informado, mostra só os alertas desse idoso.
  final int? idosoId;
  final String titulo;

  // ----- Estado da tela -----
  List<Alerta> _alertas = [];
  FiltroStatus _filtroStatus = FiltroStatus.abertos;
  NivelAlerta? _filtroNivel;

  int get alertasAbertos =>
      _alertas.where((alerta) => alerta.estaAberto).length;

  List<Alerta> get _visiveis => ordenarAlertas(_alertas.where((alerta) {
        final passaStatus = switch (_filtroStatus) {
          FiltroStatus.abertos => alerta.estaAberto,
          FiltroStatus.resolvidos => !alerta.estaAberto,
          FiltroStatus.todos => true,
        };
        final passaNivel = _filtroNivel == null || alerta.nivel == _filtroNivel;
        return passaStatus && passaNivel;
      }));

  Future<void> exibir() async {
    if (!await _carregar()) {
      entrada.pausar();
      return;
    }

    while (true) {
      entrada.limparTela();
      _mostrarLista();
      entrada.escrever('');

      final opcao = entrada.escolherOpcao([
        'Confirmar um alerta',
        'Filtrar por status',
        'Filtrar por nível',
        'Atualizar',
      ]);

      switch (opcao) {
        case 0:
          return;
        case 1:
          await _confirmar();
        case 2:
          _escolherFiltroStatus();
        case 3:
          _escolherFiltroNivel();
        case 4:
          if (!await _carregar()) entrada.pausar();
      }
    }
  }

  Future<bool> _carregar() async {
    try {
      _alertas = await _servico.listar(idosoId: idosoId);
      return true;
    } on ApiException catch (erro) {
      entrada.mostrarErro(erro.mensagem);
      return false;
    }
  }

  void _mostrarLista() {
    entrada.escrever(Terminal.cabecalho(titulo));
    entrada.escrever(
      'Filtro: ${_filtroStatus.rotulo} | '
      'Nível: ${_filtroNivel?.rotulo ?? 'todos'}',
    );

    final abertos = alertasAbertos;
    entrada.escrever(Terminal.colorir(
      'Alertas abertos: $abertos',
      abertos > 0 ? Cor.vermelho : Cor.verde,
    ));
    entrada.escrever('');

    final visiveis = _visiveis;
    if (visiveis.isEmpty) {
      entrada.escrever('  Nenhum alerta com esse filtro.');
      return;
    }
    for (var i = 0; i < visiveis.length; i++) {
      _mostrarAlerta(i + 1, visiveis[i]);
    }
  }

  void _mostrarAlerta(int numero, Alerta alerta) {
    final nome = alerta.idosoNome.isEmpty ? '' : '${alerta.idosoNome} - ';
    entrada.escrever(
      '  $numero) ${etiquetaNivel(alerta.nivel)} $nome${tituloDoAlerta(alerta)}',
    );
    if (alerta.descricao.isNotEmpty) {
      entrada.escrever('     ${alerta.descricao}');
    }

    final resolvidoEm = alerta.resolvidoEm;
    final String situacao;
    if (!alerta.estaAberto) {
      situacao = resolvidoEm == null
          ? 'Confirmado'
          : 'Confirmado: ${horario(resolvidoEm)}';
    } else if (alerta.status == StatusAlerta.escalonado) {
      situacao =
          'Escalonado: ${textoEscalonamento(alerta.nivelEscalonamento)}';
    } else {
      situacao = 'Aberto: ${textoEscalonamento(alerta.nivelEscalonamento)}';
    }

    entrada.escrever(Terminal.colorir(
      '     ${horario(alerta.criadoEm)} (${tempoDesde(alerta.criadoEm)}) | $situacao',
      Cor.cinza,
    ));
  }

  Future<void> _confirmar() async {
    final visiveis = _visiveis;
    if (!visiveis.any((alerta) => alerta.estaAberto)) {
      entrada.mostrarAviso('Não há alertas abertos para confirmar.');
      entrada.pausar();
      return;
    }

    final resposta = entrada.perguntar(
      'Número do alerta (0 para cancelar)',
      validar: (valor) {
        final erro = validarOpcao(valor, visiveis.length);
        if (erro != null) return erro;
        final numero = int.parse(valor!.trim());
        if (numero > 0 && !visiveis[numero - 1].estaAberto) {
          return 'Esse alerta já foi confirmado.';
        }
        return null;
      },
    );
    final numero = int.parse(resposta);
    if (numero == 0) return;

    final alerta = visiveis[numero - 1];
    final nome = alerta.idosoNome.isEmpty ? 'do idoso' : 'de ${alerta.idosoNome}';
    if (!entrada.confirmar('Confirmar o alerta $nome e parar os avisos?')) {
      entrada.mostrarAviso('Nada foi alterado.');
      entrada.pausar();
      return;
    }

    try {
      final confirmado = await _servico.confirmar(alerta.id);
      final antes = alertasAbertos;

      // Atualiza o estado: troca só o alerta confirmado na lista.
      _alertas = [
        for (final item in _alertas)
          if (item.id == alerta.id)
            item.copyWith(
              status: confirmado.status,
              resolvidoEm: confirmado.resolvidoEm ?? DateTime.now(),
            )
          else
            item,
      ];

      entrada.mostrarSucesso(
        'Alerta confirmado. Alertas abertos: $antes → $alertasAbertos',
      );
    } on ApiException catch (erro) {
      entrada.mostrarErro(erro.mensagem);
    }
    entrada.pausar();
  }

  void _escolherFiltroStatus() {
    entrada.escrever('');
    entrada.escrever('Mostrar quais alertas?');
    final opcao = entrada.escolherOpcao(
      [for (final filtro in FiltroStatus.values) filtro.rotulo],
      rotuloZero: 'Cancelar',
    );
    if (opcao > 0) _filtroStatus = FiltroStatus.values[opcao - 1];
  }

  void _escolherFiltroNivel() {
    entrada.escrever('');
    entrada.escrever('Qual nível?');
    final niveis = NivelAlerta.values.reversed.toList(); // crítico primeiro
    final opcao = entrada.escolherOpcao(
      ['Todos os níveis', for (final nivel in niveis) nivel.rotulo],
      rotuloZero: 'Cancelar',
    );
    if (opcao == 1) _filtroNivel = null;
    if (opcao > 1) _filtroNivel = niveis[opcao - 2];
  }
}
