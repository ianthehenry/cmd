(def number-type (fn [str] (assert (scan-number str))))
(def string-type (fn [str] str))

(defmacro- catseq [& args]
  ~(mapcat |$ (seq ,;args)))

# TODO: this needs a more clear name. what we're doing is
# converting this into a format that can be interpreted.
# as part of this, we'll need to evaluate the parser itself,
# which we do not currently do.
(defn- quote-args [args]
  # because otherwise the prototype will be completely ignored...
  ~(struct
    ,;(catseq [[key {:type t}] :pairs args]
      [~',key (struct/proto-flatten t)])))

(defn- quote-keys [dict]
  ~(struct
    ,;(catseq [[key val] :pairs dict]
      [~',key val])))

(defn- quote-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [key ~',val])))

(defmacro- pdb [& exprs]
  ~(do
    ,;(seq [expr :in exprs]
        ~(eprintf "%s = %q" ,(string/format "%q" expr) ,expr))))

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
(defn- display-name [{:names names :sym sym}]
  (if (empty? names)
    sym
    (string/join names "/")))

(defn- type+ [form]
  (let [t (type form)]
    (case t
      :tuple (case (tuple/type form)
        :brackets :tuple-brackets
        :parens :tuple-parens)
      t)))

(defn- assert-unset [val] (assert (unset? val) "duplicate argument"))

(defn- named-arg-to-string [token]
  (if (named-arg? token)
    (string token)
    (assertf "expected named argument, got %q" token)))

(defn- named-args-from-keys [s]
  (catseq [key :keys s]
    (case (type+ key)
      :tuple-brackets (map named-arg-to-string key)
      [(named-arg-to-string key)])))

(defn- put-unique [table key value str & args]
  (assertf (nil? (table key)) str ;args)
  (put table key value))

(defn- parse-simple-type-declaration [type-declaration]
  (if (= type-declaration :string)
    |$
    (errorf "unknown type declaration %q" type-declaration)))

(defn- get-dictionary-parser [dict]
  (def additional-names (named-args-from-keys dict))
  (def takes-value? (table? dict))

  # we only want to evaluate each type declaration once,
  # so we make two lookup tables: one from string name
  # to unique symbol, and one from unique symbol to
  # abstract syntax tree. we'll evaluate the latter table,
  # and use the former table to decide how to look up in it
  (def alias-remap @{})
  (def types-for-arg @{})
  (eachp [name-or-names type-declaration] dict
    (def key (if (tuple? name-or-names)
      (do
        (def sym (gensym))
        (each name name-or-names
          (put-unique alias-remap (string name) sym "duplicate alias %q" name))
        sym)
      (do
        (def name name-or-names)
        (put-unique alias-remap (string name) name "duplicate alias %q" name)
        name)))
    (def value ((if takes-value? parse-simple-type-declaration |$) type-declaration))
    (put-unique types-for-arg key value "BUG: duplicate key %q" key))

  (defn parse-string [types-for-arg arg-name value]
    (def key (alias-remap arg-name))
    (def t (types-for-arg key))
    (if takes-value?
      # TODO: actually parse it as a function:
      # (do (assert (string? value) (t value)))
      (do (assert (string? value)) value)
      (do (assert (nil? value)) t)))

  [additional-names
   takes-value?
   (quote-keys types-for-arg)
   parse-string])

# a type declaration can be an arbitrary expression. returns
# [additional-names takes-value? $type parse-string]
# $type is an abstract syntax tree that will be evaluated
# parse-string is a function from [type argument-name argument-value] -> value
# parse-string takes the evaluated type
(defn- get-parser [type-declaration]
  (if (dictionary? type-declaration)
    (get-dictionary-parser type-declaration)
    [[]
     true
     (parse-simple-type-declaration type-declaration)
     (fn [parse-string name value] (parse-string value))]))

# TODO: parse
(defn- handle/required [type-declaration]
  (def [additional-names takes-value? $type parse-string] (get-parser type-declaration))
  [additional-names
   {:init unset
    :takes-value? takes-value?
    :type $type
    :update (fn [t name old new]
      (assert-unset old)
      (parse-string t name new))
    :finish (fn [val]
     (when (unset? val)
       (error "missing required argument"))
     val)}])

(defn- handle/optional [type-declaration &opt default]
  (def [additional-names handler] (handle/required type-declaration))
  [additional-names (struct/with-proto handler
    :finish (fn [val] (if (unset? val) default val)))])

(defn- handle/last [type-declaration]
  (def [additional-names handler] (handle/required type-declaration))
  [additional-names (struct/with-proto handler
    :update (fn [t name _ new] ((handler :update) t name unset-sentinel new)))])

(defn- handle/last? [type-declaration &opt default]
  (def [additional-names handler] (handle/optional type-declaration default))
  [additional-names (struct/with-proto handler
    :update (fn [t name _ new] ((handler :update) t name unset-sentinel new)))])

(defn- handle/flag []
  [[]
   {:init unset
    :takes-value? false
    :type nil
    :update (fn [_ _ old _] (assert-unset old) true)
    :finish (fn [val]
     (if (unset? val) false val))}])

(defn- handle/counted []
  [[]
   {:init 0
    :takes-value? false
    :type nil
    :update (fn [_ _ old _] (+ old 1))
    :finish |$}])

(defn- handle/listed-array [type-declaration]
  (def [additional-names takes-value? $type parse-string] (get-parser type-declaration))
  [additional-names
   {:init @[]
    :takes-value? takes-value?
    :type $type
    :update (fn [t name old new]
     (array/push old (parse-string t name new))
     old)
    :finish |$}])

(defn- handle/listed-tuple [type-declaration]
  (def [additional-names handler] (handle/listed-array type-declaration))
  [additional-names (struct/with-proto handler :finish tuple/slice)])

# returns a tuple of [additional-names handler]
(defn- parse-form-handler [form]
  (when (empty? form)
    (errorf "unable to parse form %q" form))

  (defn arity [op args min max]
    (when (< (length args) min)
      (errorf "not enough arguments to %q" op))
    (when (> (length args) max)
      (errorf "too many arguments to %q" op))
    args)

  (def [op & args] form)
  (case op
    'quasiquote (handle/required args)
    'required (handle/required ;(arity op args 1 1))
    'optional (handle/optional ;(arity op args 1 2))
    'last (handle/last ;(arity op args 1 1))
    'last? (handle/last? ;(arity op args 1 2))
    'counted (handle/counted ;(arity op args 0 0))
    'flag (handle/flag ;(arity op args 0 0))
    'tuple (handle/listed-tuple ;(arity op args 1 1))
    'array (handle/listed-array ;(arity op args 1 1))
    (errorf "unknown operation %q" op)))

(defn- parse-handler [form]
  (case (type+ form)
    :tuple-parens (parse-form-handler form)
    :keyword (handle/required form)
    :struct (handle/required form)
    :table (handle/required form)
    (errorf "unknown handler %q" form)))

(defn- finish-arg [ctx arg next-state]
  (def {:names names :sym sym :doc doc-string :type handler} arg)

  (when (nil? handler)
    (errorf "no handler for %s" sym))

  (def [additional-names actual-type] (parse-handler handler))
  (def names
    (if (empty? additional-names)
      names
      (do
        (assertf (empty? names) "you must specify all aliases for %q inside {}" sym)
        additional-names)))

  (each name names
    (when (in (ctx :names) name)
      (errorf "multiple arguments with alias %s" name))
    (put (ctx :names) name sym))

  (when ((ctx :args) sym)
    (errorf "duplicate argument %s" sym))

  (put (ctx :args) sym
    {:doc doc-string
     :names names
     :type actual-type})
  (array/push (ctx :declared-order) sym)
  (goto-state ctx next-state))

(var- state/arg nil)

(defn- new-arg-state [spec-names]
  (assertf (not (empty? spec-names))
    "unexpected token %q" spec-names)
  (def first-name (first spec-names))
  (assertf (all symbol? spec-names)
    "unexpected token %q" spec-names)

  (def [sym arg-names]
    (if (named-arg? first-name)
      [(symbol (string/triml first-name "-")) spec-names]
      [first-name (drop 1 spec-names)]))

  (each arg arg-names
    (unless (named-arg? arg)
      (errorf "all aliases must start with - %q" spec-names)))

  (def arg-names (map string arg-names))

  (each name arg-names
    (when (all |(= $ (chr "-")) name)
      (errorf "illegal argument name %s" name)))

  (table/setproto @{:names arg-names :sym sym} state/arg))

# TODO: there should probably be an escape hatch to declare a dynamic docstring.
# Right now the doc string has to be a string literal, which is limiting.
(set state/arg
  @{:on-string (fn [self ctx str]
      (when (self :doc)
        (error "docstring already set"))
      (set (self :doc) str))
    :on-arg (fn [self ctx names]
      (finish-arg ctx self (new-arg-state names)))
    :on-other (fn [self ctx expr]
      (when-let [handler (self :type)]
        (errorf "multiple handlers specified for %s (got %q, already have %q)"
          (self :sym) expr handler))
      (set (self :type) expr))
    :on-eof (fn [self ctx] (finish-arg ctx self nil))})

(defn- set-ctx-doc [self ctx expr]
  (assertf (nil? (ctx :doc)) "unexpected token %q" expr)
  (set (ctx :doc) expr))

(def- state/pending
  @{:on-string set-ctx-doc
    :on-arg (fn [self ctx names] (goto-state ctx (new-arg-state names)))
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
    @{:args @{}
      :names @{}
      :state state/initial
      :declared-order @[]})

  (each token spec
    (def state (ctx :state))
    (case (type+ token)
      :string (:on-string state ctx token)
      :tuple-brackets (:on-arg state ctx token)
      :symbol (:on-arg state ctx [token])
      (:on-other state ctx token)))
  (:on-eof (ctx :state) ctx)
  ctx)

(defn- print-help [spec]
  (when-let [doc-string (spec :doc)]
    (print doc-string)
    (print))

  (each [_ {:names names :type t :doc doc}]
    (sorted-by 0 (pairs (spec :args)))
    (printf "%s %q %q" names t doc)))

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

(defn- set-ref [ref value]
  ((ref :set) value))
(defn- get-ref [ref]
  ((ref :get)))

# args: [string]
# spec: sym -> type description
# lookup: string -> sym
# callbacks: string -> sym
(defn- parse-args [args spec lookup refs]
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
          (errorf "unknown argument %s" arg))
        (def t (assert (spec sym)))
        (def ref (assert (refs sym)))
        (def {:update handle :type t :takes-value? takes-value?} t)

        (try-with-context arg
          (set-ref ref (handle t arg (get-ref ref) (if takes-value? (next-arg) nil)))))
      (array/push anons arg))
    (++ i)))

(defn- is-probably-interpreter? []
  (= (last (string/split "/" (dyn *executable*))) "janet"))

(defn- get-actual-args []
  (if (is-probably-interpreter?)
    (drop 1 (dyn *args*))
    (dyn *args*)))

(defn- assignment [spec]
  (def syms (spec :declared-order))
  (def gensyms (struct ;(catseq [sym :in syms] [sym (gensym)])))

  (def var-declarations
    (seq [sym :in syms
          :let [$sym (gensyms sym)
                arg ((spec :args) sym)
                t (arg :type)]]
      ~(var ,$sym ,(t :init))))

  (def finalizations
    (seq [sym :in syms
          :let [$sym (gensyms sym)
                arg ((spec :args) sym)
                name (display-name arg)
                t (arg :type)]]
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
        ,(quote-args (spec :args))
        ,(quote-values (spec :names))
        (struct ,;refs))
      [,;finalizations])
    ([err]
      (eprint err)
      (os/exit 1)
      ))))

(defmacro simple [spec & body]
  (unless (= (type+ spec) :tuple-brackets)
    (errorf "expected bracketed list of args, got %q" spec))
  (def spec (parse-specification spec))
  ~(fn [& args]
    ,(assignment spec)
    ,;body))

(defmacro immediate [& spec]
  (def spec (parse-specification spec))
  (assignment spec))
