# clotran-nrepl

An nREPL server for [clotran](https://github.com/clotran/clotran) -- Clojure hosted on Fortran --
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

`clotran nrepl [--port N]` (the clotran command; its PLAN step 36)
starts this server in a clotran for the project in the current
directory, writes `.nrepl-port` and prints the line CIDER's jack-in
waits for; on a terminal the REPL follows in the same process, so the
editor and the prompt share one program. There is nothing to add to a
project: an installed clotran carries this library (its `tools.edn`
pins the commit), and a checkout beside clotran, or `CLOTRAN_NREPL=dir`,
is used instead when there is one. From Emacs, `M-x cider-connect-clj` to localhost and
the port it printed; [clotran-mode](https://github.com/clotran/clotran-mode)
starts it and connects with `C-c C-z`, and makes CIDER's own
`M-x cider-jack-in` in a clotran buffer run it too.

In a program of your own -- one embedded in a solver -- name it in the
`deps.edn`:

    {:deps {clotran/clotran-nrepl {:git/url "https://github.com/clotran/clotran-nrepl.git"
                                   :git/sha "211616104c225498b794edbf3f6002dcc52c873f"}}}

run `clotran deps` once, then `clotran` in that directory and

    (require (quote clotran.nrepl.server))
    (clotran.nrepl.server/start! {:port 7888})

## Tests

    test/run.sh    # CLOTRAN=<clotran checkout>, default beside this one
