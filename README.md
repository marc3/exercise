# Installation
The executables are provided if you wish to skip that part.
First you need opam, OCaml's packet manager.
You can find instruction here : https://opam.ocaml.org/doc/Install.html.
You also need to clone the repo and go to the directory.

Then initialise to get the ocaml compiler :
```
opam init
```

Then we intall the needed packages (and their dependencies) :

```
opam install dune blake2 hex data-encoding zarith lwt
```
Then compile :
```
make
```

The results are three executables :
	- server.exe
	- client.exe
	- test.exe
# Unit test

You can run unit tests for the two libraries provided in the project
(merkle_tree and network).
```
./test.exe
```
# Documentation

## Libraries
We provide documentation for the two libraries.
We first need odoc to build it :
```
opam install odoc
```

We then need to clean (TODO : fix that) :

```
make clean
```

Then build the doc :
```
dune build @doc-private
```

This will produce two html pages found in :
```
_build/default/_doc/_html/
```

Note that there is and index.html that contains nothing.
TODO : fix that.

## Client
The client handles two commands
- ./client.exe upload directory file_name:
  - uploads the files present in directory,
  waits for the server's acknowledgment,
  - compute merkle root locally, write it in file_name in current
  working directory
- ./client.exe check merkle_root_path n :
  - request the n-th file (starting from 0)
	from the server along with the merkle witness
  - check correctness using merkle_root_path

## Server
The server simply listen to request and answer.
Note that it has no persistent storage.
So don't kill it, or the uploaded files will be deleted.
The server can handle several client in parrallel.

# Run an example

The repo contains a to_hash directory to be hashed to run a toy example.
First launch the server :

```
./server.exe
```
Then upload the content of to_hash :
```
 ./client.exe upload to_hash my_root
```

Then request a file :
```
/client.exe check my_root 1
```
Note that the index starts at 0, so the command request the second
file.
