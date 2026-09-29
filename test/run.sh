#!/bin/sh
# test/run.sh -- the server against its own client (test/nrepl_test.cljf),
# then, when clj is on PATH, against the reference client nrepl/nrepl.
# CLOTRAN is the clotran checkout (default: beside this repository).
here=$(cd "$(dirname "$0")/.." && pwd)
CLOTRAN=${CLOTRAN:-$here/../clotran}
CLOTRAN_PATH="$here/src" "$CLOTRAN/clotran" "$here/test/nrepl_test.cljf" </dev/null 2>&1 | grep -v '^note:\|^user=>' || true
CLOTRAN_PATH="$here/src" "$CLOTRAN/clotran" "$here/test/nrepl_test.cljf" </dev/null >/dev/null 2>&1 || exit 1
command -v clj >/dev/null || { echo "(clj not found: the reference client check is skipped)"; exit 0; }

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"; [ -n "$pid" ] && kill "$pid" 2>/dev/null' EXIT
printf '(require (quote clotran.nrepl.server))\n(spit "%s/port" (:port (clotran.nrepl.server/start! {:port 0})))\n@(promise)\n' "$work" > "$work/serve.clj"
CLOTRAN_PATH="$here/src" "$CLOTRAN/clotran" "$work/serve.clj" </dev/null >/dev/null 2>&1 &
pid=$!
i=0; while [ ! -s "$work/port" ] && [ $i -lt 30 ]; do sleep 0.5; i=$((i+1)); done
port=$(cat "$work/port")
cat > "$work/client.clj" <<CLJ
(require '[nrepl.core :as nrepl])
(with-open [conn (nrepl/connect :port $port)]
  (let [c (nrepl/client conn 5000) s (nrepl/client-session c)
        r (nrepl/combine-responses (nrepl/message s {:op "eval" :code "(println \"hi\") (reduce + (range 10))"}))
        ok (and (= "hi\n" (:out r)) (= ["nil" "45"] (:value r)) (contains? (:status r) "done")
                (= ["reduce" "reduce-kv"] (->> (nrepl/message s {:op "completions" :prefix "reduce" :ns "user"}) first :completions (map :candidate) (take 2))))]
    (println (if ok "ok   - the reference nREPL client (nrepl/nrepl 1.3.0) evaluates and completes" (str "FAIL - reference client: " (pr-str r))))
    (shutdown-agents)
    (System/exit (if ok 0 1))))
CLJ
clj -Sdeps '{:deps {nrepl/nrepl {:mvn/version "1.3.0"}}}' -M "$work/client.clj" 2>&1 | grep -v '^Downloading'
