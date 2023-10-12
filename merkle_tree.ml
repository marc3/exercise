open Blake2.Blake2b

type hash = Blake2.Blake2b.hash

(* Size of Blake's output in bytes*)
let len = 32

let hash_encoding =
  Data_encoding.conv
    (fun (Hash h) -> h)
    (fun h -> Hash h)
    (Data_encoding.Bounded.bytes len)

type witness = hash list

let witness_encoding = Data_encoding.list hash_encoding

type verifier_input = {root : hash; len : int}

let verifier_input_encoding =
  let open Data_encoding in
  conv
    (fun {root; len} -> (root, len))
    (fun (root, len) -> {root; len})
    (obj2 (req "root" hash_encoding) (req "len" int31))

type my_merkle_tree =
  | Node of Blake2.Blake2b.hash * my_merkle_tree * my_merkle_tree
  | Empty

type tree = {tree : my_merkle_tree; len : int}

(* We print a small amount of the hash sufficient
   for debugging*)
let pp_hash fmt (Hash h) = Hex.pp fmt (Hex.of_bytes (Bytes.sub h 0 4))

let pp_my_merkle_tree fmt (tree : tree) =
  let rec aux fmt tree =
    match tree with
    | Empty -> ()
    | Node (h, left, right) ->
        Format.fprintf fmt "@[<v 2>- %a:@ %a@ %a@]" pp_hash h aux left aux right
  in
  aux fmt tree.tree

let hash_leaf bytes = Node (direct bytes len, Empty, Empty)

let hash_node (Hash h1) (Hash h2) =
  direct (Bytes.concat Bytes.empty [h1; h2]) len

let hash_single (Hash h) = direct h len

let hash_two_trees t1 t2 =
  match (t1, t2) with
  | (Node (h1, _, _), Node (h2, _, _)) -> Node (hash_node h1 h2, t1, t2)
  | (Node (h1, _, _), Empty) -> Node (hash_single h1, t1, t2)
  | (Empty, Node (h1, _, _)) -> Node (hash_single h1, t1, t2)
  | (Empty, Empty) -> Empty

let tree_of_list data_list =
  let hashed_list = List.map hash_leaf data_list in
  let rec step tree_list =
    match tree_list with
    | [] -> []
    | x :: [] -> [x]
    | t1 :: t2 :: tail ->
        let rest = step tail in
        hash_two_trees t1 t2 :: rest
  in
  let rec iter list =
    match list with [] -> assert false | [x] -> x | list -> iter (step list)
  in
  {tree = iter hashed_list; len = List.length data_list}

(*TODO the len should appear with the root to
  create a verifier  input type*)
let get_root_len {tree; len} =
  match tree with Node (h, _, _) -> {root = h; len} | Empty -> assert false

let height {tree; len = _} =
  let rec aux acc tree =
    match tree with Empty -> acc | Node (_, t1, _) -> aux (acc + 1) t1
  in
  aux 0 tree

let binary_repr ~int ~lenght =
  List.init lenght (fun i -> Int.shift_right int i mod 2 != 0) |> List.rev

let cut_path ~index ~tree_length =
  let lenght = Z.(log2up (of_int tree_length)) in
  let binary_index_repr = binary_repr ~int:index ~lenght in
  let binary_tree_repr = binary_repr ~int:(tree_length - 1) ~lenght in
  let went_left = ref (not @@ List.hd binary_index_repr) in
  List.filteri
    (fun i b ->
      if !went_left then true
      else if List.nth binary_tree_repr i then (
        if not b then went_left := true ;
        true)
      else false)
    binary_index_repr

let get_witness index tree =
  let height_tree = height tree in
  let path = cut_path ~index ~tree_length:tree.len in
  let rec aux path witness tree current_height _skip_next =
    match path with
    | [] -> witness
    | head :: tail -> (
        match tree with
        | Node (_, t1, t2) ->
            let chosen_tree = if head then t2 else t1 in
            let chosen_root =
              (get_root_len
                 (*TODO : Thats ugly*)
                 (if not head then {tree = t2; len = 0}
                  else {tree = t1; len = 0}))
                .root
            in
            aux
              tail
              (chosen_root :: witness)
              chosen_tree
              (current_height - 1)
              true
        | Empty -> List.rev witness)
  in
  aux path [] tree.tree (height_tree - 1) true

let check_witness ?(debug = false) witness ~index file rt ~tree_length =
  if debug then Format.printf "root :@\n%a ---------@. " pp_hash rt ;
  let hashed_file = Blake2.Blake2b.direct file 32 in
  if debug then
    Format.printf "hashed file :@\n%a -------@. " pp_hash hashed_file ;
  let path = cut_path ~index ~tree_length |> List.rev in
  (*   binary_repr ~int:index ~lenght:(height - 1) *)
  (*   |> List.rev *)
  (*   |> List.filteri (fun pos _ -> pos >= height - List.length witness - 1) *)
  (* in *)
  if debug then (
    Format.printf "binary repr cut @." ;
    List.iter (fun b -> Format.printf "%b ; " b) path ;
    Format.printf "\nhashing--------@.") ;
  let expected_rt =
    List.fold_left2
      (fun acc hash is_left ->
        if debug then Format.printf "acc :@\n%a ;@. " pp_hash acc ;
        if is_left then hash_node hash acc else hash_node acc hash)
      hashed_file
      witness
      path
  in
  expected_rt = rt

module Internal_for_test = struct
  (*used to test the data encodings*)
  let test_witness =
    List.init 7 (fun i -> direct (Bytes.init i (fun i -> char_of_int i)) 32)

  (*used to test the data encodings*)
  let test_hash = direct (Bytes.init 5 (fun i -> char_of_int i)) 32

  let pp_witness = List.iter (fun h -> Format.printf "%a ; " pp_hash h)
end
