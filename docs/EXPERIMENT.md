# Design do experimento

## Objetivo

Comparar o comportamento do TCP Linux em três modos:

- `none`: ECN desligado
- `classic`: ECN clássico
- `accecn`: Accurate ECN, exigindo `net.ipv4.tcp_ecn_option`

## Ambiente

O experimento roda dentro de uma única VM Linux no Proxmox. A VM contém dois namespaces de rede:

```text
accecn-client 10.99.0.20  <--- veth --->  accecn-server 10.99.0.10
```

O qdisc é aplicado no egress de `accecn-server:veth-server`.

## Fluxo de tráfego

O cliente executa:

```bash
iperf3 -c 10.99.0.10 -R
```

Com `-R`, o server envia o fluxo principal para o client. Isso garante que o tráfego passe pelo qdisc no lado server.

## Qdisc

O padrão é:

```text
htb rate limit
  -> netem delay/jitter/loss
    -> fq_codel ecn
```

Variáveis:

| Variável | Padrão |
|---|---:|
| `RATE` | `100mbit` |
| `DELAY` | `25ms` |
| `JITTER` | `2ms` |
| `LOSS` | `0%` |

## Coleta

Por modo, o script salva:

- `iperf-client.json`
- `iperf-server.json`
- `handshake.pcap`
- `ss-samples.log`
- logs de ECN e qdisc

Depois:

- `analysis/parse-results.py` gera CSVs
- `analysis/plot-results.py` gera PNGs

## Validações

Antes de confiar nos resultados:

```bash
uname -r
sysctl net.ipv4.tcp_ecn
sysctl net.ipv4.tcp_ecn_option
tc qdisc add dev lo root fq_codel ecn
tc qdisc del dev lo root
```

Se `tcp_ecn_option` não existir, AccECN real não está disponível nesse kernel.
