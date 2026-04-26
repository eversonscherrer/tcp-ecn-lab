# Limitações conhecidas

Este projeto agora usa VirtualBox para evitar as limitações do Docker Desktop/LinuxKit no macOS. Ainda assim, algumas limitações continuam importantes.

## 1. O kernel da VM manda em tudo

AccECN depende do kernel Linux da VM. A imagem Ubuntu usada no disco não basta: é necessário que o kernel em execução exponha `net.ipv4.tcp_ecn_option`.

Verifique dentro da VM:

```bash
uname -r
sysctl net.ipv4.tcp_ecn_option
```

Se esse sysctl não existir, o modo `accecn` falha cedo.

## 2. VirtualBox não fornece o kernel

VirtualBox virtualiza hardware. Ele não adiciona suporte a AccECN nem qdiscs. Você ainda precisa instalar ou compilar um kernel adequado dentro da VM.

## 3. O experimento usa namespaces, não duas máquinas

Client e server ficam na mesma VM, isolados por `ip netns` e conectados por `veth`. Isso é ótimo para reprodutibilidade e controle, mas não reproduz todos os efeitos de placas, switches e roteadores reais.

## 4. fq_codel não é DualPI2

`fq_codel ecn` marca pacotes e permite comparar ECN/AccECN, mas não é uma topologia L4S completa. L4S de ponta a ponta exigiria AccECN, congestion control escalável e um roteador com DualPI2 ou equivalente.

## 5. Resultados de uma run são ruidosos

Para análise séria:

- rode cada modo várias vezes;
- varie `RATE`, `DELAY`, `LOSS`;
- calcule média e intervalo de confiança;
- capture também handshake e `ss -tin` para confirmar o estado TCP.

## 6. macOS só orquestra

Os scripts `vm-*` rodam no macOS, mas o experimento deve ser executado dentro da VM com `sudo`. Rodar `run-all.sh` diretamente no macOS não funciona, porque depende de `ip netns`, `tc`, `iperf3` e sysctls Linux.
