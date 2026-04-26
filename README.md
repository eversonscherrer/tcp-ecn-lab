# AccECN TCP Experiment

Projeto limpo para testar TCP ECN/AccECN entre duas VMs Ubuntu no Proxmox.

- `accecn1`: server
- `accecn2`: client
- O Mac apenas orquestra via SSH.

## 1. Configurar

No Mac:

```bash
cd ~/accecn-tcp-experiment
cp .env.example .env
```

Edite `.env` com os IPs e usuários reais das VMs.

## 2. Testar Acesso

```bash
./scripts/check.sh
```

## 3. Instalar Dependências

```bash
./scripts/provision.sh
```

## 4. Rodar Teste Curto

```bash
./scripts/run.sh 5
```

## 5. Rodar Teste Normal

```bash
./scripts/run.sh 30
```

Resultados ficam em `results/`.

## O Que O Teste Faz

Para cada modo (`none`, `classic`, `accecn`):

1. Configura ECN nas duas VMs.
2. Aplica `tc` no egress do server.
3. Roda `iperf3 -R` do client para o server.
4. Captura handshake com `tcpdump`.
5. Coleta amostras com `ss`.
6. Baixa resultados para o Mac.
7. Gera `summary.csv`.

## Requisitos Nas VMs

Ubuntu Server com:

- SSH ativo
- usuário com `sudo`
- conectividade entre as duas VMs

O `provision.sh` instala:

- `iproute2`
- `iperf3`
- `tcpdump`
- `python3`

## AccECN

AccECN real depende do kernel expor:

```bash
sysctl net.ipv4.tcp_ecn_option
```

Se esse sysctl não existir, o modo `accecn` falha cedo. Isso é esperado.
