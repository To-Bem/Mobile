// Validadores de entrada.
// Seguem o formato `String? Function(String?)`: devolvem null quando o valor
// está certo, ou a mensagem de erro para mostrar ao usuário.

typedef Validador = String? Function(String? valor);

final RegExp _formatoEmail = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');
final RegExp _formatoNome = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");
final RegExp _formatoDataBr = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
final RegExp _naoDigitos = RegExp(r'\D');
final RegExp _temDigito = RegExp(r'\d');

/// Idade mínima para ser acompanhado (Estatuto da Pessoa Idosa: 60 anos).
const int idadeMinimaIdoso = 60;

/// Quantos contatos podem estar na fila de aviso.
const int maximoOrdemEscalonamento = 5;

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

// ---------------------------------------------------------------------------
// Cadastros
// ---------------------------------------------------------------------------

/// Letras (com acento), espaços, apóstrofo e hífen. Mínimo de 3 letras.
String? validarNome(String? valor) {
  final vazio = validarObrigatorio(valor, 'Nome');
  if (vazio != null) return vazio;
  final nome = valor!.trim();
  if (nome.replaceAll(' ', '').length < 3) {
    return 'Nome muito curto. Use pelo menos 3 letras.';
  }
  if (!_formatoNome.hasMatch(nome)) {
    return 'Use só letras e espaços no nome.';
  }
  return null;
}

/// "12/03/1948" -> DateTime(1948, 3, 12).
/// Devolve null se o formato estiver errado ou a data não existir (ex.: 31/02).
DateTime? converterDataBr(String? valor) {
  final partes = _formatoDataBr.firstMatch(valor?.trim() ?? '');
  if (partes == null) return null;

  final dia = int.parse(partes.group(1)!);
  final mes = int.parse(partes.group(2)!);
  final ano = int.parse(partes.group(3)!);
  final data = DateTime(ano, mes, dia);

  // DateTime(2026, 2, 31) "transborda" para março; isso indica data inexistente.
  if (data.day != dia || data.month != mes || data.year != ano) return null;
  return data;
}

int calcularIdade(DateTime nascimento, DateTime hoje) {
  var anos = hoje.year - nascimento.year;
  final aindaNaoFezAniversario = hoje.month < nascimento.month ||
      (hoje.month == nascimento.month && hoje.day < nascimento.day);
  if (aindaNaoFezAniversario) anos--;
  return anos;
}

/// Data no formato dd/mm/aaaa, não futura, de alguém com 60 anos ou mais.
/// [hoje] existe só para os testes.
String? validarDataNascimento(String? valor, {DateTime? hoje}) {
  final vazio = validarObrigatorio(valor, 'Data de nascimento');
  if (vazio != null) return vazio;

  final data = converterDataBr(valor);
  if (data == null) return 'Data inválida. Use o formato dd/mm/aaaa.';

  final agora = hoje ?? DateTime.now();
  if (data.isAfter(agora)) return 'A data não pode estar no futuro.';

  final idade = calcularIdade(data, agora);
  if (idade < idadeMinimaIdoso) {
    return 'O monitoramento é para pessoas com $idadeMinimaIdoso anos ou mais '
        '(esta pessoa tem $idade).';
  }
  if (idade > 120) return 'Confira o ano: a idade passou de 120 anos.';
  return null;
}

String somenteDigitos(String valor) => valor.replaceAll(_naoDigitos, '');

/// DDD + número, com ou sem pontuação: (11) 98888-7777, 11988887777, 1133334444.
String? validarTelefone(String? valor) {
  final vazio = validarObrigatorio(valor, 'Telefone');
  if (vazio != null) return vazio;

  final digitos = somenteDigitos(valor!);
  if (digitos.length != 10 && digitos.length != 11) {
    return 'Telefone inválido. Use DDD + número, ex.: (11) 98888-7777.';
  }
  if (int.parse(digitos.substring(0, 2)) < 11) return 'DDD inválido.';
  if (digitos.length == 11 && digitos[2] != '9') {
    return 'Celular com 11 dígitos precisa ter 9 depois do DDD.';
  }
  return null;
}

/// Rua e número (ou "s/n").
String? validarEndereco(String? valor) {
  final vazio = validarObrigatorio(valor, 'Endereço');
  if (vazio != null) return vazio;
  final endereco = valor!.trim();
  if (endereco.length < 5) return 'Endereço muito curto. Informe rua e número.';
  if (!_temDigito.hasMatch(endereco) &&
      !endereco.toLowerCase().contains('s/n')) {
    return 'Inclua o número da casa (ou s/n).';
  }
  return null;
}

/// 1 = avisado primeiro, até [maximoOrdemEscalonamento].
String? validarOrdemEscalonamento(String? valor) {
  final ordem = int.tryParse(valor?.trim() ?? '');
  if (ordem == null || ordem < 1 || ordem > maximoOrdemEscalonamento) {
    return 'Use um número de 1 a $maximoOrdemEscalonamento '
        '(1 = avisado primeiro).';
  }
  return null;
}
