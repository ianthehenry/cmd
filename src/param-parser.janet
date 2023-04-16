# compile-time parser for the [--foo (optional :string)] DSL

(use ./util)
(use ./bridge)
(import ./help)

(defn- named-param? [token]
  (and
    (= (type token) :symbol)
    (string/has-prefix? "-" token)))

(defn- goto-state [ctx next-state]
  (set (ctx :state) next-state))

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
        ~[,$tag ,$type])
      ~[,(infer-tag name-or-names) ,form]))
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
          (putf! alias-remap (string name) sym "duplicate alias %q" name))
        sym)
      (do
        (def name name-or-names)
        (putf! alias-remap (string name) name "duplicate alias %q" name)
        name)))
    (def $type
      (if takes-value?
        (tagged-variant-parser name-or-names type-declaration)
        type-declaration))
    (putf! types-for-param key $type "BUG: duplicate key %q" key))

  (defn parse-string [[alias-remap types-for-param] param-name value]
    (def key (alias-remap param-name))
    (def t (types-for-param key))
    (if takes-value?
      (do
        (assert (string? value))
        (def [tag [_ of-string]] t)
        [tag (of-string value)])
      (do (assert (nil? value)) t)))

  [additional-names
   takes-value?
   ~[,(quote-keys-and-values alias-remap) ,(quote-keys types-for-param)]
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
     type-declaration
     (fn [[_ parse-string] name value] (parse-string value))]))

(defn missing-required-argument []
  (error "missing required argument"))

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
       (missing-required-argument))
     val)}])

(defn- rewrite-value [handler new]
  (if (not= (handler :value) :none) new))

(defn- handle/optional [type-declaration &opt default]
  (def [additional-names handler] (handle/required type-declaration))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :optional)
    :finish (fn [val] (if (unset? val) default val)))])

(defn- handle/last+ [type-declaration]
  (def [additional-names handler] (handle/required type-declaration))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :variadic+)
    :update (fn [t name _ new] ((handler :update) t name unset-sentinel new)))])

(defn- handle/last [type-declaration &opt default]
  (def [additional-names handler] (handle/optional type-declaration default))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :variadic)
    :update (fn [t name _ new] ((handler :update) t name unset-sentinel new)))])

(defn- handle/flag []
  [[]
   {:init unset
    :value :none
    :type nil
    :update (fn [_ _ old _] (assert-unset old) true)
    :finish (fn [val]
     (if (unset? val) false val))}])

(defn- handle/effect [f]
  [[]
  {:init unset
   :value :none
   :type f
   :symless true
   :update (fn [[_ t] _ old _] (assert-unset old) t)
   :finish (fn [val] (if (unset? val) nil (val)))}])

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

(defn- handle/listed-array+ [type-declaration]
  (def [additional-names handler] (handle/listed-array type-declaration))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :variadic+)
    :finish (fn [arr]
      (if (empty? arr)
        (missing-required-argument))
      arr))])

(defn- handle/listed-tuple [type-declaration]
  (def [additional-names handler] (handle/listed-array type-declaration))
  [additional-names (struct/with-proto handler :finish tuple/slice)])

(defn- handle/listed-tuple+ [type-declaration]
  (def [additional-names handler] (handle/listed-array type-declaration))
  [additional-names (struct/with-proto handler
    :value (rewrite-value handler :variadic+)
    :finish (fn [arr]
      (if (empty? arr)
        (missing-required-argument))
      (tuple/slice arr)))])

(defn- handle/escape [&opt type-declaration]
  (if (nil? type-declaration)
    [[] {:symless true :value :soft-escape}]
    (do
      (def [additional-names handler] (handle/listed-tuple type-declaration))
      [additional-names (struct/with-proto handler
        :value (rewrite-value handler :greedy))])))

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
    'last (handle/last ;(arity op args 1 2))
    'last+ (handle/last+ ;(arity op args 1 1))
    'counted (handle/counted ;(arity op args 0 0))
    'flag (handle/flag ;(arity op args 0 0))
    'escape (handle/escape ;(arity op args 0 1))
    'effect (handle/effect ;(arity op args 1 1))
    'tuple (handle/listed-tuple ;(arity op args 1 1))
    'tuple+ (handle/listed-tuple+ ;(arity op args 1 1))
    'array (handle/listed-array ;(arity op args 1 1))
    'array+ (handle/listed-array+ ;(arity op args 1 1))
    (errorf "unknown operation %q" op)))

(defn- parse-handler [form]
  (case (type+ form)
    :tuple-parens (parse-form-handler form)
    :keyword (handle/required form)
    :struct (handle/required form)
    :table (handle/required form)
    (errorf "unknown handler %q" form)))

(defn- finish-param [ctx param next-state]
  (def {:names names :sym sym :doc doc-string :handler handler} param)

  (when (nil? handler)
    (errorf "no handler for %s" sym))

  (def [additional-names handler] (parse-handler handler))
  (def names
    (if (empty? additional-names)
      names
      (do
        (assertf (empty? names) "you must specify all aliases for %s inside {}" sym)
        additional-names)))

  (def symless? (handler :symless))
  (def soft-escape? (= (handler :value) :soft-escape))
  (assert (or sym symless?)
    "only soft escapes and effects can be anonymous")
  (def sym (if symless? (gensym) sym))

  (each name names
    (when (in (ctx :names) name)
      (errorf "multiple parameters named %s" name))
    (put (ctx :names) name sym))

  (when ((ctx :params) sym)
    (errorf "duplicate parameter %s" sym))

  (def positional? (empty? names))

  (when positional?
    (assertf (not symless?)
      "positional argument needs a valid symbol")
    (assert (not= (ctx :variadic-positional) :greedy)
      "only the final positional parameter can have an escape handler")
    (def value-handling (handler :value))
    (cond
      (= value-handling :none) (errorf "illegal handler for positional argument %s" sym)
      (or (= value-handling :variadic)
          (= value-handling :variadic+)
          (= value-handling :greedy))
        (do
          (assert (nil? (ctx :variadic-positional))
            "you cannot specify specify multiple variadic positional parameters")
          (put ctx :variadic-positional value-handling))))

  (def param (if positional?
    {:doc doc-string
     :handler handler
     :sym sym}
    {:doc doc-string
     :names names
     :handler handler}))

  (put (ctx :params) sym param)

  (if positional?
    (array/push (ctx :positional-params) param)
    (put (ctx :named-params) sym param))

  (goto-state ctx next-state))

(var- state/param nil)

(defn- symbol-of-name [name]
  (def base (string/triml name "-"))
  (if (empty? base) nil (symbol base)))

(defn- new-param-state [spec-names]
  (assertf (not (empty? spec-names))
    "unexpected token %q" spec-names)
  (def first-name (first spec-names))
  (assertf (all symbol? spec-names)
    "unexpected token %q" spec-names)

  (def [sym param-names]
    (if (named-param? first-name)
      [(symbol-of-name first-name) spec-names]
      [first-name (drop 1 spec-names)]))

  (each param param-names
    (unless (named-param? param)
      (errorf "all aliases must start with - %q" spec-names)))

  (def param-names (map string param-names))

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
      (when-let [handler (self :handler)]
        (errorf "multiple handlers specified for %s (got %q, already have %q)"
          (display-name self) expr handler))
      (set (self :handler) expr))
    :on-eof (fn [self ctx] (finish-param ctx self nil))})

(defn- set-ctx-doc [self ctx expr]
  (assertf (nil? (ctx :doc)) "unexpected token %q" expr)
  (set (ctx :doc) expr))

(def- state/pending
  @{:on-string set-ctx-doc
    :on-param (fn [self ctx names] (goto-state ctx (new-param-state names)))
    :on-other set-ctx-doc
    :on-eof (fn [_ _])})

(def- state/initial
  (table/setproto
    @{:on-other (fn [self ctx token]
      (set-ctx-doc self ctx token)
      (goto-state ctx state/pending))}
    state/pending))

(defn- add-help [ctx]
  # this could be cleaner... the whole ctx state parsing
  # thing is a little janky
  (def public-help-name "--help")
  (unless (nil? ((ctx :names) public-help-name))
    (break))
  (def default-help-names [public-help-name "-h" "-?"])
  (def help-names (seq [name :in default-help-names :when (hasnt? (ctx :names) name)] name))
  (unless (empty? help-names)
    (def [_ handler] (handle/effect (defn []
      (help/simple (dyn *spec*))
      (os/exit 0))))
    (def help-param
      {:names [public-help-name]
       :doc "Print this help text and exit"
       :handler handler})
    (def help-sym (gensym))
    (each name help-names
      (put! (ctx :names) name help-sym))
    (put! (ctx :named-params) help-sym help-param)
    (put! (ctx :params) help-sym help-param)))

# Returns an abstract syntax tree
# that can be evaluated to produce
# a spec
(defn parse-specification [spec]
  (def ctx
    @{:params @{} # symbol -> param
      :named-params @{} # symbol -> param
      :positional-params @[]
      :names @{} # string -> symbol
      :variadic-positional nil
      :state state/initial
      :doc nil
      })

  (each token spec
    (def state (ctx :state))
    (case (type+ token)
      :string (:on-string state ctx token)
      :tuple-brackets (:on-param state ctx token)
      :symbol (:on-param state ctx [token])
      (:on-other state ctx token)))
  (:on-eof (ctx :state) ctx)
  (add-help ctx)
  ctx)
