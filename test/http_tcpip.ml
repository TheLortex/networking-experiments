module Eth = Ethernet.Make (Netif)
module Arp = Arp.Make (Eth)
module Ip = Static_ipv4.Make (Mirage_random_stdlib) (Mclock) (Eth) (Arp)
module Icmp = Icmpv4.Make (Ip)
module Udp = Udp.Make (Ip) (Mirage_random_stdlib)
module Tcp = Tcp.Flow.Make (Ip) (Mclock) (Mirage_random_stdlib)

let ip_ignore ~src ~dst buffer = ignore (src, dst, buffer)

let echo_reply icmp ~proto ~src ~dst buffer =
  match proto with
  | 1 -> Icmp.input icmp ~src ~dst buffer
  | _ -> ignore (src, dst, buffer, proto)

let unwrap_result = function
  | Ok v -> v
  | Error trace -> Fmt.pr "%a" Error.pp_trace trace

let handle_connection =
  Httpaf_eio.Server.create_connection_handler Wrk_bench.request_handler
    ~error_handler:Wrk_bench.error_handler

let handler ~sw (flow : < Eio.Flow.two_way ; Eio.Flow.close >) =
  Eio.Private.Ctf.note_increase "http_handler" 1;
  handle_connection ~sw
    (flow :> Eio.Flow.two_way)
    (`Tcp (Eio.Net.Ipaddr.V4.loopback, 8080));
  Eio.Private.Ctf.note_increase "http_handler" (-1);
  Eio.Flow.close flow

let test ~sw ~env () =
  let clock = Eio.Stdenv.clock env in
  let net = Netif.connect ~sw "tap1" in
  let t = Eth.connect net in
  let arp = Arp.connect ~sw t clock in
  let ip =
    Ip.connect ~cidr:(Ipaddr.V4.Prefix.of_string_exn "10.0.0.11/24") t arp
  in
  let icmp = Icmp.connect ip in
  let tcp = Tcp.connect ~sw ~clock ip in

  Tcp.listen tcp ~port:8080 (handler ~sw);

  Netif.listen net ~header_size:Ethernet.Packet.sizeof_ethernet
    (Eth.input ~arpv4:(Arp.input arp)
       ~ipv4:
         (Ip.input ~tcp:(Tcp.input tcp) ~udp:ip_ignore
            ~default:(echo_reply icmp) ip)
       ~ipv6:ignore t)
  |> unwrap_result

let _ =
  Sys.set_signal Sys.sigint
    (Sys.Signal_handle
       (fun _ ->
         Gc.print_stat stderr;
         exit 0))

let () =
  Logs.set_level (Some Info);
  Logs.set_reporter (Logs_fmt.reporter ())

let () =
  (* Eio_unix.Ctf.with_tracing ~size:1_500_000 "trace.ctf" @@ fun () -> *)
  Printf.printf "Ready.\n%!";
  ( Eio_linux.run @@ fun env ->
    Eio.Std.Switch.run @@ fun sw -> test ~sw ~env () );
  Printf.printf "The end.\n%!"
