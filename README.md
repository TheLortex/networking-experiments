## Networking experiments with OCaml 5's effects

Goal: port Mirage's TCP/IP stack on top of OCaml 5's effects for 
more manageable async code.

```
opam switch create 4.12.0+domains --repositories=multicore=git+https://github.com/ocaml-multicore/multicore-opam.git,default
opam install --deps-only ./ -t
dune runtest
```


## HTTP SERVER

Requirements: 
- a tap0 interface configured with 10.0.0.1/24 as an address

