import '../../core/ui/entrada.dart';
import '../../services/api_exception.dart';

/// Mostra o erro da API e, se ela informar, o problema de cada campo.
void mostrarErroDaApi(Entrada entrada, ApiException erro) {
  entrada.mostrarErro(erro.mensagem);
  for (final campo in erro.campos.entries) {
    entrada.escrever('   - ${campo.key}: ${campo.value}');
  }
}
