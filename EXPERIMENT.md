# Design do experimento

## Objetivo

Comparar empiricamente o comportamento do TCP Linux sob três configurações de Explicit Congestion Notification:

1. **No ECN** — TCP puro, congestionamento sinalizado apenas por perda
2. **Classic ECN** (RFC 3168) — um sinal binário por RTT
3. **AccECN** (RFC 9768) — sinalização contínua e quantitativa por ACK

## Hipóteses testáveis

- **H1**: AccECN reduz retransmissões em relação a No ECN sob mesmo nível de congestionamento.
- **H2**: AccECN entrega throughput igual ou superior ao Classic ECN, com cwnd mais estável.
- **H3**: Sob AQM marcador (fq_codel ecn), tanto Classic ECN quanto AccECN evitam packet drops; sem AQM, todos se comportam similar a No ECN.

## Topologia

```
┌─────────────┐       labnet (10.99.0.0/24)       ┌─────────────┐
│   client    │ ─────────────────────────────────► │   server    │
│ 10.99.0.20  │ ◄───── tc qdisc (egress) ──────── │ 10.99.0.10  │
└─────────────┘                                   └─────────────┘
```

O qdisc é aplicado no **egress do servidor** porque é nessa direção que o tráfego bulk do `iperf3` flui (server → client por default no modo de download invertido, ou server-side processing). Para garantir que o impairment afete o caminho que importa, basta inverter `iperf3 -R` se necessário.

## Variáveis controladas

| Variável | Valor padrão | Como alterar |
|---|---|---|
| Rate bottleneck | 100 Mbps | `RATE=50mbit ./setup-network.sh apply` |
| Delay one-way | 25 ms | `DELAY=50ms` |
| Jitter | 2 ms | `JITTER=5ms` |
| Loss | 0% | `LOSS=0.5%` |
| Duração | 30 s | argumento do `run-experiment.sh` |
| AQM | fq_codel ecn | editar `setup-network.sh` |
| Congestion control | default (cubic) | `sysctl net.ipv4.tcp_congestion_control` |

## Sysctls relevantes

| Sysctl | Significado |
|---|---|
| `net.ipv4.tcp_ecn` | 0=off, 1=in/out, 2=in only |
| `net.ipv4.tcp_ecn_option` | 0=off, 1=accept, 2=request (AccECN) |
| `net.ipv4.tcp_ecn_fallback` | 1=fallback automático em conexões problemáticas |
| `net.ipv4.tcp_congestion_control` | algoritmo (cubic, bbr, etc.) |

## Validação da negociação

A diferença visível no handshake:

| Modo | SYN flags | SYN-ACK flags |
|---|---|---|
| No ECN | — | — |
| Classic ECN | ECE + CWR | ECE |
| AccECN | AE + ECE + CWR | AE + ECE (ou ECE) |

Capture com:
```bash
tcpdump -i eth0 -nn -vv 'tcp port 5201 and tcp[tcpflags] & tcp-syn != 0'
```

Em conexão ativa:
```bash
ss -tin '( dport = :5201 )' | grep -oE 'ecn|accecn|ecnseen'
```

## Métricas coletadas

| Métrica | Fonte | Uso |
|---|---|---|
| Throughput interval | iperf3 JSON `intervals[].sum.bits_per_second` | gráfico temporal |
| Retransmits | iperf3 JSON `end.sum_sent.retransmits` | barra comparativa |
| cwnd | `ss -tin` parser regex | linha temporal |
| RTT | iperf3 streams + `ss` | linha temporal |
| ECN marks | tcpdump (CE bit no IP header) | contagem |
| Handshake flags | pcap | validação binária |

## Procedimento (passo a passo)

1. Subir containers: `docker compose up -d --build`
2. Validar kernel: `docker exec accecn-server uname -r` (deve ser ≥ 6.18 para AccECN)
3. Rodar bateria: `./scripts/run-all.sh 30`
4. Parsear: `python3 analysis/parse-results.py results/`
5. Plotar: `python3 analysis/plot-results.py results/`
6. Inspecionar plots em `results/plots/`

## Análise estatística (recomendado)

Para resultados publicáveis:

- Repetir cada modo N ≥ 10 vezes
- Calcular média e desvio padrão por intervalo
- Plotar com banda de confiança (matplotlib `fill_between`)
- Teste de hipótese (Mann-Whitney U) para diferenças de retransmits/throughput

## Extensões possíveis

- Adicionar BBRv3 vs Cubic como segunda dimensão
- Substituir fq_codel por DualPI2 (requer kernel patcheado) para L4S real
- Adicionar terceiro container como roteador para topologia mais realista
- Coletar via eBPF em vez de `ss` para precisão temporal
