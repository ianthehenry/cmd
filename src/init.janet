(def number-type (fn [str] (assert (scan-number str))))
(def string-type (fn [str] str))

(defn- assertf [pred str & args]
  (assert pred (string/format str ;args)))

(def- unset-sentinel (gensym))

(def- unset ~',unset-sentinel)

(defn- unset? [x]
  (= x unset-sentinel))

(defn- named-arg? [token]
  (and
    (= (type token) :symbol)
    (string/has-prefix? "-" token)))

(defn- goto-state [ctx next-state]
  (set (ctx :state) next-state))

# TODO: probably get rid of primary-name? at least in spec
# errors. it's good to show it to the user, but if there's a
# spec parse error it should probably treat the symbol as the
# canonical name
(defn- primary-name [{:names names :sym sym}]
  (match names
    [name & _] name
    [] sym))

(defn- type+ [form]
  (let [t (type form)]
    (case t
      :tuple (case (tuple/type form)
        :brackets :tuple-brackets
        :parens :tuple-parens)
      t)))

# TODO: parse
(defn- optional [form &opt default]
  {:init unset
   :takes-value? true
   :update (fn [old new]
    (assert (unset? old) "optional value already set")
    new)
   :finish (fn [val]
    (if (unset? val) default val))})

(defn- assert-unset [val] (assert (unset? val) "flag already set"))

# TODO: parse
(defn- required [form]
  {:init unset
   :takes-value? true
   :update (fn [old new] (assert-unset old) new)
   :finish (fn [val]
    (when (unset? val)
      (error "missing required flag"))
    val)})

(defn- flag []
  {:init unset
   :takes-value? false
   :update (fn [old] (assert-unset old) true)
   :finish (fn [val]
    (if (unset? val) false val))})

(defn- counted []
  {:init 0
   :takes-value? false
   :update (fn [old] (+ old 1))
   :finish |$})

# TODO: parse
(defn- listed-array [form]
  {:init @[]
   :takes-value? true
   :update (fn [old new]
    (array/push old new)
    old)
   :finish |$})

# TODO: parse
(defn- listed-tuple [form]
  {:init @[]
   :takes-value? true
   :update (fn [old new]
    (array/push old new)
    old)
   :finish tuple/slice})

(defn- parse-form [form]
  (when (empty? form)
    (errorf "unable to parse form %q" form))

  (defn arity [op args min max]
    (when (< (length args) min)
      (errorf "not enough arguments to %q" op))
    (when (> (length args) max)
      (errorf "too many arguments to %q" op))
    args)

  (def [op & args] form)
  # TODO: special-case quasiquote here...
  (case op
    'optional (optional ;(arity op args 1 2))
    '? (optional ;(arity op args 1 2))
    'opt (optional ;(arity op args 1 2))
    'count (counted ;(arity op args 0 0))
    'flag (flag ;(arity op args 0 0))
    (errorf "unknown operation %q" op)))

# brackets should be shorthand for listed
(defn- parse-type [form]
  (case (type+ form)
    :tuple-parens (parse-form form)
    :tuple-brackets (case (length form)
      1 (listed-tuple form)
      (errorf "unable to parse %q" form))
    :array (case (length form)
      1 (listed-array form)
      (errorf "unable to parse %q" form))
    :keyword (required form)
    ))

(defn- finish-flag [ctx flag next-state]
  (def {:names names :sym sym :doc doc-string :type t} flag)

  (when (nil? t)
    (errorf "no type for %s" (primary-name flag)))

  (each name names
    (when (in (ctx :names) name)
      (errorf "multiple flags named %s" name))
    (put (ctx :names) name sym))

  (when ((ctx :flags) sym)
    (errorf "duplicate flag %s" sym))

  (put (ctx :flags) sym
    {:doc doc-string
     :names names
     :type (parse-type t)})
  (array/push (ctx :declared-order) sym)
  (goto-state ctx next-state))

(var- state/arg nil)

(defn- new-flag-state [spec-names]
  (assertf (not (empty? spec-names))
    "unexpected token %q" spec-names)
  (def first-name (first spec-names))

  (def [sym flag-names]
    (if (named-arg? first-name)
      [(symbol (string/triml first-name "-")) spec-names]
      [first-name (drop 1 spec-names)]))

  (each flag flag-names
    (unless (named-arg? flag)
      (errorf "all aliases must start with - %q" spec-names)))

  (def flag-names (map string flag-names))

  (each name flag-names
    (when (all |(= $ (chr "-")) name)
      (errorf "illegal flag name %s" name)))

  (table/setproto @{:names flag-names :sym sym} state/arg))

# TODO: there should probably be an escape hatch to declare a dynamic docstring.
# Right now the doc string has to be a string literal, which is limiting.
(set state/arg
  @{:on-string (fn [self ctx str]
      (when (self :doc)
        (error "docstring already set"))
      (set (self :doc) str))
    :on-flag (fn [self ctx names]
      (finish-flag ctx self (new-flag-state names)))
    :on-other (fn [self ctx expr]
      (when-let [peg (self :type)]
        (errorf "multiple parsers specified for %s (got %q, already have %q)"
          (primary-name self) expr peg))
      (set (self :type) expr))
    :on-eof (fn [self ctx] (finish-flag ctx self nil))})

(defn- set-ctx-doc [self ctx expr]
  (assertf (nil? (ctx :doc)) "unexpected token %q" expr)
  (set (ctx :doc) expr))

(def- state/pending
  @{:on-string set-ctx-doc
    :on-flag (fn [self ctx names] (goto-state ctx (new-flag-state names)))
    :on-other (fn [self ctx token] (errorf "unexpected token %q" token))
    :on-eof (fn [_ _])})

(def- state/initial
  (table/setproto
    @{:on-other (fn [self ctx token]
      (set-ctx-doc self ctx token)
      (goto-state ctx state/pending))}
    state/pending))

(defn- parse-specification [spec]
  (def ctx
    @{:flags @{}
      :names @{}
      :state state/initial
      :declared-order @[]})

  (each token spec
    (def state (ctx :state))
    (match (type+ token)
      :string (:on-string state ctx token)
      (:tuple-brackets (all symbol? token)) (:on-flag state ctx token)
      :symbol (:on-flag state ctx [token])
      (:on-other state ctx token)))
  (:on-eof (ctx :state) ctx)
  ctx)

(defmacro simple [spec & body]
  (unless (and (tuple? spec) (= (tuple/type spec) :brackets))
    (errorf "expected bracketed list of flags, got %q" spec))
  (def spec (parse-specification spec))

  ~(fn [& args]

    ,spec

    ))

(defn- print-help [spec]
  (when-let [doc-string (spec :doc)]
    (print doc-string)
    (print))

  (each [_ {:names names :type t :doc doc}]
    (sorted-by 0 (pairs (spec :flags)))
    (printf "%s %q %q" names t doc)))

(defmacro- catseq [& args]
  ~(mapcat |$ (seq ,;args)))

(defmacro- pdb [& exprs]
  ~(do
    ,;(seq [expr :in exprs]
        ~(eprintf "%s = %q" ,(string/format "%q" expr) ,expr))))

(defn- quote-flags [flags]
  ~(struct
    ,;(catseq [[key {:type t}] :pairs flags]
      [~',key t])))

#(defn- quote-keys [struct]
#  ~(struct
#    ,;(catseq [[key val] :pairs struct]
#      [~',key val])))

(defn- quote-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [key ~',val])))

# TODO: you could imagine a debug mode
# where we preserve the stack frames here...
# actually maybe we should always preserve
# the stack frames, and just throw them away
# when we're using one of the user-facing macros?
# hmm. hmm hmm hmm.
(defmacro- try-with-context [name & body]
  ~(try (do ,;body)
    ([err fib]
      (errorf "%s: %s" ,name err))))

# flags: sym -> type description
# lookup: string -> sym
# callbacks: string -> sym
(defn- parse-args [args flags lookup refs]
  (var i 0)
  (def anons @[])

  (defn next-arg []
    (++ i)
    (when (= i (length args))
      (errorf "missing argument"))
    (args i))

  (while (< i (length args))
    (def arg (args i))
    (if (string/has-prefix? "-" arg)
      (do
        (def sym (lookup arg))
        (when (nil? sym)
          # TODO: nice error message for negative number
          (errorf "unknown flag %s" arg))
        (def t (assert (flags sym)))
        (def ref (assert (refs sym)))

        (try-with-context arg
          (if (t :takes-value?)
            ((ref :set) ((t :update) ((ref :get)) (next-arg)))
            ((ref :set) ((t :update) ((ref :get)))))))
      (array/push anons arg))
    (++ i)))

(defn- is-probably-interpreter? []
  (= (last (string/split "/" (dyn *executable*))) "janet"))

(defn- get-actual-args []
  (if (is-probably-interpreter?)
    (drop 1 (dyn *args*))
    (dyn *args*)))

(defmacro immediate [& spec]
  (def spec (parse-specification spec))

  (def syms (spec :declared-order))
  (def gensyms (struct ;(catseq [sym :in syms] [sym (gensym)])))

  (def var-declarations
    (seq [sym :in syms
          :let [$sym (gensyms sym)
                flag ((spec :flags) sym)
                t (flag :type)]]
      ~(var ,$sym ,(t :init))))

  (def finalizations
    (seq [sym :in syms
          :let [$sym (gensyms sym)
                flag ((spec :flags) sym)
                name (primary-name flag)
                t (flag :type)]]
      ~(as-macro
        ,try-with-context ,name
        (,(t :finish) ,$sym))))

  (def refs
    (catseq [sym :in (spec :declared-order)
             :let [$sym (gensyms sym)]]
      [~',sym
        ~{:get (fn [] ,$sym)
          :set (fn [x] (set ,$sym x))}]))

  ~(def [,;syms]
    (try (do
      ,;var-declarations
      (,parse-args
        (,get-actual-args)
        ,(quote-flags (spec :flags))
        ,(quote-values (spec :names))
        (struct ,;refs))
      [,;finalizations])
    ([err]
      (eprint err)
      (os/exit 1)
      ))))
