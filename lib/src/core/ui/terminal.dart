import 'dart:io';

/// Cores do terminal (códigos ANSI). É a "identidade visual" da aplicação:
/// verde = tudo bem, amarelo = atenção, vermelho = alerta, cinza = sem sinal.
enum Cor {
  verde('32'),
  amarelo('33'),
  vermelho('31'),
  vermelhoForte('1;31'),
  cinza('90'),
  azul('36'),
  negrito('1');

  const Cor(this.codigo);
  final String codigo;
}

/// Funções de apresentação no terminal.
class Terminal {
  Terminal._();

  /// Liga as cores só quando o terminal aceita códigos ANSI.
  /// Nos testes e em terminais antigos, o texto sai sem cor.
  static bool usarCores = stdout.hasTerminal && stdout.supportsAnsiEscapes;

  static String colorir(String texto, Cor cor) {
    if (!usarCores) return texto;
    return '\x1B[${cor.codigo}m$texto\x1B[0m';
  }

  /// Texto entre colchetes e colorido, ex.: [ ALERTA ].
  static String etiqueta(String texto, Cor cor) => colorir('[ $texto ]', cor);

  /// Título da tela entre duas linhas.
  static String cabecalho(String titulo, {int largura = 50}) {
    final linha = '=' * largura;
    return '$linha\n  ${titulo.toUpperCase()}\n$linha';
  }

  static void limparTela() {
    if (usarCores) stdout.write('\x1B[2J\x1B[H');
  }
}
