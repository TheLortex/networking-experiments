(*
 * Copyright (C) 2013 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
 * REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
 * INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
 * LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
 * OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *)
module Eth = Ethernet.Make (Netif)
module Arp = Arp.Make (Eth)
module Ip = Static_ipv4.Make (Mirage_random_stdlib) (Mclock) (Eth) (Arp)
module Icmp = Icmpv4.Make (Ip)

let run test =
  Eio_linux.run @@ fun env ->
  Eio.Std.Switch.run @@ fun sw -> test ~sw ~env ()

let unwrap_result = function
  | Ok v -> v
  | Error trace -> Fmt.pr "%a" Error.pp_trace trace

let ip_ignore ~src ~dst buffer = ignore (src, dst, buffer)

let echo_reply icmp ~proto ~src ~dst buffer =
  match proto with
  | 1 ->
      Printf.printf "Input.\n%!";
      Icmp.input icmp ~src ~dst buffer
  | _ -> ignore (src, dst, buffer, proto)

let test_write ~sw ~env () =
  let net = Netif.connect ~sw "tap1" in
  let t = Eth.connect net in
  let arp = Arp.connect ~sw t (Eio.Stdenv.clock env) in
  let ip =
    Ip.connect ~cidr:(Ipaddr.V4.Prefix.of_string_exn "10.0.0.11/24") t arp
  in
  let icmp = Icmp.connect ip in
  Eio.Std.Fibre.fork ~sw (fun () ->
      Netif.listen net ~header_size:Ethernet.Packet.sizeof_ethernet
        (Eth.input ~arpv4:(Arp.input arp)
           ~ipv4:
             (Ip.input ~tcp:ip_ignore ~udp:ip_ignore ~default:(echo_reply icmp)
                ip)
           ~ipv6:ignore t)
      |> unwrap_result);
  for i = 0 to 128 do
    Icmp.write icmp
      ~src:(Ipaddr.V4.of_string_exn "10.0.0.11")
      ~dst:(Ipaddr.V4.of_string_exn "10.0.0.10")
      ~ttl:64
      (Icmpv4_packet.Marshal.make_cstruct
         {
           Icmpv4_packet.code = 0x00;
           ty = Icmpv4_wire.Echo_request;
           subheader = Id_and_seq (2 * i, i);
         }
         ~payload:Cstruct.empty)
    |> unwrap_result;
    Eio.Time.sleep (Eio.Stdenv.clock env) 0.1
  done

let () =
  Logs.set_level (Some Debug);
  Logs.set_reporter (Logs_fmt.reporter ())

let _ = run test_write
