open Lwt_unix
open Lwt.Syntax

let pp_addr fmt = function
  | ADDR_INET (inet, port) ->
      Format.fprintf fmt "%s:%d" (Unix.string_of_inet_addr inet) port
  | _ -> assert false

let server_addr = ADDR_INET (Unix.inet_addr_any, 12345)

let connect_server () = Lwt_io.open_connection server_addr

(*Helpers for disk IOs
  TODO : create a lib*)
module Disk_IO = struct
  let read_file fn = Lwt_io.with_file fn ~mode:Input (fun ch -> Lwt_io.read ch)

  let get_files dir ~to_exclude =
    let get_files_names directory to_exclude =
      let lift file = directory ^ "/" ^ file in
      let handle = Unix.opendir directory in
      let rec loop acc =
        match Unix.readdir handle with
        | file ->
            if not (List.mem file to_exclude) then loop (lift file :: acc)
            else loop acc
        | exception End_of_file ->
            Unix.closedir handle ;
            acc
      in
      loop []
    in

    get_files_names dir to_exclude |> Lwt_list.map_p read_file

  let create_file ?(close_on_exec = true) ?(perm = 0o644) name content =
    let flags =
      let open Unix in
      let flags = [O_TRUNC; O_CREAT; O_WRONLY] in
      if close_on_exec then O_CLOEXEC :: flags else flags
    in
    let* fd = Lwt_unix.openfile name flags perm in
    Lwt.try_bind
      (fun () -> write_string fd content 0 (String.length content))
      (fun v ->
        let* () = close fd in
        Lwt.return v)
      raise

  let save ~filename ~verifier_input =
    let str =
      match
        Data_encoding.Binary.to_string
          Merkle_tree.verifier_input_encoding
          verifier_input
      with
      | Error err ->
          Format.eprintf
            "saving root and len: encoding failed (%a); exiting@."
            Data_encoding.Binary.pp_write_error
            err ;
          exit 1
      | Ok res -> res
    in
    (* TODO handle error *)
    let* _ = create_file filename str in
    Lwt.return_unit
end

(* Main functions of the client*)
module Client = struct
  (*Upload data from dir_path to the server.
    Then wait for an acknowledgment from the server
    and saves the necessary info to verify a witness
    in a specified file.*)
  let handle_upload ~dir_path_upload ~fn_save =
    Format.printf "uploading files from %s @." dir_path_upload ;
    let* (ic, oc) = connect_server () in
    let* data = Disk_IO.get_files dir_path_upload ~to_exclude:["."; ".."] in
    (* TODO we can probably do less conversion*)
    let data = List.map Bytes.of_string data in
    let tree = Merkle_tree.tree_of_list data in
    let verifier_input = Merkle_tree.get_root_len tree in
    let* () = Network.Client.write_message oc Network.(Upload data) in
    let* answer = Network.Client.read_message ic in
    match answer with
    | Ack ->
        let* () = Disk_IO.save ~filename:fn_save ~verifier_input in
        Format.printf "Uploaded and save the root in %s@." fn_save ;
        Lwt.return_unit
    (*TODO : handle error*)
    | Answer _ ->
        Format.eprintf "Server sent an Answer instead of an Ack :(@." ;
        Lwt.return_unit

  (*Checks a witness *)
  let check_merkle_root root_len_fn index =
    Format.printf
      "Requesting index: %s from root saved in %s@."
      index
      root_len_fn ;
    let index = int_of_string index in
    let* (ic, oc) = connect_server () in
    let* root_len = Disk_IO.read_file root_len_fn in
    let Merkle_tree.{root; len} =
      Data_encoding.Binary.of_string_exn
        Merkle_tree.verifier_input_encoding
        root_len
    in
    let request = Network.(Request {root; index}) in
    let* () = Network.Client.write_message oc request in
    let* answer = Network.Client.read_message ic in
    match answer with
    | Answer {file; witness} ->
        let ok =
          Merkle_tree.check_witness witness ~index file root ~tree_length:len
        in
        if ok then Format.printf "server was honest:)@."
        else Format.printf "server lied to us:(@." ;
        Lwt.return_unit
    (*TODO : handle error*)
    | Ack ->
        Format.eprintf "Server sent an Ack instead of an Answer :( @." ;
        assert false
end

let () =
  Lwt_main.run
  @@
  let args = Sys.argv |> Array.to_list |> List.tl in
  match args with
  | ["upload"; dir_path_upload; fn_save] ->
      Client.handle_upload ~dir_path_upload ~fn_save
  | ["check"; root_len_fn; n] -> Client.check_merkle_root root_len_fn n
  | _ ->
      Format.printf
        "Usage:\n\
        \ <client> upload <directory> <file_name>:\n\
        \  - uploads the files present in <directory>,\n\
        \ - waits for the server's acknowledgment,\n\
        \   compute merkle root locally, write it in <file_name> in the \
         current working directory\n\n\n\
        \ <client> check <merkle_root_path> <n> :\n\
        \   - request the n-th file (starting from 0) from the server along \
         with the merkle witness\n\
        \   - check correctness using <merkle_root_path>" ;
      Lwt.return_unit
