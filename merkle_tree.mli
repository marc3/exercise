(**This library offers a Merkle tree implementation
   using the Blake2b hash function.
   The lenght of the hash is 256 bits which offers
   the standard 128 bits of security.
   Most data types are abstract.
   @fixme!!!Does not work with less than two files!!!
 *)

(**Output of Blake*)
type hash

val hash_encoding : hash Data_encoding.t

(**Tree containing only hashes*)
type my_merkle_tree

(**We also store the length used to extract witnesses.
Does not store the data used for creation.*)
type tree = {tree : my_merkle_tree; len : int}

(**Everything the verifier needs from the tree.
Once the data has been outsourced the client
can only save this*)
type verifier_input = {root : hash; len : int}

val verifier_input_encoding : verifier_input Data_encoding.t

val get_root_len : tree -> verifier_input

(**Create function. Does not store the data.
 @fixme!!!Does not work with less than two files!!!*)
val tree_of_list : bytes list -> tree

val pp_my_merkle_tree : Format.formatter -> tree -> unit

type witness

val witness_encoding : witness Data_encoding.t

(**[get_witness n t] returns a witness that the hash of the n-th leaf
belongs to tree.*)
val get_witness : int -> tree -> witness

(**[check_witness debug w index file root tree_length] returns a boolean.
[true]  means that file has been used to create the merkle tree of lenght
tree_length and root root has been created using file at index i.
[false] means it is not the case or the provided witness
is incorrect.
Will return [true] If the witness has been created using the correct parameters
*)
val check_witness :
  ?debug:bool ->
  witness ->
  index:int ->
  bytes ->
  hash ->
  tree_length:int ->
  bool

(**Don't use outside of tests*)
module Internal_for_test : sig
  val test_witness : witness

  val test_hash : hash

  val pp_witness : witness -> unit
end
