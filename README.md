# clotran-nrepl

An nREPL server for [clotran](../clotran) -- Clojure hosted on Fortran --
so CIDER, Calva and other nREPL clients can connect to a running clotran
program, including one embedded in a Fortran solver.

**Status: a stub.** The namespaces load; nothing serves yet.

## The plan

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

- `clotran.nrepl.bencode` -- the wire format, over byte arrays: bencode
  lengths count BYTES, so this needs clotran's byte-level socket reads
  (not yet in clotran; its text reader decodes UTF-8).
- `clotran.nrepl.server` -- sessions and ops over `clotran.net`, with
  evaluation and output capture as `clotran.server/prepl` does them.

## Using it (once it serves)

In a project's `deps.edn`:

    {:deps {io.github.jborden/clotran-nrepl {:local/root "../clotran-nrepl"}}}

then `CLOTRAN_PATH=$(clotran-deps) clotran` and
`(clotran.nrepl.server/start! {:port 7888})`.
