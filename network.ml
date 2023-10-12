open Lwt.Syntax
open Data_encoding

(*TODO expose constructor to ensure
  the well-formedness of those types.*)
type files = Bytes.t list

type answer = {file : Bytes.t; witness : Merkle_tree.witness}

let answer_encoding =
  conv
    (fun {file; witness} -> (file, witness))
    (fun (file, witness) -> {file; witness})
    (obj2 (req "file" bytes) (req "witness" Merkle_tree.witness_encoding))

type server_message = Ack | Answer of answer

let server_msg_encoding =
  let open Data_encoding in
  union
    ~tag_size:`Uint8
    [
      case
        ~title:"Ack"
        (Tag 0)
        unit
        (function Ack -> Some () | _ -> None)
        (fun () -> Ack);
      case
        ~title:"Answer"
        (Tag 1)
        answer_encoding
        (function Answer answer -> Some answer | _ -> None)
        (fun answer -> Answer answer);
    ]

type request = {root : Merkle_tree.hash; index : int}

let request_encoding =
  conv
    (fun {root; index} -> (root, index))
    (fun (root, index) -> {root; index})
    (obj2 (req "root" Merkle_tree.hash_encoding) (req "index" int31))

type client_message = Upload of files | Request of request

let client_msg_encoding =
  let open Data_encoding in
  union
    ~tag_size:`Uint8
    [
      case
        ~title:"Upload"
        (Tag 1)
        (list bytes)
        (function Upload l -> Some l | _ -> None)
        (fun l -> Upload l);
      case
        ~title:"Request"
        (Tag 2)
        request_encoding
        (function Request request -> Some request | _ -> None)
        (fun request -> Request request);
    ]

module Client = struct
  (*TODO : make it type safe with read/write*)
  let write_message output_channel msg =
    let msg =
      Data_encoding.Binary.to_bytes_exn client_msg_encoding msg
      |> Bytes.to_string
    in
    let* () = Lwt_io.write_value output_channel msg in
    Lwt.return_unit

  (*TODO : make it type safe with read/write*)
  let read_message input_channel =
    let* msg = Lwt_io.read_value input_channel in
    Lwt.return
      (Data_encoding.Binary.of_bytes_exn
         server_msg_encoding
         (String.to_bytes msg))
end

module Server = struct
  (*TODO : make it type safe with read/write*)
  let write_message output_channel msg =
    let msg =
      Data_encoding.Binary.to_bytes_exn server_msg_encoding msg
      |> Bytes.to_string
    in
    let* () = Lwt_io.write_value output_channel msg in
    Lwt.return_unit

  (*TODO : make it type safe with read/write*)
  let read_message input_channel =
    let* msg = Lwt_io.read_value input_channel in
    Lwt.return
      (Data_encoding.Binary.of_bytes_exn
         client_msg_encoding
         (String.to_bytes msg))
end

module Internal_for_test = struct
  let client_msg_encoding = client_msg_encoding

  let server_msg_encoding = server_msg_encoding
end
