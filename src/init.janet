(defn- has? [p x y]
  (= (p x) y))

(defmacro- catseq [& args]
  ~(mapcat |$ (seq ,;args)))

# TODO: this needs a more clear name. what we're doing is
# converting this into a format that can be interpreted.
# as part of this, we'll need to evaluate the parser itself,
# which we do not currently do.
(defn- quote-named-params [params]
  ~(struct
    ,;(catseq [[sym {:type t}] :pairs params]
      [~',sym (struct/proto-flatten t)])))

(defn- quote-positional-params [params]
  ~[,;(seq [{:sym sym :type t} :in params]
      {:type (struct/proto-flatten t) :sym ~',sym})])

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

(defn- named-param? [token]
  (and
    (= (type token) :symbol)
    (string/has-prefix? "-" token)))

(defn- goto-state [ctx next-state]
  (set (ctx :state) next-state))

(defn- display-name [{:names names :sym sym}]
  (if (or (nil? names) (empty? names))
    (string sym)
    (string/join names "/")))

(defn- type+ [form]
  (let [t (type form)]
    (case t
      :tuple (case (tuple/type form)
        :brackets :tuple-brackets
        :parens :tuple-parens)
      t)))

(defn- assert-unset [val] (assert (unset? val) "duplicate argument"))

(defn- named-param-to-string [token]
  (if (named-param? token)
    (string token)
    (assertf "expected named parameter, got %q" token)))

(defn- named-params-from-keys [s]
  (catseq [key :keys s]
    (case (type+ key)
      :tuple-brackets (map named-param-to-string key)
      [(named-param-to-string key)])))

(defn- put-unique [table key value str & args]
  (assertf (nil? (table key)) str ;args)
  (put table key value))

(defn- builtin-type-parser [token]
  (case token
    :string |$
    :number (error "unimplemented")
    (errorf "unknown type %q" token)))

(defn- peg-parser [peg]
  (def peg (peg/compile peg))
  (fn [str]
    (def matches (peg/match peg str))
    (if (and (not (nil? matches)) (has? length matches 1))
      (first matches)
      (errorf "unable to parse %q" str))))

(defn- parse-simple-type-declaration [type-declaration]
  (cond
    (keyword? type-declaration) (builtin-type-parser type-declaration)
    (and (has? type+ type-declaration :tuple-parens)
      (= (first type-declaration) 'quasiquote)) ~(,peg-parser ,type-declaration)
    type-declaration))

(defn- infer-tag [name-or-names]
  (def name
    (if (tuple? name-or-names)
      (first name-or-names)
      name-or-names))
  (keyword (string/triml name "-")))

(defn- tagged-variant-parser [name-or-names form]
  (def $tag-and-parser
    (if (has? type+ form :tuple-brackets)
      (do
        (assertf (has? length form 2)
          "expected tuple of two elements, got %q" form)
        (def [$tag $type] form)
        ~[,$tag ,(parse-simple-type-declaration $type)])
      ~[,(infer-tag name-or-names) ,(parse-simple-type-declaration form)]))
  $tag-and-parser)

(defn- get-dictionary-parser [dict]
  (def additional-names (named-params-from-keys dict))
  (def takes-value? (table? dict))

  # we only want to evaluate each type declaration once,
  # so we make two lookup tables: one from string name
  # to unique symbol, and one from unique symbol to
  # abstract syntax tree. we'll evaluate the latter table,
  # and use the former table to decide how to look up in it
  (def alias-remap @{})
  (def types-for-param @{})
  (eachp [name-or-names type-declaration] dict
    (def key (if (tuple? name-or-names)
      (do
        (assertf (not (empty? name-or-names)) "unexpected token %q" name-or-names)
        (def sym (gensym))
        (each name name-or-names
          (put-unique alias-remap (string name) sym "duplicate alias %q" name))
        sym)
      (do
        (def name name-or-names)
        (put-unique alias-remap (string name) name "duplicate alias %q" name)
        name)))
    (def $type
      (if takes-value?
        (tagged-variant-parser name-or-names type-declaration)
        type-declaration))
    (put-unique types-for-param key $type "BUG: duplicate key %q" key))

  (defn parse-string [types-for-param param-name value]
    (def key (alias-remap param-name))
    (def t (types-for-param key))
    (if takes-value?
      (do
        (assert (string? value))
        (def [tag of-string] t)
        [tag (of-string value)])
      (do (assert (nil? value)) t)))

  [additional-names
   takes-value?
   (quote-keys types-for-param)
   parse-string])

# a type declaration can be an arbitrary expression. returns
# [additional-names takes-value? $type parse-string]
# $type is an abstract syntax tree that will be evaluated
# parse-string is a function from [type param-name arg-value] -> value
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
    :value (if takes-value? :required :none)
    :type $type
    :update (fn [t name old new]
      (assert-unset old)
      (parse-string t name new))
    :finish (fn [val]
     (when (unset? val)
       (error "missing required argument"))
     val)}])

(defn- rewrite-value [handler new]
  (if (not= (handler :value) :none) new))

(defn- handle/optional [type-declaration &opt default]
  (def [additional-names handler] (handle/required type-declaration))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :optional)
    :finish (fn [val] (if (unset? val) default val)))])

(defn- handle/last [type-declaration]
  (def [additional-names handler] (handle/required type-declaration))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :variadic)
    :update (fn [t name _ new] ((handler :update) t name unset-sentinel new)))])

(defn- handle/last? [type-declaration &opt default]
  (def [additional-names handler] (handle/optional type-declaration default))
  [additional-names (struct/with-proto handler
    :update (fn [t name _ new] ((handler :update) t name unset-sentinel new)))])

(defn- handle/flag []
  [[]
   {:init unset
    :value :none
    :type nil
    :update (fn [_ _ old _] (assert-unset old) true)
    :finish (fn [val]
     (if (unset? val) false val))}])

(defn- handle/counted []
  [[]
   {:init 0
    :value :none
    :type nil
    :update (fn [_ _ old _] (+ old 1))
    :finish |$}])

(defn- handle/listed-array [type-declaration]
  (def [additional-names takes-value? $type parse-string] (get-parser type-declaration))
  [additional-names
   {:init @[]
    :value (if takes-value? :variadic :none)
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
    'quasiquote (handle/required form)
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

(defn- finish-param [ctx param next-state]
  (def {:names names :sym sym :doc doc-string :type handler} param)

  (when (nil? handler)
    (errorf "no handler for %s" sym))

  (def [additional-names actual-type] (parse-handler handler))
  (def names
    (if (empty? additional-names)
      names
      (do
        (assertf (empty? names) "you must specify all aliases for %s inside {}" sym)
        additional-names)))

  (each name names
    (when (in (ctx :names) name)
      (errorf "multiple parameters with alias %s" name))
    (put (ctx :names) name sym))

  (when ((ctx :params) sym)
    (errorf "duplicate parameter %s" sym))

  (def positional? (empty? names))

  (when positional?
    (case (actual-type :value)
      :none (errorf "illegal handler for positional argument %s" sym)
      :variadic (do
        (assertf (not (ctx :variadic-positional?))
          "you cannot specify specify multiple variadic positional parameters")
        (put ctx :variadic-positional? true))))

  (def param (if positional?
    {:doc doc-string
     :type actual-type
     :sym sym}
    {:doc doc-string
     :names names
     :type actual-type}))

  (put (ctx :params) sym param)

  (if positional?
    (array/push (ctx :positional-params) param)
    (put (ctx :named-params) sym param))

  (goto-state ctx next-state))

(var- state/param nil)

(defn- new-param-state [spec-names]
  (assertf (not (empty? spec-names))
    "unexpected token %q" spec-names)
  (def first-name (first spec-names))
  (assertf (all symbol? spec-names)
    "unexpected token %q" spec-names)

  (def [sym param-names]
    (if (named-param? first-name)
      [(symbol (string/triml first-name "-")) spec-names]
      [first-name (drop 1 spec-names)]))

  (each param param-names
    (unless (named-param? param)
      (errorf "all aliases must start with - %q" spec-names)))

  (def param-names (map string param-names))

  (each name param-names
    (when (all |(= $ (chr "-")) name)
      (errorf "illegal parameter name %s" name)))

  (table/setproto @{:names param-names :sym sym} state/param))

# TODO: there should probably be an escape hatch to declare a dynamic docstring.
# Right now the doc string has to be a string literal, which is limiting.
(set state/param
  @{:on-string (fn [self ctx str]
      (when (self :doc)
        (error "docstring already set"))
      (set (self :doc) str))
    :on-param (fn [self ctx names]
      (finish-param ctx self (new-param-state names)))
    :on-other (fn [self ctx expr]
      (when-let [handler (self :type)]
        (errorf "multiple handlers specified for %s (got %q, already have %q)"
          (self :sym) expr handler))
      (set (self :type) expr))
    :on-eof (fn [self ctx] (finish-param ctx self nil))})

(defn- set-ctx-doc [self ctx expr]
  (assertf (nil? (ctx :doc)) "unexpected token %q" expr)
  (set (ctx :doc) expr))

(def- state/pending
  @{:on-string set-ctx-doc
    :on-param (fn [self ctx names] (goto-state ctx (new-param-state names)))
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
    @{:params @{} # set of symbols
      :named-params @{} # symbol -> param
      :positional-params @[]
      :names @{} # string -> symbol
      :variadic-positional? false
      :state state/initial
      })

  (each token spec
    (def state (ctx :state))
    (case (type+ token)
      :string (:on-string state ctx token)
      :tuple-brackets (:on-param state ctx token)
      :symbol (:on-param state ctx [token])
      (:on-other state ctx token)))
  (:on-eof (ctx :state) ctx)
  ctx)

(defn- print-help [spec]
  (when-let [doc-string (spec :doc)]
    (print doc-string)
    (print))

  (each [_ {:names names :type t :doc doc}]
    (sorted-by 0 (pairs (spec :named-params)))
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

# param: {sym arity type}
(defn- assign-positional-args [args params refs]
  (def num-args (length args))

  (var num-required-params 0)
  (var num-optional-params 0)
  (each {:type {:value value-handling}} params
    (case value-handling
      :required (++ num-required-params)
      :optional (++ num-optional-params)
      :variadic nil
      (errorf "BUG: unknown value handler %q" value-handling)))

  (var num-optional-args
    (min (- num-args num-required-params) num-optional-params))

  (var num-variadic-args
    (- num-args (+ num-required-params num-optional-args)))

  (defn assign [{:type t :sym sym} arg]
    (def ref (assert (refs sym)))
    (def {:update handle :type t} t)
    (try-with-context sym
      (set-ref ref (handle t nil (get-ref ref) arg))))

  (var arg-index 0)
  (defn take-arg []
    (assert (< arg-index num-args))
    (def arg (args arg-index))
    (++ arg-index)
    arg)
  (each param params
    (case ((param :type) :value)
      :required (do
        (assertf (< arg-index num-args)
          "missing required argument %s" (param :sym))
        (assign param (take-arg)))
      :optional
        (when (> num-optional-args 0)
          (assign param (take-arg))
          (-- num-optional-args))
      :variadic
        (while (> num-variadic-args 0)
          (assign param (take-arg))
          (-- num-variadic-args))
      (assert false)))

  (when (< arg-index num-args)
    (errorf "unexpected argument %s" (args arg-index))))

# args: [string]
# params: sym -> type description
# param-names: string -> sym
# refs: sym -> ref
(defn- parse-args [args named-params param-names positional-params refs]
  (var i 0)
  (def positional-args @[])

  (defn next-arg []
    (++ i)
    (when (= i (length args))
      (errorf "no value for argument"))
    (args i))

  (while (< i (length args))
    (def arg (args i))
    (if (string/has-prefix? "-" arg)
      (do
        (def sym (param-names arg))
        (when (nil? sym)
          # TODO: nice error message for negative number
          (errorf "unknown parameter %s" arg))
        (def t (assert (named-params sym)))
        (def ref (assert (refs sym)))
        (def {:update handle :type t :value value} t)
        (def takes-value? (not= value :none))

        (try-with-context arg
          (set-ref ref (handle t arg (get-ref ref) (if takes-value? (next-arg) nil)))))
      (array/push positional-args arg))
    (++ i))
  (assign-positional-args positional-args positional-params refs))

(defn- is-probably-interpreter? []
  (= (last (string/split "/" (dyn *executable*))) "janet"))

(defn- get-actual-args []
  (if (is-probably-interpreter?)
    (drop 1 (dyn *args*))
    (dyn *args*)))

(defn- assignment [spec]
  (def syms (keys (spec :params)))
  (def gensyms (struct ;(catseq [sym :in syms] [sym (gensym)])))

  (def var-declarations
    (seq [sym :in syms
          :let [$sym (gensyms sym)
                param ((spec :params) sym)
                t (param :type)]]
      ~(var ,$sym ,(t :init))))

  (def finalizations
    (seq [sym :in syms
          :let [$sym (gensyms sym)
                param ((spec :params) sym)
                name (display-name param)
                t (param :type)]]
      ~(as-macro
        ,try-with-context ,name
        (,(t :finish) ,$sym))))

  (def refs
    (catseq [sym :in syms
             :let [$sym (gensyms sym)]]
      [~',sym
        ~{:get (fn [] ,$sym)
          :set (fn [x] (set ,$sym x))}]))

  ~(def [,;syms]
    (try (do
      ,;var-declarations
      (,parse-args
        (,get-actual-args)
        ,(quote-named-params (spec :named-params))
        ,(quote-values (spec :names))
        ,(quote-positional-params (spec :positional-params))
        (struct ,;refs))
      [,;finalizations])
    ([err]
      (eprint err)
      (os/exit 1)
      ))))

(defmacro simple [spec & body]
  (unless (= (type+ spec) :tuple-brackets)
    (errorf "expected bracketed list of parameters, got %q" spec))
  (def spec (parse-specification spec))
  ~(fn [& args]
    ,(assignment spec)
    ,;body))

(defmacro immediate [& spec]
  (def spec (parse-specification spec))
  (assignment spec))
