(use ./util)
(import ./help :prefix "" :export true)

(def- *spec* (keyword (gensym)))

# TODO: this needs a more clear name. what we're doing is
# converting this into a format that can be interpreted.
# as part of this, we'll need to evaluate the parser itself,
# which we do not currently do.
(defn- quote-named-params [params]
  ~(struct
    ,;(catseq [[sym {:handler handler :doc doc}] :pairs params]
      [~',sym {:handler (struct/proto-flatten handler)
               :doc doc}])))

(defn- quote-positional-params [params]
  ~[,;(seq [{:sym sym :handler handler} :in params]
      {:handler (struct/proto-flatten handler) :sym ~',sym})])

(defn- quote-keys [dict]
  ~(struct
    ,;(catseq [[key val] :pairs dict]
      [~',key val])))

(defn- quote-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [key ~',val])))

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

(defn- handle/effect [f]
  [[]
  {:init unset
   :value :none
   :type f
   :symless true
   :update (fn [t _ old _] (assert-unset old) t)
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

(defn- handle/listed-tuple [type-declaration]
  (def [additional-names handler] (handle/listed-array type-declaration))
  [additional-names (struct/with-proto handler :finish tuple/slice)])

(defn- handle/escape [&opt type-declaration]
  (if (nil? type-declaration)
    [[] {:symless true :value :soft-escape}]
    (do
      (def [additional-names handler] (handle/listed-tuple type-declaration))
      [additional-names (struct/with-proto handler
        :value (rewrite-value handler :greedy)
        :finish tuple/slice)])))

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
    'escape (handle/escape ;(arity op args 0 1))
    'effect (handle/effect ;(arity op args 1 1))
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
    :on-other (fn [self ctx token] (errorf "unexpected token %q" token))
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
  (def default-help-names ["--help" "-h" "-?"])
  (def help-names (seq [name :in default-help-names :when (hasnt? (ctx :names) name)] name))
  (unless (empty? help-names)
    (def [_ handler] (handle/effect (defn []
      (print-help (dyn *spec*))
      (os/exit 0))))
    (def help-param
      {:names help-names
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
(defn- parse-specification [spec]
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

(defn- bake-spec [ctx]
  {:named (quote-named-params (ctx :named-params))
   :names (quote-values (ctx :names))
   :pos (quote-positional-params (ctx :positional-params))
   :doc (ctx :doc)})

# param: {sym handler}
(defn- assign-positional-args [args params refs]
  (def num-args (length args))
  (def errors @{})

  (var num-required-params 0)
  (var num-optional-params 0)
  (each {:handler {:value value-handling}} params
    (case value-handling
      :required (++ num-required-params)
      :optional (++ num-optional-params)
      :variadic nil
      :greedy nil
      (errorf "BUG: unknown value handler %q" value-handling)))

  (var num-optional-args
    (min (- num-args num-required-params) num-optional-params))

  (var num-variadic-args
    (- num-args (+ num-required-params num-optional-args)))

  (defn assign [{:handler handler :sym sym} arg]
    (def ref (assert (refs sym)))
    (def {:update handle :type t} handler)
    (try-with-context sym errors
      (set-ref ref (handle t nil (get-ref ref) arg))))

  (var arg-index 0)
  (defn take-arg []
    (assert (< arg-index num-args))
    (def arg (args arg-index))
    (++ arg-index)
    arg)
  (each param params
    (case ((param :handler) :value)
      :required (do
        (if (< arg-index num-args)
          (assign param (take-arg))
          (do
            (table/push errors "" "not enough arguments")
            (break))))
      :optional
        (when (> num-optional-args 0)
          (assign param (take-arg))
          (-- num-optional-args))
      :variadic
        (while (> num-variadic-args 0)
          (assign param (take-arg))
          (-- num-variadic-args))
      :greedy nil
      (assert false)))

  (when (< arg-index num-args)
    (table/push errors "" (string/format "unexpected argument %s" (args arg-index))))
  errors)

(defmacro- consume [name expr]
  ~(let [{:update handle :type t} handler]
    (try-with-context ,name errors
      (set-ref ref (handle t (if (string? ,name) ,name) (get-ref ref) ,expr)))))

# args: [string]
# spec:
#   named-params: sym -> param
#   param-names: string -> sym
#   pos: [param]
# refs: sym -> ref
(defn- parse-args [args {:named named-params :names param-names :pos positional-params} refs]
  (var i 0)
  (def errors @{})
  (def positional-args @[])
  (var soft-escaped? false)

  # TODO: we need to set an invariant that there can be no
  # positional arguments declared after a hard positional escape
  (def positional-hard-escape-param
    (if-let [last-param (last positional-params)]
      (if (= ((last-param :handler) :value) :greedy) last-param)))

  (defn next-arg []
    (if (= i (length args))
      (errorf "no value for argument"))
    (def arg (args i))
    (++ i)
    arg)

  (defn positional? [arg]
    (or soft-escaped?
      (not (string/has-prefix? "-" arg))))

  (defn handle [sym param])

  (defn final-positional? []
    (= (length positional-args)
       (- (length positional-params) 1)))

  (while (< i (length args))
    (def arg (args i))
    (++ i)
    (label continue
      (if (positional? arg)
        (if (and positional-hard-escape-param (final-positional?))
          (let [{:sym sym :handler handler} positional-hard-escape-param
                 ref (assert (refs sym))]
            (consume sym arg)
            (while (< i (length args)) (consume sym (next-arg))))
          (array/push positional-args arg))
        (let [sym (param-names arg)]
          # TODO: nice error message for negative number
          (when (nil? sym)
            (table/push errors arg "unknown parameter")
            (return continue))
          (def {:handler handler} (assert (named-params sym)))
          (def {:value value-handling} handler)
          (if (= value-handling :soft-escape)
            (set soft-escaped? true)
            (do
              (def takes-value? (not= value-handling :none))
              (def ref (assert (refs sym)))
              (case value-handling
                :none (consume arg nil)
                :greedy (while (< i (length args)) (consume arg (next-arg)))
                (consume arg (next-arg)))))))))
  (table/union errors (assign-positional-args positional-args positional-params refs))
  errors)

(def- -foo=bar ~(* (<- (* "-" (some ,(^ "= ")))) "=" (<- (to -1))))
(def- -xyz ~(* "-" (group (some (<- ,(^ "- ")))) -1))

(defn- split-short-flags [arg]
  (if-let [[args] (peg/match -xyz arg)]
    (map |(string "-" $) args)
    [arg]))

(defn- normalize-args [args]
  (def result @[])
  (each arg args
    (if-let [[arg val] (peg/match -foo=bar arg)]
      (array/concat result (split-short-flags arg) [val])
      (array/concat result (split-short-flags arg))))
  result)

(defn args []
  (normalize-args
    (if (is-probably-interpreter?)
      (drop 1 (dyn *args*))
      (dyn *args*))))

(defn- print-parse-errors [err-table]
  (if-let [ctxless-errors (err-table "")]
    (each err ctxless-errors
      (eprint err))
    (loop [[context errs] :pairs err-table :when (not= context "")]
      (eprintf "%s: %s" context (first errs)))))

(defn- assignment [spec]
  (def params (spec :params))
  (def all-syms (seq [sym :keys params :when (not= (((params sym) :handler) :value) :soft-escape)] sym))
  (def {true private-syms false public-syms} (group-by |(truthy? (((params $) :handler) :nameless)) all-syms))
  (default private-syms [])
  (default public-syms [])
  (def gensyms (struct ;(catseq [sym :in all-syms] [sym (gensym)])))

  (def var-declarations
    (seq [sym :in all-syms
          :let [$sym (gensyms sym)
                param (params sym)
                handler (param :handler)]]
      ~(var ,$sym ,(handler :init))))


  (def refs
    (catseq [sym :in all-syms
             :let [$sym (gensyms sym)]]
      [~',sym
        ~{:get (fn [] ,$sym)
          :set (fn [x] (set ,$sym x))}]))

  (with-syms [$spec $errors $results]
    (defn finalizations-of [syms]
      (seq [sym :in syms
            :let [$sym (gensyms sym)
                  param (params sym)
                  name (display-name param)
                  handler (param :handler)]]
        ~(as-macro
          ,try-with-context ,name ,$errors
          (,(handler :finish) ,$sym))))
    ~(def [,;public-syms]
      (let [,$spec ,(bake-spec spec)] (with-dyns [,*spec* ,$spec]
        ,;var-declarations
        (def ,$errors (,parse-args
          (,args)
          ,$spec
          (,struct ,;refs)))
        ,;(finalizations-of private-syms)
        (def ,$results [,;(finalizations-of public-syms)])
        (unless (,empty? ,$errors)
          (,print-parse-errors ,$errors)
          (,os/exit 1))
        ,$results)))))

(defmacro simple [spec & body]
  (unless (= (type+ spec) :tuple-brackets)
    (errorf "expected bracketed list of parameters, got %q" spec))
  (def spec (parse-specification spec))
  ~(fn [& args]
    ,(assignment spec)
    ,;body))

(defmacro script [& spec]
  (def spec (parse-specification spec))
  (assignment spec))

(defn parse [spec args]
  (def handlers @{})
  (eachp [sym {:handler handler}] (spec :named)
    (put handlers sym handler))
  (each {:sym sym :handler handler} (spec :pos)
    (put handlers sym handler))

  (def scope (tabseq [[sym handler] :pairs handlers]
    sym (handler :init)))
  (def refs (tabseq [sym :keys handlers]
    sym {:get (fn [] (scope sym)) :set (fn [x] (put scope sym x))}))
  (with-dyns [*spec* spec]
    (def errors (parse-args args spec refs))
    (def result @{})
    (eachp [sym val] scope
      (def handler (assert (handlers sym)))
      (try-with-context sym errors
        (put result (keyword sym) ((handler :finish) val))))
    result))

(defmacro spec [& s]
  (bake-spec (parse-specification s)))
