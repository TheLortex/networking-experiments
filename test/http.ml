module Eth = Ethernet.Make (Netif)
module Arp = Arp.Make (Eth)
module Ip = Static_ipv4.Make (Mirage_random_stdlib) (Mclock) (Eth) (Arp)
module Icmp = Icmpv4.Make (Ip)
module Udp = Udp.Make (Ip) (Mirage_random_stdlib)
module Tcp = Utcp_eio.Make_v4 (Mirage_random_stdlib) (Mclock) (Time) (Ip)

let ip_ignore ~src ~dst buffer = ignore (src, dst, buffer)

let echo_reply icmp ~proto ~src ~dst buffer =
  match proto with
  | 1 -> Icmp.input icmp ~src ~dst buffer
  | _ -> ignore (src, dst, buffer, proto)

let unwrap_result = function
  | Ok v -> v
  | Error trace -> Fmt.pr "%a" Error.pp_trace trace

type _ Eio.Generic.ty += Flow : Tcp.flow Eio.Generic.ty

let chunk_cs = Cstruct.create 10000 

class flow_obj (flow : Tcp.flow) =
  object (_ : < Eio.Flow.source ; Eio.Flow.sink ; .. >)
    (*
    method close = Tcp.close flow
  *)
    method probe : type a. a Eio.Generic.ty -> a option =
      function Flow -> Some flow | _ -> None

    method copy (src : #Eio.Flow.source) =
      try
        while true do
          let got = Eio.Flow.read src chunk_cs in
          match Tcp.write flow (Cstruct.sub chunk_cs 0 got) with
          | Ok () -> ()
          | Error _e -> ()
        done
      with End_of_file -> ()

    method read_into buf =
      match Tcp.read flow with
      | Ok (`Data buffer) ->
          Cstruct.blit buffer 0 buf 0 (Cstruct.length buffer);
          let len = Cstruct.length buffer in
          len
      | Ok `Eof -> raise End_of_file
      | Error _ -> raise End_of_file

    method read_methods = []

    method shutdown (_ : [ `All | `Receive | `Send ]) =
      Printf.printf "SHUTDOWN.\n%!";
      Tcp.close flow
  end

let handler ~sw (flow : Tcp.flow) =
  Eio.Private.Ctf.note_increase "http_handler" 1;
  let (eio_flow : #Eio.Flow.two_way) = new flow_obj flow in
  Wrk_bench.handle_connection ~sw eio_flow
    (`Tcp (Eio.Net.Ipaddr.V4.loopback, 8080));
  Eio.Private.Ctf.note_increase "http_handler" (-1);
  Tcp.close flow

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


let () =
  Logs.set_level (Some Warning);
  Logs.set_reporter (Logs_fmt.reporter ())

let () =(*
  Eio_unix.Ctf.with_tracing "trace.ctf" @@ fun () ->
  *)Printf.printf "Ready.\n%!";
  Eio_linux.run ~queue_depth:128 @@ fun env ->
  Eio.Std.Switch.run @@ fun sw -> test ~sw ~env ()
