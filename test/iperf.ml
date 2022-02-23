module Eth = Ethernet.Make (Netif)
module Arp = Arp.Make (Eth)
module Ip = Static_ipv4.Make (Mirage_random_stdlib) (Mclock) (Eth) (Arp)
module Icmp = Icmpv4.Make (Ip)
module Udp = Udp.Make (Ip) (Mirage_random_stdlib)

let unwrap_result = function
  | Ok v -> v
  | Error trace -> Fmt.pr "%a" Error.pp_trace trace

let ip_ignore ~src ~dst buffer = ignore (src, dst, buffer)
let n_domains = 1
let n_sent = 16
let n_threads = 8
let cut = 1024
let size = 1350
let len = n_domains * n_sent * n_threads * cut * size
let () = Printf.printf "Packet size: %d (%d)\n" len (n_domains * n_sent * n_threads * cut)

(* 1MB buffer *)
let data_buf = Cstruct.create_unsafe size
let () = Cstruct.memset data_buf 60

let echo_reply icmp ~proto ~src ~dst buffer =
  match proto with
  | 1 -> Icmp.input icmp ~src ~dst buffer
  | _ -> ignore (src, dst, buffer, proto)


let test ~sw ~env () =
  let net = Netif.connect ~sw "tap0" in
  let t = Eth.connect net in
  let arp = Arp.connect ~sw t (Eio.Stdenv.clock env) in
  let ip =
    Ip.connect ~cidr:(Ipaddr.V4.Prefix.of_string_exn "10.0.0.10/24") t arp
  in
  let icmp = Icmp.connect ip in
  let udp = Udp.connect ip in
  Eio.Std.Fibre.fork ~sw (fun () ->
      Netif.listen net ~header_size:Ethernet.Packet.sizeof_ethernet
        (Eth.input ~arpv4:(Arp.input arp)
           ~ipv4:
             (Ip.input ~tcp:ip_ignore ~udp:(Udp.input udp)
                ~default:(echo_reply icmp) ip)
           ~ipv6:ignore t)
      |> unwrap_result);
  List.init n_domains (fun _ ->
      Eio.Domain_manager.run (Eio.Stdenv.domain_mgr env) @@ fun () ->
      List.init n_threads (fun _ () ->
          for _ = 0 to n_sent - 1 do
            for _ = 0 to cut - 1 do
              Udp.write
                ~dst:(Ipaddr.V4.of_string_exn "10.0.0.11")
                ~dst_port:2115 udp
                (Cstruct.sub data_buf 0 size)
              |> unwrap_result;
            done;
            Printf.printf ".%!"
          done)
      |> Eio.Std.Fibre.all)
  |> List.iter Fun.id;
  exit 0
(*
let () =
  Logs.set_level (Some Info);
  Logs.set_reporter (Logs_fmt.reporter ())
*)
let () =
  Eio_unix.Ctf.with_tracing "trace.ctf" @@ fun () ->
  Eio_linux.run @@ fun env ->
  Eio.Std.Switch.run @@ fun sw -> test ~sw ~env ()
