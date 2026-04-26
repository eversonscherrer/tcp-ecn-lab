# Design do experimento

## Objetivo

Comparar empiricamente o comportamento do TCP Linux sob três configurações de Explicit Congestion Notification:

1. **No ECN** - congestionamento sinalizado apenas por perda
2. **Classic ECN** (RFC 3168) - sinalização ECN clássica
3. **AccECN** (RFC 9768) - feedback ECN mais preciso, quando suportado pelo kernel

## Topologia

O experimento roda dentro de uma VM Linux no VirtualBox. Client e server são namespaces de rede conectados por um par `veth`.

```text
VM Linux

┌──────────────────────────┐       veth       ┌──────────────────────────┐
│ netns accecn-client      │ <--------------> │ netns accecn-server      │
│ 10.99.0.20/24            │                  │ 10.99.0.10/24            │
│ iperf3 client + tcpdump  │                  │ iperf3 server + tc qdisc │
└──────────────────────────┘                  └──────────────────────────┘
```

O qdisc é aplicado no egress do namespace `accecn-server`. Por isso o cliente roda `iperf3 -R`: o fluxo principal sai do server, atravessa o qdisc e chega ao client.

## Hipóteses testáveis

- **H1**: No ECN tende a gerar mais retransmissões sob congestionamento.
- **H2**: Classic ECN reduz drops quando o AQM marca CE.
- **H3**: AccECN só é distinguível de Classic ECN quando o kernel negocia `tcp_ecn_option`.

## Variáveis controladas

| Variável | Valor padrão | Como alterar |
|---|---:|---|
| Rate bottleneck | 100 Mbps | `RATE=50mbit sudo ./scripts/run-all.sh 30` |
| Delay one-way | 25 ms | `DELAY=50ms` |
| Jitter | 2 ms | `JITTER=5ms` |
| Loss | 0% | `LOSS=0.5%` |
| Duração | 30 s | argumento de `run-experiment.sh` |
| AQM | `fq_codel ecn` | editar `scripts/setup-network.sh` |
| Congestion control | default do kernel | `sysctl net.ipv4.tcp_congestion_control` |

## Sysctls relevantes

| Sysctl | Significado |
|---|---|
| `net.ipv4.tcp_ecn` | 0=off, 1=ECN enabled |
| `net.ipv4.tcp_ecn_option` | 0=off, 1=accept, 2=request AccECN |
| `net.ipv4.tcp_ecn_fallback` | fallback automático em conexões problemáticas |
| `net.ipv4.tcp_congestion_control` | algoritmo TCP, como cubic ou bbr |

## Validação da negociação

Capture dentro da VM:

```bash
sudo NS=accecn-client ./scripts/validate-accecn.sh capture
```

Em conexão ativa:

```bash
sudo NS=accecn-client ./scripts/validate-accecn.sh inspect
```

Sinais esperados:

| Modo | SYN | SYN-ACK |
|---|---|---|
| No ECN | sem ECE/CWR/AE | sem ECE/CWR/AE |
| Classic ECN | ECE + CWR | ECE |
| AccECN | AE + ECE + CWR | AE/ECE, conforme suporte do kernel |

## Métricas coletadas

| Métrica | Fonte |
|---|---|
| Throughput por intervalo | `iperf3` JSON |
| Retransmissões | `iperf3` JSON |
| cwnd | amostras `ss -tin` |
| RTT | `iperf3` e `ss` |
| Handshake | `handshake.pcap` |

## Procedimento

No macOS:

```bash
ISO_PATH=/path/to/ubuntu-server.iso ./scripts/vm-create.sh
./scripts/vm-provision.sh
./scripts/vm-ssh.sh
```

Dentro da VM:

```bash
cd ~/accecn-tcp-experiment
sudo ./scripts/run-all.sh 30
python3 analysis/parse-results.py results/
python3 analysis/plot-results.py results/
```

## Análise estatística recomendada

Para resultados publicáveis:

- rode cada modo N >= 10 vezes;
- calcule média, desvio padrão e intervalo de confiança;
- varie `RATE`, `DELAY` e `LOSS`;
- compare retransmissões e throughput com testes não paramétricos quando a distribuição for assimétrica.

## Extensões possíveis

- Adicionar BBRv3 vs CUBIC como segunda dimensão.
- Trocar `fq_codel` por DualPI2 em kernel compatível.
- Criar uma terceira namespace como roteador intermediário.
- Coletar métricas via eBPF em vez de amostragem com `ss`.
