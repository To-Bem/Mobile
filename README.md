# Tô Bem — App do familiar/cuidador (Dart puro)

Aplicação de terminal em **Dart puro** (sem Flutter) para o projeto Tô Bem —
Global Solution 2026/2 (CitizenTech), FIAP.

A lâmpada com radar (ESP32) acompanha o idoso que mora sozinho, sem câmeras.
Este app é o lado da família: mostra quem está bem, quem precisa de atenção,
os alertas abertos e permite cadastrar idosos, lâmpadas e rotinas.

**Todos os dados vêm da API Java** ([To-Bem/JAVA](https://github.com/To-Bem/JAVA)).
O app não tem dados mockados.

## Requisitos

- Dart SDK 3.x
- A API Java rodando (por padrão em `http://localhost:8080`)

## Como rodar (passo a passo)

### 1. Suba a API Java

No repositório JAVA, siga o README de lá. Resumo no PowerShell:

```powershell
$env:ADMIN_EMAIL = 'admin@tobem.com'
$env:ADMIN_PASSWORD = 'Admin@12345'
mvn spring-boot:run
```

Sem `JWT_SECRET`, a API usa a chave de desenvolvimento do `application.yaml`.

### 2. Instale as dependências do app

```powershell
dart pub get
```

### 3. Prepare dados de demonstração (uma vez)

Em outro terminal, com as **mesmas** `ADMIN_EMAIL` e `ADMIN_PASSWORD` da API:

```powershell
$env:ADMIN_EMAIL = 'admin@tobem.com'
$env:ADMIN_PASSWORD = 'Admin@12345'
dart run tool/simular.dart preparar
```

Isso cria a conta `familiar.teste@example.com` / `Teste12345!`, dois idosos ligados
a ela, uma lâmpada e uma rotina para cada um. O comando mostra o número de cada lâmpada.
Rodar de novo não duplica nada.

### 4. Abra o app

```powershell
chcp 65001   # acentos no terminal do Windows
dart run
```

Entre com `familiar.teste@example.com` / `Teste12345!` (visão de familiar) ou com o
admin (vê todos os idosos). Também dá para criar uma conta nova pela opção **Criar conta**.

### 5. Simule a lâmpada durante a apresentação

Com o app aberto em **Monitoramento ao vivo**, em outro terminal:

```powershell
dart run tool/simular.dart queda 1         # alerta CRÍTICO
dart run tool/simular.dart inatividade 1   # alerta de nível ALERTA
dart run tool/simular.dart calor 2         # 34 °C + alerta de ATENÇÃO
dart run tool/simular.dart movimento 1     # a pessoa se mexeu
dart run tool/simular.dart saiu 1          # modo "fora de casa"
dart run tool/simular.dart voltou 1
dart run tool/simular.dart heartbeat 1     # renova o sinal da lâmpada
```

O número é o **id do dispositivo** (mostrado pelo `preparar` e no detalhe do idoso).
O simulador usa a conta ADMIN porque a API só aceita eventos e alertas de ADMIN/MANAGER.

## Variáveis de ambiente

| Variável | Padrão | Para quê |
|---|---|---|
| `API_URL` | `http://localhost:8080` | Endereço da API Java (ex.: IP da VM na Azure) |
| `MONITOR_SEGUNDOS` | `10` | Intervalo do monitoramento ao vivo |
| `SEM_SINAL_MINUTOS` | `15` | Sem heartbeat/evento por mais que isso, a lâmpada fica "sem sinal" |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | `admin@tobem.com` / `Admin@12345` | Conta usada pelo `tool/simular.dart` |

Exemplo apontando para a nuvem: `$env:API_URL="http://<IP da VM>:8080"; dart run`

## O que o app faz

| Tela | Perfil |
|---|---|
| Login e **Criar conta** (cadastro público da API) | todos |
| Menu com resumo: quantos idosos, quantos alertas, quem precisa de atenção | todos |
| Lista de idosos, do mais urgente ao que está bem | ADMIN/MANAGER: todos · MEMBER: os que acompanha |
| Detalhe: situação, dispositivos e último sinal, rotina, contatos, temperatura, linha do tempo | todos |
| Alertas: filtros por status e nível, confirmação (status RESOLVIDO) | todos |
| Cadastrar idoso (você vira o 1º contato), lâmpada/base e rotina | todos |
| Marcar "fora de casa" / "voltou" | só ADMIN/MANAGER (regra da API) |
| Monitoramento ao vivo (Stream), com bip quando algo piora | todos |

A situação de cada idoso (Tudo bem, Atenção, Alerta, Crítico, Sem sinal) é calculada
no app a partir dos alertas, dispositivos e eventos. Detalhes, rotas usadas e pontos a
alinhar com Java e IoT: [`docs/contrato-api.md`](docs/contrato-api.md).

## Testes

```powershell
dart analyze
dart test
```

Os testes não precisam da API no ar: usam uma imitação da API Java
(`test/apoio/api_java_falsa.dart`) com as mesmas rotas, formatos, permissões
por perfil e mensagens de erro.

## Estrutura

```
bin/monitor_idoso.dart        ponto de entrada
lib/src/core/                 configuração, terminal, entrada com validação, JSON
lib/src/models/               modelos espelhando os DTOs do Java
lib/src/services/             ApiClient (dart:io), autenticação, idosos, alertas, monitoramento
lib/src/telas/                telas do terminal
tool/simular.dart             faz o papel da lâmpada contra a API Java
test/                         testes (com a imitação da API em test/apoio)
docs/contrato-api.md          rotas usadas e pendências de integração
```
