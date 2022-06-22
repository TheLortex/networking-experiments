## Networking experiments with OCaml 5's effects

Goal: port Mirage's TCP/IP stack on top of OCaml 5's effects for 
more manageable async code.

### Creating a 4.12.0+domains switch

```
opam switch create 4.12.0+domains --repositories=multicore=git+https://github.com/ocaml-multicore/multicore-opam.git,default
```

### Creating a 5.0.0+trunk switch

```
opam switch create 5.0.0+trunk --repositories=alpha=git+https://github.com/kit-ty-kate/opam-alpha-repository.git,default
```

Optional: install lsp server: 
```
opam pin -y git+https://github.com/patricoferris/ocaml-lsp#dc9a4ef8529628fe023e1ed034ffe6b517ea4f1a
```

### Installing the project

```
git clone --recursive https://github.com/TheLortex/networking-experiments
cd networking-experiments
opam install --deps-only ./ -t
dune runtest
```


## HTTP SERVER

Requirements: 
- a tap0 interface configured with 10.0.0.1/24 as an address

Bench:
- `dune exec test/http_tcpip.exe`
- `wrk -t16 -c256 -d5s http://10.0.0.11:8080/`

Results (lots of variation):
```
wrk 4.2.0 [epoll] Copyright (C) 2012 Will Glozer
Running 5s test @ http://10.0.0.11:8080/
  16 threads and 256 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    20.21ms    2.08ms  41.94ms   92.28%
    Req/Sec   792.44     90.29     1.37k    91.36%
  63913 requests in 5.10s, 127.75MB read
Requests/sec:  12535.60
Transfer/sec:     25.06MB
```

## TCP SPEED

### Original mirage-tcpip:

- without pcap recording 
```
test.exe: [INFO] Iperf server: t = 692458038, avg_rate = 1155.30 MBits/s, totbytes = 100000000, live_words = 143408
```

- with pcap recording
```
test.exe: [INFO] Iperf server: t = 1000016465, avg_rate = 553.78 MBits/s, totbytes = 69223140, live_words = 131837
test.exe: [INFO] Iperf server: t = 1441745933, avg_rate = 554.88 MBits/s, totbytes = 100000000, live_words = 101111
```

### Eio mirage-tcpip:

- without pcap recording
```
test.exe: [INFO] Iperf server: t = 1000014908, avg_rate = 790.52 MBits/s, totbytes = 98815900, live_words = 65104
test.exe: [INFO] Iperf server: t = 1012995882, avg_rate = 789.74 MBits/s, totbytes = 100000000, live_words = 64879
```

- with pcap recording
```
test.exe: [INFO] Iperf server: t = 1000298217, avg_rate = 235.22 MBits/s, totbytes = 29411320, live_words = 4463730
test.exe: [INFO] Iperf server: t = 2000327795, avg_rate = 241.19 MBits/s, totbytes = 59560600, live_words = 8970173
test.exe: [INFO] Iperf server: t = 3000669694, avg_rate = 248.89 MBits/s, totbytes = 90682200, live_words = 13622019
```
