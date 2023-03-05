(use ./util)
(import ./help)
(use ./param-parser)
(use ./arg-parser)
(use ./bridge)

(defmacro spec [& s]
  (bake-spec (parse-specification s)))

(def args args)
(def parse parse)

(defn run [command args]
  (def f (assertf (command :fn) "invalid command %q" command))
  (f args))

(defmacro group [& s]
  (if (odd? (length s))
    (error "group requires an even number of arguments"))

  (def commands
    (tabseq [[name command] :in (partition 2 s)]
      (string name) command))

  (defn print-help-and-exit [spec & messages]
    (unless (empty? messages)
      (eprintf ;messages))
    (help/group spec)
    (os/exit 1))

  (def docstring "this is the docstring")

  # TODO: we could also accumulate arguments
  (with-syms [$commands $spec]
    ~(let [,$commands ,commands
           ,$spec {:doc ,docstring :commands ,$commands}]
      {:fn (fn [args]
        (match args
          [first & rest]
            (if-let [command (,$commands first)]
              (,run command rest)
              (,print-help-and-exit ,$spec "unknown subcommand %s" first))
          [] (,print-help-and-exit ,$spec)))
       :doc (,$spec :doc)
       :help (fn [] (,help/group ,$spec))})))

(defmacro defgroup [name & s]
  ~(def ,name (as-macro ,group ,;s)))

(defmacro main [command]
  ~(defn main [&] (,run ,command (,args))))

(defn peg [peg-dsl]
  (def peg (peg/compile peg-dsl))
  ["_"
   (fn [str]
     (def matches (peg/match peg str))
     (if (and (not (nil? matches)) (has? length matches 1))
       (first matches)
       (errorf "unable to parse %q" str)))])

(defmacro fn [& args]
  (def [spec body]
    (case (length args)
      0 (error "not enough arguments")
      1 [(first args) []]
      (let [[first second & rest] args]
        (if (string? first)
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
       :help (fn [] (,help/single ,$spec))})))

(defmacro defn [name & args]
  ~(def ,name (as-macro ,fn ,;args)))

(def print-help help/single)

(defmacro def [& spec]
  (def spec (parse-specification spec))
  (assignment spec nil ~(,args)))
