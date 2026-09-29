# clotran-nrepl

An nREPL server for [clotran](../clotran) -- Clojure hosted on Fortran --
so CIDER, Calva and other nREPL clients can connect to a running clotran
program, including one embedded in a Fortran solver.

**Status (2026-09-29): serving.** All eleven ops below answer, tested
against this package's own client and the reference client, `nrepl/nrepl`
1.3.0 (`test/run.sh`). CIDER itself has not been tried yet.

## The design

Not a port of the reference `nrepl/nrepl`, which is built on JVM threads,
class loaders and `Thread.stop`. The model is babashka's compact server
(`babashka/babashka.nrepl`), which serves CIDER from a non-JVM Clojure
with the operations CIDER uses day to day:

| op | what |
|---|---|
| `clone`, `close` | sessions |
| `describe` | the server's ops and versions |
| `eval`, `load-file` | with `*out*`/`*err*` sent back as they are printed |
| `complete`, `completions` | symbol completion |
| `info`, `lookup`, `eldoc` | docs and arglists |
| `ns-list` | the loaded namespaces |

`interrupt` is not planned: a running evaluation cannot be stopped from
outside on clotran, as on babashka.

The pieces, all clotran's own:

- `clotran.nrepl.bencode` -- the wire format over clotran.net's byte
  reads: a string's length counts BYTES, so strings are read exactly and
  decoded from UTF-8; a message is written in one send.
- `clotran.nrepl.server` -- sessions (each with its namespace and
  `*1 *2 *3 *e`) and the ops, a thread a connection; completion adds
  `clojure.core`'s publics, since clotran resolves to them rather than
  referring them (clotran's DEVIATIONS 3).

## Using it

In a project's `deps.edn`:

    {:deps {io.github.jborden/clotran-nrepl {:local/root "../clotran-nrepl"}}}

then, in that directory, `clotran` and

    (require (quote clotran.nrepl.server))
    (clotran.nrepl.server/start! {:port 7888})

and from Emacs, `M-x cider-connect-clj` to localhost, port 7888.

## Tests

    test/run.sh    # CLOTRAN=<clotran checkout>, default beside this one
