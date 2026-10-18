;;; test/cider-test.el -- the real CIDER, headless, against a running
;;; clotran-nrepl server (NREPL_PORT): connect, then the requests CIDER
;;; makes as you type. Exits 0 when every check passes. Run by test/run.sh.
(require 'package)
(package-initialize)
(require 'cider)
(defvar fails 0)
(defmacro check (label got want)
  `(let ((g (condition-case err ,got (error (list 'ERROR err)))))
     (if (equal g ,want)
         (princ (format "ok   - CIDER: %s\n" ,label))
       (setq fails (1+ fails))
       (princ (format "FAIL - CIDER: %s\n  got:  %S\n  want: %S\n" ,label g ,want)))))
(cider-connect-clj (list :host "localhost" :port (string-to-number (getenv "NREPL_PORT"))
                         :project-dir default-directory))
(let ((n 0)) (while (< n 30) (accept-process-output nil 0.1) (setq n (1+ n))))
(let ((repl (seq-find (lambda (b) (with-current-buffer b (derived-mode-p 'cider-repl-mode))) (buffer-list))))
  (if (not repl)
      (progn (princ "FAIL - CIDER: no REPL buffer after connecting\n") (kill-emacs 1))
    (with-current-buffer repl
      (check "a generic runtime, not taken for clj" (cider-runtime) 'generic)
      (check "eval" (nrepl-dict-get (cider-nrepl-sync-request:eval "(+ 1 2)") "value") "3")
      (check "printed output" (nrepl-dict-get (cider-nrepl-sync-request:eval "(println \"hi λ\")") "out") "hi λ\n")
      (check "completion" (mapcar #'substring-no-properties (seq-take (cider-complete "redu") 2)) '("reduce" "reduce-kv"))
      (check "info" (nrepl-dict-get (cider-var-info "map") "ns") "clojure.core")
      (check "eldoc" (car (lax-plist-get (cider-eldoc-info "inc") "arglists")) '("x"))
      (check "an error" (not (null (nrepl-dict-get (cider-nrepl-sync-request:eval "(no-such-thing)") "err"))) t)
      ;; a .cljf file: clojure-mode from clotran-mode (beside this checkout),
      ;; and loaded into clotran from its buffer as CIDER loads any file
      (load (expand-file-name "clotran-mode.el" (getenv "CLOTRAN_MODE_DIR")))
      ;; inside the connected project: CIDER links a buffer to a REPL by
      ;; its project directory, and loads nothing from a file outside it
      (let* ((dir (make-temp-file (expand-file-name "cljf" default-directory) t))
             (f (expand-file-name "demo.cljf" dir)))
        (with-temp-file f (insert "(ns cljf-demo)\n(defn twice [x] (* 2 x))\n"))
        (let ((buf (find-file-noselect f)))
          (check "a .cljf file opens in a clojure-mode (clotran-mode)" (with-current-buffer buf (and (derived-mode-p (quote clojure-mode)) t)) t)
          (with-current-buffer buf
            (cider-load-buffer)
            (let ((n 0)) (while (< n 20) (accept-process-output nil 0.1) (setq n (1+ n)))))
          (check "and CIDER loads it into clotran, interpreted" (nrepl-dict-get (cider-nrepl-sync-request:eval "(cljf-demo/twice 21)") "value") "42")
          ;; loaded as the file, so compiled too: build it now rather than
          ;; wait for the background build, then run the native code
          (check "and compiles it"
                 (nrepl-dict-get (cider-nrepl-sync-request:eval (format "(clotran.loader/compile-now %S)" f)) "value") ":installed")
          (check "the compiled function is the one that runs"
                 (nrepl-dict-get (cider-nrepl-sync-request:eval "[(clojure.string/includes? (pr-str cljf-demo/twice) \"#<compiled\") (cljf-demo/twice 21)]") "value")
                 "[true 42]")
          (kill-buffer buf))
        (delete-directory dir t))
      (check "its trace, as CIDER shows it without middleware"
             (not (null (string-match-p "no-such-thing"
                                        (or (nrepl-dict-get (cider-nrepl-sync-request:eval "(clojure.stacktrace/print-cause-trace *e)") "out") ""))))
             t))))
(kill-emacs (if (zerop fails) 0 1))
