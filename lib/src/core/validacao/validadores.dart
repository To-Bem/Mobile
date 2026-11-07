// Validadores de entrada.
// Seguem o formato `String? Function(String?)`: devolvem null quando o valor
// está certo, ou a mensagem de erro para mostrar ao usuário.

typedef Validador = String? Function(String? valor);

final RegExp _formatoEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

String? validarObrigatorio(String? valor, [String campo = 'Campo']) {
  if (valor == null || valor.trim().isEmpty) {
    return '$campo: preenchimento obrigatório.';
  }
  return null;
}

String? validarEmail(String? valor) {
  final vazio = validarObrigatorio(valor, 'E-mail');
  if (vazio != null) return vazio;
  if (!_formatoEmail.hasMatch(valor!.trim())) {
    return 'E-mail inválido. Use o formato nome@email.com.';
  }
  return null;
}

String? validarSenha(String? valor) {
  final vazio = validarObrigatorio(valor, 'Senha');
  if (vazio != null) return vazio;
  if (valor!.length < 6) return 'A senha precisa ter pelo menos 6 caracteres.';
  return null;
}

/// Número de menu entre 0 e [maximo].
String? validarOpcao(String? valor, int maximo) {
  final numero = int.tryParse(valor?.trim() ?? '');
  if (numero == null || numero < 0 || numero > maximo) {
    return 'Digite um número de 0 a $maximo.';
  }
  return null;
}

const List<String> _respostasSimNao = ['s', 'sim', 'n', 'nao', 'não'];

/// Aceita s, sim, n, nao ou não (maiúsculas ou minúsculas).
String? validarSimNao(String? valor) {
  final texto = (valor ?? '').trim().toLowerCase();
  if (_respostasSimNao.contains(texto)) return null;
  return 'Responda s (sim) ou n (não).';
}

/// true quando a resposta (já validada) é sim.
bool respostaSim(String valor) => valor.trim().toLowerCase().startsWith('s');
