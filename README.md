# AccECN TCP Experiment

Experimento para rodar em uma VM Linux no Proxmox e comparar três modos de TCP ECN:

1. **No ECN** - congestionamento sinalizado por perda
2. **Classic ECN** - ECN clássico
3. **AccECN** - Accurate ECN, quando o kernel suporta `tcp_ecn_option`

O Mac só orquestra via SSH. O laboratório real roda dentro da VM usando `ip netns`, `veth`, `tc`, `iperf3`, `tcpdump` e `ss`.

## Topologia

```text
Mac terminal
  |
  | SSH / rsync
  v
Proxmox VM Linux
  |
  +-- netns accecn-client 10.99.0.20
  |
  +-- veth pair
  |
  +-- netns accecn-server 10.99.0.10
        |
        +-- tc htb + netem + fq_codel ecn
```

O `iperf3` roda com `-R`, então o fluxo principal sai do server, atravessa o qdisc e chega ao client.

## Pré-requisitos

No Proxmox:

- Uma VM Linux com SSH habilitado
- Usuário com permissão de `sudo`
- Kernel com suporte a `ip netns`, `veth`, `htb`, `netem` e `fq_codel`
- Kernel com `net.ipv4.tcp_ecn_option` se você quiser testar AccECN real

No Mac:

- `ssh`
- `rsync`
- este repositório

## Fluxo Rápido

Defina o IP e usuário da VM:

```bash
export REMOTE_HOST=192.168.1.50
export REMOTE_USER=accecn
```

Ou crie um `.env`:

```bash
cp .env.example .env
```

Teste o acesso:

```bash
./scripts/remote-check.sh
```

Instale dependências e sincronize o projeto:

```bash
./scripts/remote-provision.sh
```

Rode uma bateria curta:

```bash
./scripts/remote-run.sh 5
```

Rode a bateria normal:

```bash
./scripts/remote-run.sh 30
```

Os resultados voltam para `results/` no Mac.

## VM no Proxmox

Crie a VM pelo Proxmox do jeito usual. Recomendações:

- Debian 12, Ubuntu Server 24.04/26.04, Fedora ou outra distro Linux moderna
- 2 vCPU
- 2 a 4 GB RAM
- 20 GB disco
- rede VirtIO
- OpenSSH instalado

Depois de instalar, descubra o IP:

```bash
ip addr
```

No Mac, teste:

```bash
ssh usuario@IP_DA_VM
```

## Comandos Remotos

Checar VM:

```bash
REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn ./scripts/remote-check.sh
```

Sincronizar projeto:

```bash
REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn ./scripts/remote-sync.sh
```

Provisionar:

```bash
REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn ./scripts/remote-provision.sh
```

Entrar por SSH:

```bash
REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn ./scripts/remote-ssh.sh
```

Rodar experimento e baixar resultados:

```bash
REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn ./scripts/remote-run.sh 30
```

Se o SSH usar outra porta:

```bash
REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn REMOTE_PORT=2222 ./scripts/remote-check.sh
```

## Rodar Diretamente Dentro da VM

Se preferir entrar na VM e rodar localmente:

```bash
cd ~/accecn-tcp-experiment
sudo ./scripts/run-all.sh 30
python3 analysis/parse-results.py results/
python3 analysis/plot-results.py results/
```

## Customização

Parâmetros de rede:

```bash
RATE=50mbit DELAY=50ms JITTER=5ms LOSS=0.5% sudo ./scripts/run-all.sh 30
```

Um modo apenas:

```bash
sudo ./scripts/run-experiment.sh classic 10
```

Validar handshake:

```bash
sudo ./scripts/setup-lab.sh apply
sudo NS=accecn-client ./scripts/validate-accecn.sh capture
```

## Limitações

Leia [docs/LIMITATIONS.md](docs/LIMITATIONS.md). O ponto mais importante: AccECN depende do kernel da VM. Se `sysctl net.ipv4.tcp_ecn_option` não existir, o modo `accecn` vai falhar cedo.
