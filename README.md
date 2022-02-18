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


