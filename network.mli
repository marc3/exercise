(**This module provides high level function
   for the server and client to communicate.
   We have two modules for client and server.
   Using the right module prevents unexpected
   messages. The messages type are exposed
   to allow construction.*)

(**Type for the client to send the data he wants
   to outsource.*)
type files = Bytes.t list

(**The answer to a client {!request}.
   The [file] field is the file he wants to recover.
   The [witness] field has to be used to verify the answer.
   Once the answer os verified the witness can be deleted.*)
type answer = {file : Bytes.t; witness : Merkle_tree.witness}

(**A request for the [index]-th file of the
   data which root is [root].*)
type request = {root : Merkle_tree.hash; index : int}

(**What the server can send.
   Ack has no content and just Acknoledge that
   an upload has been received and handle.
   Answer send the requested file to the client
   with a witness.
 *)
type server_message = Ack | Answer of answer

(**What the client can send.
   Upload contains the files he wants to outsource.
   Request request a file and its witness.
 *)
type client_message = Upload of files | Request of request

(**Read and write functions to be used by the client.*)
module Client : sig
  (**[write_message oc msg] takes an Lwt [output_channel], and write
     a {!client_message} to be read using {!Server.read_message}.*)
  val write_message : Lwt_io.output_channel -> client_message -> unit Lwt.t

  (**[read_message ic msg] takes an Lwt [input_channel], and
     returns a Lwt {!server_message}
     written by {!Server.write_message}.*)
  val read_message : Lwt_io.input_channel -> server_message Lwt.t
end

(**Read and write functions to be used by the server.*)
module Server : sig
  (**[write_message oc msg] takes an Lwt [output_channel], and write
     a {!server_message} to be read using {!Client.read_message}.*)
  val write_message : Lwt_io.output_channel -> server_message -> unit Lwt.t

  (**[read_message ic msg] takes an Lwt [input_channel], and
     returns a Lwt {!client_message}
     written by {!Client.write_message}.*)
  val read_message : Lwt_io.input_channel -> client_message Lwt.t
end

(**Only use for test. The client or server should not use encodings
   but only the provided read and write functions*)
module Internal_for_test : sig
  val client_msg_encoding : client_message Data_encoding.t

  val server_msg_encoding : server_message Data_encoding.t
end
