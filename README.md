## Networking experiments with OCaml 5's effects

Goal: port IP layer (TCP at some point) on top of OCaml 5's effects for 
more manageable async code.

Installation:
Requirements: 
- an opam switch with effects, such as `4.12.0+domains` or `5.00.0+trunk`
- a tap0 interface configured with 10.0.0.1/24 as an address

```
opam install --deps-only ./
dune exec test/ping_responder.exe
ping -i 0.1 10.0.0.2
```




## PING FLOOD


### 1400

`ping -f <IP> -s 1400

#### localhost
841069 paquets transmis, 841069 reçus, 0% packet loss, time 12578ms
rtt min/avg/max/mdev = 0.002/0.004/0.102/0.001 ms, ipg/ewma 0.014/0.006 ms

> 67k ping/sec


#### write

342399 paquets transmis, 342398 reçus, 0.000292057% packet loss, time 17101ms
rtt min/avg/max/mdev = 0.021/0.033/2.240/0.030 ms, ipg/ewma 0.049/0.037 ms

> 20023 ping/sec


#### writev

433487 paquets transmis, 433487 reçus, 0% packet loss, time 21906ms
rtt min/avg/max/mdev = 0.020/0.034/2.159/0.031 ms, ipg/ewma 0.050/0.040 ms

> 19793 ping/sec

### normal


#### write

#### writev

226284 paquets transmis, 226283 reçus, 0.000441923% packet loss, time 10557ms
rtt min/avg/max/mdev = 0.019/0.033/2.175/0.033 ms, ipg/ewma 0.046/0.046 ms

> 21550 ping/sec
