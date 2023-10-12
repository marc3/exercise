all: clean client server test
	cp _build/default/client.exe .
	cp _build/default/server.exe .
	cp _build/default/test.exe .


client:
	dune build ./client.exe

server:
	dune build ./server.exe

test:
	dune build ./test.exe

clean:
	rm -f client.exe server.exe test.exe
