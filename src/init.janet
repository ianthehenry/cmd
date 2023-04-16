(use ./util)
(import ./help)
(use ./param-parser)
(use ./arg-parser)
(use ./bridge)

(defn print-help [spec]
  (if (spec :commands)
    (help/group spec)
    (help/simple spec)))

(defn- print-group-help-and-error [spec & messages]
  (unless (empty? messages)
    (eprintf ;messages))
  (help/group spec)
  (os/exit 1))

(defn- potential-docstring? [node]
  (case (type+ node)
    :tuple-parens true
    :string true
    false))

# TODO: the representation of having the :help
# function is a little odd. we could just represent
# the command as the fully-parsed spec, and have
# cmd/run do the same check as cmd/print-help
(defmacro- simple-command [& args]
  (def [spec body]
    (case (length args)
      0 (error "not enough arguments")
      1 [(first args) []]
      (let [[first second & rest] args]
        (if (potential-docstring? first)
          [(tuple/brackets first ;second) rest]
          [first [second ;rest]]))))

  (unless (has? type+ spec :tuple-brackets)
    (errorf "expected bracketed list of parameters, got %q" spec))
  (def spec (parse-specification spec))
  (with-syms [$args $spec]
    ~(let [,$spec ,(bake-spec spec)]
      {:fn (fn [,$args]
        ,(assignment spec $spec $args)
        ,;body)
       :doc (,$spec :doc)
       :help (fn [] (,help/simple ,$spec))})))

(defn- extend-subcommand-path [command]
  [;(dyn *subcommand-path* []) command])

(defn- rewrite-last-subcommand-entry [new]
  (def current-path (dyn *subcommand-path* []))
  (def but-last (tuple/slice current-path 0 (- (length current-path) 1)))
  [;but-last new])

(def- help-command (simple-command "explain a subcommand"
  [command (optional ["COMMAND" :string])]
  (def spec (dyn *spec*))
  (if command
    (if-let [subcommand ((spec :commands) command)]
      (with-dyns [*subcommand-path* (rewrite-last-subcommand-entry command)]
        ((subcommand :help)))
      (print-group-help-and-error spec "unknown subcommand %s" command))
    (help/group spec))))

(defmacro spec [& s]
  (bake-spec (parse-specification s)))

(def args args)
(def parse parse)

(defn run [command args]
  (def f (assertf (command :fn) "invalid command %q" command))
  (f args))

(defmacro group [& spec]
  (def [docstring spec]
    (if (potential-docstring? (first spec))
      [(first spec) (drop 1 spec)]
      [nil spec]))

  (if (odd? (length spec))
    (errorf "subcommand %q has no implementation" (last spec)))

  (def commands
    (tabseq [[name command] :in (partition 2 spec)]
      (string name) command))

  (unless (commands "help")
    (put commands "help" help-command))

  # TODO: we could also accumulate flag-looking arguments and pass
  # them to the command, so that `foo --verbose bar` meant the same
  # thing as `foo bar --verbose`.
  (with-syms [$commands $spec]
    ~(let [,$commands ,commands
           ,$spec {:doc ,docstring :commands ,$commands}]
      {:fn (fn [args]
        (match args
          [first & rest]
            (if-let [command (,$commands first)]
              (with-dyns [,*spec* ,$spec
                          ,*subcommand-path* (,extend-subcommand-path first)]
                (,run command rest))
              (,print-group-help-and-error ,$spec "unknown subcommand %s" first))
          [] (,print-group-help-and-error ,$spec)))
       :doc (,$spec :doc)
       :help (fn [] (,help/group ,$spec))})))

(defmacro defgroup [name & s]
  ~(def ,name (as-macro ,group ,;s)))

(defmacro main [command]
  ~(defn main [&] (,run ,command (,args))))

(defn peg [name peg-dsl]
  (def peg
    (case (type peg-dsl)
      :core/peg peg-dsl
      (peg/compile peg-dsl)))
  [name
   (fn [str]
     (def matches (peg/match peg str))
     (if (and (not (nil? matches)) (has? length matches 1))
       (first matches)
       (errorf "unable to parse %q" str)))])

(def fn :macro simple-command)

(defmacro defn [name & args]
  ~(def ,name (as-macro ,fn ,;args)))

(defmacro def [& spec]
  (def spec (parse-specification spec))
  (assignment spec nil ~(,args)))
