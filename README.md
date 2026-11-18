# Tô Bem — App do familiar/cuidador (Dart puro)

Aplicação de terminal em **Dart puro** (sem Flutter) para o projeto Tô Bem —
Global Solution 2026/2 (CitizenTech), FIAP · Mobile Development.

**Todos os dados vêm da API Java** ([To-Bem/JAVA](https://github.com/To-Bem/JAVA)),
que roda em containers numa VM no Microsoft Azure. O app não tem dados mockados.

| | |
|---|---|
| Integrantes | Matheus Guimarães Rosa — RM 567912 · Lucas Shida Rodrigues da Costa — RM 568194 · Pedro Henrique Pinheiro Falchi — RM 566967 |
| Turma | 2TDSPS |
| Vídeo do app | https://youtu.be/-YyKNQjuFcQ |
| Executável | aba **Releases** deste repositório (`tobem.exe`, Windows) |

## O problema e quem se beneficia

No Brasil, cada vez mais idosos moram sozinhos. Uma queda ou um mal-estar pode levar
horas até alguém perceber. Câmeras resolvem, mas invadem a privacidade.

O Tô Bem usa uma **lâmpada com radar** (ESP32 + sensor mmWave) que percebe movimento,
queda e falta de atividade **sem nenhuma câmera**. Quando algo foge da rotina, o alerta
sobe em etapas: primeiro a própria lâmpada pisca e apita, depois a família é avisada e,
sem resposta, o próximo contato (cuidador ou vizinho).

- **Cidadão beneficiado:** o idoso que mora sozinho, que ganha segurança sem perder
  autonomia nem privacidade.
- **Também se beneficiam:** familiares e cuidadores, que acompanham à distância e são
  avisados na hora certa.
- **Este app** é o lado da família: mostra quem está bem e quem precisa de atenção,
  os alertas abertos, a linha do tempo da casa e permite cadastrar idosos, lâmpadas e rotinas.

### ODS relacionados

| ODS | Como o Tô Bem contribui |
|---|---|
| **3 — Saúde e bem-estar** | Resposta mais rápida a quedas e mal-estar; acompanhamento da rotina e do calor dentro de casa |
| **10 — Redução das desigualdades** | Tecnologia de baixo custo para que idosos continuem morando sozinhos com segurança |
| **11 — Cidades e comunidades sustentáveis** | Rede de cuidado entre família, cuidadores e vizinhos, com moradia segura para a população idosa |

## Requisitos

- Dart SDK 3.x
- A API Java rodando (por padrão em `http://localhost:8080`)

## Como rodar (passo a passo)

### 1. Use a API na nuvem ou suba a API local

**Na nuvem (Azure):** a API já está no ar na VM do projeto. Basta apontar o app para ela
e pular para o passo 2:

```powershell
$env:API_URL = "http://191.238.210.248:8080"
```

**Local:** no repositório JAVA, siga o README de lá. Resumo no PowerShell:

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

## Executável (publicação)

O app é publicado como executável na aba **Releases** do GitHub. Para gerar uma nova versão:

```powershell
dart compile exe bin/monitor_idoso.dart -o build/tobem.exe
```

No GitHub: **Releases → Draft a new release**, tag `v1.0.0`, anexe o `build/tobem.exe` e publique.
Para usar sem instalar o Dart:

```powershell
chcp 65001
$env:API_URL = "http://191.238.210.248:8080"
.\tobem.exe
```

## Como o app atende aos critérios da disciplina

| Critério | Onde está no app |
|---|---|
| **Navegação entre telas** (9 telas) | Login → Menu → Lista de idosos → Detalhe → Alertas / Cadastro de lâmpada / Cadastro de rotina; Monitoramento ao vivo. Cada tela é uma classe com `exibir()`; a opção `0` volta para a anterior, como uma pilha de navegação |
| **Protótipo visual** | Cabeçalhos, cores ANSI e etiquetas de status (`[ CRÍTICO ]`, `[ TUDO BEM ]`, `[ SEM SINAL ]`), lista ordenada do mais urgente ao que está bem |
| **Gerenciamento de estado** | Sessão do usuário (perfil ADMIN/MANAGER/MEMBER); contador de alertas abertos que muda ao confirmar (`2 → 1`); modo "fora de casa"; monitoramento que compara a leitura anterior com a atual e avisa o que mudou |
| **Formulários e validação** | Login e criar conta (e-mail, senha de 8 a 72 caracteres, confirmação); cadastro de idoso (nome, data com idade mínima de 60 anos, telefone, endereço, parentesco); lâmpada (cômodo) e rotina (horário hh:mm, 0 a 10 levantadas). Cada campo é validado na hora e pede de novo; os erros da API aparecem campo a campo |
| **Git e README** | Histórico de commits por camada; este README |

Recursos do Dart usados: classes e construtores `factory`, `enum` com campos, classes
`sealed` com `switch` por padrão, records, null safety, genéricos, `async`/`await`,
`Future.wait`, `Stream` com `async*`/`yield` e `await for`, exceções próprias,
`dart:io` (`HttpClient`, terminal) e `dart:convert` (JSON). Testes com o pacote `test`.

## Uso de IA

O grupo usou o Claude (Anthropic) como apoio no desenvolvimento: estrutura do projeto em
camadas, revisão de código, explicação de erros, integração com a API Java, testes e
documentação. Todo o código foi revisado, executado e testado pelo grupo.
