# clotran-nrepl

An nREPL server for [clotran](../clotran) -- Clojure hosted on Fortran --
so CIDER, Calva and other nREPL clients can connect to a running clotran
program, including one embedded in a Fortran solver.

**Status (2026-09-29): serving.** All eleven ops below answer, tested
against this package's own client, the reference client `nrepl/nrepl`
1.3.0, and the real CIDER run headless in Emacs (`test/cider-test.el`) --
all three by `test/run.sh`, the last two when clj and an Emacs with CIDER
are there. Like babashka's server, it gives no Clojure `version-string`:
CIDER takes one to mean clj and evaluates host-bound code (the
host's class path property), so without it CIDER treats clotran as
a generic runtime and everything above works.

## The design

Not a port of the reference `nrepl/nrepl`, which is built on its host's threads,
class loaders and thread stopping. The model is babashka's compact server
(`babashka/babashka.nrepl`), which serves CIDER from a Clojure that is not clj
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

    {:deps {clotran/clotran-nrepl {:local/root "../clotran-nrepl"}}}

then, in that directory, `clotran` and

    (require (quote clotran.nrepl.server))
    (clotran.nrepl.server/start! {:port 7888})

and from Emacs, `M-x cider-connect-clj` to localhost, port 7888.

From Emacs, clotran-mode (`~/clotran/clotran-mode`) makes `M-x cider-jack-in`
run `bin/clotran-nrepl`, which does the above for the project in the
current directory and prints the line CIDER waits for. By hand:

    bin/clotran-nrepl --port 7888

## Tests

    test/run.sh    # CLOTRAN=<clotran checkout>, default beside this one
