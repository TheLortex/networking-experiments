module B = struct
  module V = Netif
  module E = Ethernet.Make (V)
  module A = Arp.Make (E)
  module Ip4 = Static_ipv4.Make (Mirage_random_test) (Mclock) (E) (A)
  module Ip6 = Ipv6.Make (V) (E) (Mirage_random_test)
  module Icmp4 = Icmpv4.Make (Ip4)
  module I = Tcpip_stack_direct.IPV4V6 (Ip4) (Ip6)
  module U = Udp.Make (I) (Mirage_random_test)
  module T = Tcp.Flow.Make (I) (Mclock) (Mirage_random_test)

  module Stack =
    Tcpip_stack_direct.MakeV4V6 (Mirage_random_test) (Netif) (E) (A) (I) (Icmp4)
      (U)
      (T)

  let stack ~sw ~clock backend cidr =
    let v = V.connect ~sw backend in
    let e = E.connect v in
    let a = A.connect ~sw ~clock e in
    let i4 = Ip4.connect ~cidr e a in
    let i6 = Ip6.connect ~sw ~clock ~no_init:true v e in
    let i = I.connect ~ipv4_only:false ~ipv6_only:false i4 i6 in
    let u = U.connect i in
    let t = T.connect ~sw ~clock i in
    let icmp = Icmp4.connect i4 in
    Stack.connect ~sw v e a i icmp u t

  module Net = Tcpip_stack_eio.Make (Stack)

  let net = Net.net
end

module Example = struct
  open Eio

  let http_get ~net ~stdout addr =
    Switch.run @@ fun sw ->
    let flow = Net.connect ~sw net addr in
    Flow.copy_string "GET / HTTP/1.0\r\n\r\n" flow;
    Flow.shutdown flow `Send;
    Flow.copy flow stdout

end

let () =
  Logs.set_level (Some Info);
  Logs.set_reporter (Logs_fmt.reporter ())

let client ~sw ~stdenv =
  let stack =
    B.stack ~sw ~clock:stdenv#clock "tap0"
      (Ipaddr.V4.Prefix.of_string_exn "10.0.0.2/24")
  in
  let net = B.net stack in
  Example.http_get ~net ~stdout:stdenv#stdout
    (`Tcp (Eio.Net.Ipaddr.of_raw "\010\000\000\003", 8080))

let () =
  Eio_linux.run @@ fun stdenv ->
  Eio.Switch.run @@ fun sw -> client ~sw ~stdenv
