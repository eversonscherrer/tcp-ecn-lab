# Notes

Este repositório foi reiniciado para o fluxo Proxmox com duas VMs.

Topologia:

```text
accecn2 client ---- rede Proxmox ---- accecn1 server
                                      ^
                                      tc qdisc no egress
```

O `iperf3` roda com `-R`, então o tráfego pesado sai do server e passa pelo qdisc.
