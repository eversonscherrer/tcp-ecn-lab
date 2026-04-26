# AccECN TCP Experiment

Experimento reproduzível em uma VM Linux no VirtualBox para comparar empiricamente o comportamento do TCP em três configurações de ECN:

1. **No ECN** - TCP tradicional, congestionamento via packet loss
2. **Classic ECN** (RFC 3168) - sinalização ECN clássica
3. **AccECN** (RFC 9768) - feedback ECN mais preciso, quando o kernel suporta

O projeto roda no macOS usando VirtualBox, mas o experimento em si acontece dentro de uma VM Linux. Dentro da VM, os papéis de client e server são isolados com `ip netns`, ligados por um par `veth`, e o gargalo é criado com `tc`. O `iperf3` roda em modo reverse (`-R`) para o fluxo principal sair do server e atravessar o qdisc.

## TL;DR

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

Resultados em `results/plots/`.

## Pré-requisitos

No macOS:

- VirtualBox 7.x com `VBoxManage`
- Uma ISO de Ubuntu Server ou outra distro Linux compatível
- `ssh` e `rsync`

Cheque o host:

```bash
./scripts/vm-check.sh
```

Na VM Linux:

- Kernel **>= 6.18** para AccECN funcional
- qdiscs `htb`, `netem` e `fq_codel`
- `iproute2`, `iperf3`, `tcpdump`, `python3`

Verifique dentro da VM:

```bash
uname -r
sysctl net.ipv4.tcp_ecn_option
tc qdisc add dev lo root fq_codel ecn && tc qdisc del dev lo root
```

Se `tcp_ecn_option` não existir, o modo `accecn` não é suportado por esse kernel.

## Estrutura

```text
accecn-tcp-experiment/
├── scripts/
│   ├── vm-create.sh          # cria VM VirtualBox a partir de ISO
│   ├── vm-provision.sh       # instala dependências e sincroniza o repo
│   ├── vm-sync.sh            # sincroniza arquivos para a VM
│   ├── vm-ssh.sh             # entra na VM via SSH
│   ├── setup-lab.sh          # cria namespaces client/server
│   ├── configure-ecn.sh      # aplica modo ECN no namespace alvo
│   ├── setup-network.sh      # aplica tc/netem/fq_codel no link server->client
│   ├── validate-accecn.sh    # inspeciona handshake ou conexão ativa
│   ├── run-experiment.sh     # roda um modo
│   └── run-all.sh            # roda none/classic/accecn
├── analysis/
│   ├── parse-results.py
│   ├── plot-results.py
│   └── requirements.txt
├── docs/
│   ├── EXPERIMENT.md
│   └── LIMITATIONS.md
└── results/
```

## Uso

### 1. Criar a VM

Baixe uma ISO de Ubuntu Server e rode:

```bash
ISO_PATH="$HOME/Downloads/ubuntu-server.iso" ./scripts/vm-create.sh
```

Variáveis úteis:

```bash
VM_NAME=accecn-lab
VM_USER=accecn
VM_PASS=accecn
SSH_PORT=2222
VM_CPUS=2
VM_MEMORY_MB=4096
VM_DISK_MB=30000
```

### 2. Provisionar

Depois que a instalação da VM terminar e o SSH responder:

```bash
./scripts/vm-provision.sh
```

Esse comando sincroniza o repositório para `/home/accecn/accecn-tcp-experiment`, instala os pacotes necessários e testa a criação dos namespaces.

### 3. Rodar a bateria

```bash
./scripts/vm-ssh.sh
cd ~/accecn-tcp-experiment
sudo ./scripts/run-all.sh 30
```

Saída por modo em:

```text
results/<timestamp>-<mode>/
```

### 4. Analisar

Dentro da VM:

```bash
python3 analysis/parse-results.py results/
python3 analysis/plot-results.py results/
```

Gera:

- `results/summary.csv`
- `results/plots/throughput-comparison.png`
- `results/plots/retransmits-bar.png`
- `results/plots/cwnd-evolution.png`
- `results/plots/rtt-evolution.png`

## Customização

Variáveis de rede:

```bash
RATE=50mbit DELAY=50ms JITTER=5ms LOSS=0.5% sudo ./scripts/run-all.sh 30
```

Rodar apenas um modo:

```bash
sudo ./scripts/run-experiment.sh classic 10
```

Validar handshake:

```bash
sudo ./scripts/setup-lab.sh apply
sudo NS=accecn-client ./scripts/validate-accecn.sh capture
```

## Interpretação

Sob `fq_codel ecn`:

- **No ECN** tende a ter mais retransmissões.
- **Classic ECN** reduz drops quando há marcação CE.
- **AccECN** só pode ser observado se o kernel expõe `net.ipv4.tcp_ecn_option`.

A diferença entre Classic ECN e AccECN pode ser sutil com CUBIC. Para experimentos mais avançados, use um kernel e congestion control que consumam melhor feedback ECN granular.

## Limitações

Leia [docs/LIMITATIONS.md](docs/LIMITATIONS.md) antes de tirar conclusões.
