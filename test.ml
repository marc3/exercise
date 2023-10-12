let test_merkle () =
  let open Merkle_tree in
  let test len =
    let l =
      List.init len (fun i -> Int.to_string i) |> List.map Bytes.of_string
    in
    let test i =
      let tree = tree_of_list l in
      let witness = get_witness i tree in
      (* uncomment to see the tree*)
      (* Format.printf "\ntree:@\n%a------ @." pp_my_merkle_tree tree ; *)
      (* uncomment to see the witness*)
      (* Format.printf "witness -------  @." ; *)
      (* Internal_for_test.pp_witness witness ; *)
      (* Format.printf "@." ; *)
      assert (
        check_witness (*change to true for debug infos*)
          ~debug:false
          witness
          ~index:i
          (List.nth l i)
          (get_root_len tree).root
          ~tree_length:len) ;
      Format.printf "works for len %d and index %d :)---------@." len i
    in
    for i = 0 to List.length l - 1 do
      test i
    done
  in
  for i = 2 to 32 do
    test i
  done

let test_encoding () =
  let open Network in
  let open Network.Internal_for_test in
  let test_server msg =
    assert (
      msg
      = Data_encoding.Binary.(
          of_bytes_exn
            server_msg_encoding
            (to_bytes_exn server_msg_encoding msg)))
  in
  let test_client msg =
    assert (
      msg
      = Data_encoding.Binary.(
          of_bytes_exn
            client_msg_encoding
            (to_bytes_exn client_msg_encoding msg)))
  in
  let upload =
    Upload (List.map Bytes.of_string ["aez"; "fdsfddg"; ""; "fsdfse"])
  in
  test_server Ack ;
  Format.printf "ack encoding works @." ;
  test_server
    (Answer
       {
         file = Bytes.init 3 (fun i -> char_of_int i);
         witness = Merkle_tree.Internal_for_test.test_witness;
       }) ;
  Format.printf "answer encoding works @." ;
  test_client upload ;
  Format.printf "upload encoding works @." ;
  test_client
    (Request {root = Merkle_tree.Internal_for_test.test_hash; index = 3}) ;
  Format.printf "request encoding works @."

let () = test_merkle ()

let () = test_encoding ()
