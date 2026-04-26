# Limitações

## Kernel da VM

Proxmox virtualiza hardware; ele não adiciona suporte de kernel. AccECN depende do kernel instalado dentro da VM.

Verifique:

```bash
uname -r
sysctl net.ipv4.tcp_ecn_option
```

Se `tcp_ecn_option` não existir, o modo `accecn` não é suportado.

## Uma VM, dois namespaces

Client e server rodam na mesma VM, isolados por `ip netns`. Isso é ótimo para reprodutibilidade, mas não mede efeitos de múltiplas máquinas físicas, switches reais ou roteamento externo.

## fq_codel não é L4S completo

`fq_codel ecn` marca pacotes CE e permite comparar ECN, mas não implementa uma topologia L4S completa. Para L4S real, seria necessário DualPI2 ou equivalente, além de congestion control escalável.

## Resultados variam

Uma execução curta serve para validar o pipeline, não para conclusão estatística. Para análise séria:

- rode cada modo várias vezes;
- varie `RATE`, `DELAY` e `LOSS`;
- calcule médias e intervalos de confiança;
- salve os pcaps para confirmar handshake ECN/AccECN.

## Acesso remoto

Os scripts `remote-*` assumem SSH funcional e usuário com `sudo`. Se o usuário exige senha para `sudo`, o terminal remoto pode pedir a senha durante `remote-provision.sh` ou `remote-run.sh`.
