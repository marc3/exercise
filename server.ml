open Lwt_unix
open Lwt.Syntax

let pp_addr fmt = function
  | Unix.ADDR_INET (inet, port) ->
      Format.fprintf fmt "%s:%d" (Unix.string_of_inet_addr inet) port
  | _ -> assert false

module Merkle_root_map = Map.Make (struct
  type t = Merkle_tree.hash

  let compare = compare
end)

(* TODO make a persistent storage for the server*)
type server_state = Merkle_tree.tree * Bytes.t list Merkle_root_map.t

let start_client state client_fd =
  let ic = Lwt_io.of_fd ~mode:Input client_fd in
  let oc = Lwt_io.of_fd ~mode:Output client_fd in
  let rec loop () =
    let* msg = Network.Server.read_message ic in
    let* () =
      match msg with
      | Network.Upload files ->
          Format.printf "Received an upload@." ;
          let tree = Merkle_tree.tree_of_list files in
          let root = Merkle_tree.((get_root_len tree).root) in
          let () = state := Merkle_root_map.add root (tree, files) !state in
          let* () = Network.Server.write_message oc Network.Ack in
          (*TODO id the upload in case of concurency*)
          Format.printf "Handled the upload @." ;
          Lwt.return_unit
      | Network.(Request {root; index}) ->
          Format.printf "Received a request@." ;
          (*TODO : catch exception and
            extend answer type to inform the client*)
          let (tree, files) = Merkle_root_map.find root !state in
          (*TODO : catch exception and
            extend answer type to inform the client*)
          let file = List.nth files index in
          let witness = Merkle_tree.get_witness index tree in
          let answer = Network.(Answer {file; witness}) in
          let* () = Network.Server.write_message oc answer in
          Format.printf "Handled the request @." ;
          Lwt.return_unit
    in

    loop ()
  in
  loop ()

let run () =
  (*TODO : find a higher level function*)
  let socket = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Lwt_unix.setsockopt socket SO_REUSEADDR true ;
  let my_address = Unix.ADDR_INET (Unix.inet_addr_any, 12345) in
  let* () = Lwt_unix.bind socket my_address in
  (*100 chosen arbitraly*)
  let () = Lwt_unix.listen socket 100 in
  (*TODO Get rid of the ref*)
  let state = ref Merkle_root_map.empty in
  Format.printf "Launching server@." ;
  let rec loop () =
    let* (client_fd, client_addr) = Lwt_unix.accept socket in
    let () = Lwt_unix.listen socket 100 in

    Format.printf "Received new connection from %a@." pp_addr client_addr ;
    Lwt.async (fun () ->
        Lwt.catch
          (fun () -> start_client state client_fd)
          (fun exn ->
            Format.printf
              "Client %a exited: %s@."
              pp_addr
              client_addr
              (Printexc.to_string exn) ;
            Lwt.return_unit)) ;
    loop ()
  in

  loop ()

let () = Lwt_main.run (run ())
