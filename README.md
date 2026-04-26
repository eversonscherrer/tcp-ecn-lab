# AccECN TCP Experiment

Experimento reproduzível em containers Linux para comparar empiricamente o comportamento do TCP em três configurações de ECN:

1. **No ECN** — TCP tradicional, congestionamento via packet loss
2. **Classic ECN** (RFC 3168) — um sinal binário por RTT
3. **AccECN** (RFC 9768) — sinalização contínua e quantitativa por ACK

> **Por que isso importa:** AccECN se tornou o default no kernel Linux 7.0 (abril/2026), promovendo uma mudança que estava em desenvolvimento desde 2018. Antes que esteja em todas as distros estáveis, vale entender o que muda na prática.

## TL;DR

```bash
docker compose up -d --build
./scripts/run-all.sh 30
pip install -r analysis/requirements.txt
python3 analysis/parse-results.py results/
python3 analysis/plot-results.py results/
```

Resultados em `results/plots/`.

## Pré-requisitos

- Docker + Docker Compose v2
- Kernel host **≥ 6.18** para AccECN funcional (containers herdam o kernel do host)
- Python 3.10+ com `matplotlib` (para análise)
- `~500 MB` de espaço em disco

Verifique seu kernel:
```bash
uname -r
```

Se `< 6.18`, o modo `accecn` se comportará como ECN clássico. Veja [docs/LIMITATIONS.md](docs/LIMITATIONS.md) para alternativas.

## Estrutura do repositório

```
accecn-tcp-experiment/
├── README.md                    # este arquivo
├── docker-compose.yml           # client + server containers
├── docker/
│   ├── Dockerfile               # Ubuntu 24.04 + iperf3 + tools
│   └── entrypoint.sh
├── scripts/
│   ├── configure-ecn.sh         # aplica modo ECN via sysctl
│   ├── setup-network.sh         # tc qdisc + netem + fq_codel
│   ├── validate-accecn.sh       # inspeciona handshake
│   ├── run-experiment.sh        # roda 1 experimento
│   └── run-all.sh               # roda os 3 modos em sequência
├── analysis/
│   ├── parse-results.py         # iperf3/ss → CSV
│   ├── plot-results.py          # CSV → PNG
│   └── requirements.txt
├── results/                     # gerado pelos scripts
└── docs/
    ├── EXPERIMENT.md            # design detalhado
    └── LIMITATIONS.md           # o que este experimento NÃO mede
```

## Uso passo a passo

### 1. Subir o ambiente

```bash
docker compose up -d --build
docker compose ps     # confirma client e server up
```

### 2. Validar o kernel dentro do container

```bash
docker exec accecn-server uname -r
docker exec accecn-server sysctl net.ipv4.tcp_ecn_option
```

Se o sysctl `tcp_ecn_option` não existir, seu kernel não suporta AccECN (precisa ≥ 6.18).

### 3. Validar negociação ECN no handshake

Em um terminal:
```bash
docker exec accecn-client tcpdump -i eth0 -nn -vv \
    'tcp port 5201 and tcp[tcpflags] & tcp-syn != 0'
```

Em outro:
```bash
docker exec accecn-server /experiment/scripts/configure-ecn.sh accecn
docker exec -d accecn-server iperf3 -s -1
docker exec accecn-client iperf3 -c 10.99.0.10 -t 5
```

No `tcpdump`, procure por flags `[S], cksum ..., AE` no SYN do client e a reflexão no SYN-ACK do server.

### 4. Rodar a bateria completa

```bash
./scripts/run-all.sh 30      # 30s por modo
```

Saída em `results/<timestamp>-<mode>/`.

### 5. Análise

```bash
pip install -r analysis/requirements.txt
python3 analysis/parse-results.py results/
python3 analysis/plot-results.py results/
```

Gera em `results/plots/`:
- `throughput-comparison.png` — três linhas, throughput vs tempo
- `retransmits-bar.png` — total de retransmissões por modo
- `cwnd-evolution.png` — congestion window ao longo do tempo
- `rtt-evolution.png` — RTT ao longo do tempo
- `summary.csv` — tabela final consolidada

## Interpretando os resultados

**O que esperar sob `fq_codel ecn` ativo (default):**

- **No ECN**: maior número de retransmissões, throughput oscilante (efeito sawtooth clássico do Reno/Cubic).
- **Classic ECN**: retransmissões reduzidas (marcação substitui drop), mas cwnd ainda reage de forma binária.
- **AccECN**: mesmas vantagens de Classic ECN, mas com cwnd mais estável e ajuste mais granular conforme o feedback contínuo.

**Atenção**: a diferença entre Classic ECN e AccECN é **sutil** com Cubic. Para ver o impacto real do AccECN, troque o algoritmo para BBRv3 (que consome o feedback granular):

```bash
docker exec accecn-server sysctl -w net.ipv4.tcp_congestion_control=bbr
```

## Customização

Variáveis de ambiente para o tc/netem:

```bash
RATE=50mbit DELAY=50ms LOSS=0.5% \
    docker exec accecn-server /experiment/scripts/setup-network.sh apply
```

## Limitações

Este experimento tem várias limitações importantes — leia [docs/LIMITATIONS.md](docs/LIMITATIONS.md) antes de tirar conclusões.

Resumo:
- Containers compartilham kernel do host (não isolam AccECN)
- fq_codel ≠ DualPI2 (L4S completo requer roteador específico)
- Resultados em uma única run podem ser ruidosos — repita N×
- Não substitui testes em escala/internet pública

## Referências

- [RFC 9768 — Accurate ECN Feedback in TCP](https://datatracker.ietf.org/doc/rfc9768/)
- [RFC 9330 — L4S Architecture](https://datatracker.ietf.org/doc/rfc9330/)
- [LWN — More accurate congestion notification for TCP](https://lwn.net/)
- [Linux 7.0 release notes — KernelNewbies](https://kernelnewbies.org/Linux_7.0)

## Licença

MIT — veja `LICENSE`.

## Contribuindo

PRs bem-vindos para:
- Suporte a IPv6
- Integração com BBRv3
- Topologia com router DualPI2
- Coleta via eBPF/bpftrace
- Testes automatizados em CI
