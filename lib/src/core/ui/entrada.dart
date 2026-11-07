import 'dart:convert';
import 'dart:io';

import '../validacao/validadores.dart';
import 'terminal.dart';

/// Lançada quando o usuário encerra a entrada (Ctrl+Z no Windows, Ctrl+D no Linux/Mac).
class EntradaEncerradaException implements Exception {
  const EntradaEncerradaException();

  @override
  String toString() => 'Entrada encerrada pelo usuário.';
}

/// Conversa com o usuário pelo terminal: perguntas com validação e mensagens.
///
/// Por padrão lê o teclado e escreve na tela. Nos testes, recebe funções
/// falsas no lugar de [lerLinha], [escrever] e [escreverPrompt].
class Entrada {
  Entrada({
    String? Function()? lerLinha,
    void Function(String texto)? escrever,
    void Function(String texto)? escreverPrompt,
  })  : _usandoTeclado = lerLinha == null,
        _lerLinha = lerLinha ?? _lerDoTeclado,
        _escrever = escrever ?? ((texto) => stdout.writeln(texto)),
        _escreverPrompt = escreverPrompt ?? ((texto) => stdout.write(texto));

  final bool _usandoTeclado;
  final String? Function() _lerLinha;
  final void Function(String texto) _escrever;
  final void Function(String texto) _escreverPrompt;

  static const Utf8Codec _utf8Tolerante = Utf8Codec(allowMalformed: true);

  static String? _lerDoTeclado() =>
      stdin.readLineSync(encoding: _utf8Tolerante);

  /// Pergunta até a resposta passar em [validar]. Remove espaços das pontas.
  String perguntar(String rotulo, {Validador? validar}) =>
      _perguntar(rotulo, validar: validar, aparar: true, esconder: false);

  /// Igual a [perguntar], mas sem mostrar o que é digitado.
  String perguntarSenha(String rotulo, {Validador? validar}) => _perguntar(
        rotulo,
        validar: validar,
        aparar: false,
        esconder: _usandoTeclado && stdin.hasTerminal,
      );

  String _perguntar(
    String rotulo, {
    required Validador? validar,
    required bool aparar,
    required bool esconder,
  }) {
    while (true) {
      _escreverPrompt('$rotulo: ');
      final resposta = esconder ? _lerEscondido() : _lerLinha();
      if (resposta == null) throw const EntradaEncerradaException();

      final valor = aparar ? resposta.trim() : resposta;
      final erro = validar?.call(valor);
      if (erro == null) return valor;
      mostrarErro(erro);
    }
  }

  String? _lerEscondido() {
    stdin.echoMode = false;
    try {
      return _lerLinha();
    } finally {
      stdin.echoMode = true;
      _escrever('');
    }
  }

  /// Lê um número de menu entre 0 e [maximo].
  int lerOpcao(int maximo) => int.parse(
        perguntar('Opção', validar: (valor) => validarOpcao(valor, maximo)),
      );

  /// Mostra [opcoes] numeradas a partir de 1, mais a opção 0 ([rotuloZero]),
  /// e devolve o número escolhido.
  int escolherOpcao(List<String> opcoes, {String rotuloZero = 'Voltar'}) {
    for (var i = 0; i < opcoes.length; i++) {
      _escrever('  ${i + 1}) ${opcoes[i]}');
    }
    _escrever('  0) $rotuloZero');
    return lerOpcao(opcoes.length);
  }

  void pausar() {
    _escreverPrompt('Pressione Enter para continuar...');
    if (_lerLinha() == null) throw const EntradaEncerradaException();
  }

  void escrever(String texto) => _escrever(texto);

  void mostrarSucesso(String mensagem) =>
      _escrever(Terminal.colorir('[OK] $mensagem', Cor.verde));

  void mostrarErro(String mensagem) =>
      _escrever(Terminal.colorir('[ERRO] $mensagem', Cor.vermelho));

  void mostrarAviso(String mensagem) =>
      _escrever(Terminal.colorir('[!] $mensagem', Cor.amarelo));

  /// Limpa a tela só quando está usando o terminal de verdade.
  void limparTela() {
    if (_usandoTeclado) Terminal.limparTela();
  }
}
