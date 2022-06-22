module Eth = Ethernet.Make (Netif)
module Arp = Arp.Make (Eth)
module Ip = Static_ipv4.Make (Mirage_random_stdlib) (Mclock) (Eth) (Arp)
module Icmp = Icmpv4.Make (Ip)
module Udp = Udp.Make (Ip) (Mirage_random_stdlib)

let ip_ignore ~src ~dst buffer = ignore (src, dst, buffer)

let echo_reply icmp ~proto ~src ~dst buffer =
  match proto with
  | 1 -> Icmp.input icmp ~src ~dst buffer
  | _ -> ignore (src, dst, buffer, proto)

let count = ref 0

let _ =
  Sys.set_signal Sys.sigint
    (Sys.Signal_handle
       (fun _ ->
         Printf.printf "packets: %d\n%!" !count;
         exit 0))

let test ~sw ~env () =
  let net = Netif.connect ~sw "tap1" in
  let t = Eth.connect net in
  let arp = Arp.connect ~sw ~clock:(Eio.Stdenv.clock env) t  in
  let ip =
    Ip.connect ~cidr:(Ipaddr.V4.Prefix.of_string_exn "10.0.0.11/24") t arp
  in
  let icmp = Icmp.connect ip in
  let udp = Udp.connect ip in

  Udp.listen udp ~port:2115 (fun ~src:_ ~dst:_ ~src_port:_ _ ->
      Eio.Private.Ctf.label "incr";
      incr count);

  Netif.listen net ~header_size:Ethernet.Packet.sizeof_ethernet
    (Eth.input ~arpv4:(Arp.input arp)
       ~ipv4:
         (Ip.input ~tcp:ip_ignore ~udp:(Udp.input udp)
            ~default:(echo_reply icmp) ip)
       ~ipv6:ignore t)

let () =
  Printf.printf "Ready.\n%!";
  Eio_linux.run @@ fun env ->
  Eio.Std.Switch.run @@ fun sw -> test ~sw ~env ()
