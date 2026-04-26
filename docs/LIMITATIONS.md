# Limitações conhecidas do experimento

Antes de tirar conclusões, é importante entender o que este setup mede — e o que ele **não** mede.

## 1. Containers compartilham o kernel do host

Docker e containerd não trazem seu próprio kernel. O kernel ativo é o do host. Isso significa:

- Se o host roda kernel **< 6.18**, o sysctl `tcp_ecn_option` não existe e o modo `accecn` se comportará como ECN clássico.
- A negociação AccECN só acontece se o kernel do host suportar.
- `uname -r` dentro do container mostra o kernel do **host**, não da imagem.

**Verifique antes:** `docker run --rm ubuntu:24.04 uname -r`

## 2. Kernel 7.0 ainda não está disponível em distros estáveis

Linux 7.0 saiu em abril de 2026 e ainda não está em Ubuntu LTS, RHEL, Debian estável. Opções práticas para quem quer kernel 7.0:

- **Distros rolling-release**: Arch, Fedora Rawhide, openSUSE Tumbleweed.
- **Ubuntu mainline**: pacotes em `kernel.ubuntu.com/mainline/`.
- **VM com kernel custom**: compile a partir de `kernel.org`.

Para o objetivo deste experimento — comparar **comportamento** do AccECN — qualquer kernel `>= 6.18` é suficiente. O que muda no 7.0 é apenas o default ativo, não a funcionalidade.

## 3. Bridge Docker tem limitações de qdisc

O qdisc é aplicado na interface `eth0` do container. Isso afeta o **egress** do container, não a interface bridge do host. Para topologias mais realistas:

- Use `--network host` e veth pares manuais.
- Considere `netns` direto (sem Docker) para controle total.
- Para topologia com router intermediário, adicione um terceiro container atuando como gateway com IP forwarding.

## 4. AccECN precisa de AQM marcador para mostrar valor

Sem um AQM que **marque** pacotes ECN-CE em vez de descartá-los, AccECN e ECN clássico se comportam como TCP comum. Por isso o `setup-network.sh` configura `fq_codel ecn` — sem isso, o experimento não revela diferença.

Variantes para experimentar:
- `fq_codel ecn` (default deste repo)
- `cake` (mais sofisticado, suporta ECN nativo)
- `red ecn` (clássico, RFC 2309)
- DualPI2 — necessário para L4S completo, mas requer patches/kernel específico.

## 5. Métricas de cwnd em containers podem ser ruidosas

`ss -tin` retorna cwnd em segmentos, mas o intervalo de coleta (0.5s) e a precisão variam. Para análise rigorosa:

- Use `bpftrace` ou eBPF probes em `tcp_cong_avoid`.
- Habilite `tcp_probe` (requer kernel module) para tracing por evento.
- Considere `ss -tinm` para ver mais detalhes de memória/buffer.

## 6. Variabilidade entre runs

Resultados em uma única execução podem não ser representativos. Para análise séria:

- Rode cada modo **N=10+** vezes.
- Calcule médias com intervalos de confiança.
- Varie `RATE`, `DELAY`, `LOSS` para mapear o espaço.

## 7. Este experimento não testa L4S completo

L4S = AccECN + DualPI2 (ou similar) + congestion control escalável (TCP Prague, BBRv3 com ECN). Este repo cobre apenas a parte do AccECN. Para L4S de ponta a ponta, é necessário um router intermediário com DualPI2 — não disponível em kernels mainline ainda.

## Resumo do que este experimento mostra de fato

✅ Negociação ECN/AccECN no handshake (via tcpdump)
✅ Diferença de comportamento sob AQM marcador
✅ Throughput, retransmissões, cwnd, RTT comparativos
✅ Reproduzibilidade básica em qualquer host Linux moderno

❌ Não mede L4S puro
❌ Não mede impacto em internet pública (depende de roteadores reais)
❌ Não substitui testes em escala
