(def number-type (fn [str] (assert (scan-number str))))
(def string-type (fn [str] str))

(def- unset-sentinel (gensym))

(def- unset ~',unset-sentinel)

(defn unset? [x]
  (= x unset-sentinel))

(var state/flag nil)
(var state/pending nil)

(defn goto-state [ctx next-state]
  (set (ctx :state) next-state))

(defn type- [form]
  (let [t (type form)]
    (case t
      :tuple (case (tuple/type form)
        :brackets :tuple-brackets
        :parens :tuple-parens)
      t)))

# TODO: parse
(defn optional [form &opt default]
  {:init unset
   :takes-value? true
   :update (fn [old new]
    (assert (unset? old) "optional value already set")
    new)
   :finish (fn [val]
    (if (unset? val) default val))})

# TODO: parse
(defn required [form]
  {:init unset
   :takes-value? true
   :update (fn [old new]
    (assert (unset? old) "flag specified more than once")
    new)
   :finish (fn [val]
    (when (unset? val)
      (error "missing required flag"))
    val)})

(defn flag []
  {:init unset
   :takes-value? false
   :update (fn [old]
    (assert (unset? old) "flag specified more than once")
    true)
   :finish (fn [val]
    (if (unset? val) false val))})

(defn counted []
  {:init 0
   :takes-value? false
   :update (fn [old] (+ old 1))
   :finish |$})

# TODO: parse
(defn listed-array [form]
  {:init @[]
   :takes-value? true
   :update (fn [old new]
    (array/push old new)
    old)
   :finish |$})

# TODO: parse
(defn listed-tuple [form]
  {:init @[]
   :takes-value? true
   :update (fn [old new]
    (array/push old new)
    old)
   :finish tuple/slice})

(defn parse-form [form]
  (when (< (length form) 2)
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
    'count (counted ;(arity op args 1 1))
    (errorf "unknown operation %q" op)))

# brackets should be shorthand for listed
(defn parse-type [form]
  (case (type- form)
    :tuple-parens (parse-form form)
    :tuple-brackets (case (length form)
      1 (listed-tuple form)
      (errorf "unable to parse %q" form))
    :array (case (length form)
      1 (listed-array form)
      (errorf "unable to parse %q" form))
    :keyword (required form)
    ))

(defn finish-flag [ctx flag next-state]
  (def names (flag :names))
  (def sym (flag :sym))

  (when ((ctx :flags) sym)
    (errorf "duplicate flag %s" sym))

  (each name names
    (when (in (ctx :names) name)
      (errorf "conflicting alias %q" name))
    (put (ctx :names) name sym))

  (put (ctx :flags) sym
    {:doc (flag :doc)
     :names names
     :type (parse-type (flag :type))})
  (array/push (ctx :declared-order) sym)
  (goto-state ctx next-state))

(defn new-flag-state [name]
  (when (case name '- true '-- true false)
    (errorf "illegal flag name %q" name))

  (def name (string name))
  (def sym (symbol (string/triml name "-")))

  (table/setproto @{:names [name] :sym sym} state/flag))

(defn primary-name [flag] ((flag :names) 0))

# TODO: there should be an escape hatch to declare a dynamic docstring.
# right now the doc string has to be a string literal, which is limiting.
(set state/flag
  @{:on-string (fn [self ctx str]
      (when (self :doc)
        (error "doc string already set"))
      (set (self :doc) str))
    :on-flag (fn [self ctx name]
      (if (self :type)
        (finish-flag ctx self (new-flag-state name))
        (errorf "no parser for %s" (primary-name self))))
    :on-other (fn [self ctx expr]
      (when-let [peg (self :type)]
        (errorf "multiple parsers specified for %s (got %q, already have %q)"
          (primary-name self) expr peg))
      (set (self :type) expr))
    :on-eof (fn [self ctx] (finish-flag ctx self nil))})

(defn set-ctx-doc [self ctx expr]
  (assert (nil? (ctx :doc)) "should never transition back into pending state")
  (set (ctx :doc) expr))

(def state/pending
  @{:on-string set-ctx-doc
    :on-flag (fn [self ctx name] (goto-state ctx (new-flag-state name)))
    :on-other set-ctx-doc
    :on-eof (fn [_ _])})

(defn parse-specification [spec]
  (def ctx
    @{:flags @{}
      :names @{}
      :state state/pending
      :declared-order @[]})

  (each token spec
    (def state (ctx :state))
    (case (type token)
      :string (:on-string state ctx token)
      :symbol
        (if (string/has-prefix? "-" token)
          (:on-flag state ctx token)
          (:on-other state ctx token))
      (:on-other state ctx token)))
  (:on-eof (ctx :state) ctx)
  ctx)

(defmacro simple [doc-string spec & body]
  (unless (and (tuple? spec) (= (tuple/type spec) :brackets))
    (errorf "expected bracketed list of flags, got %q" spec))
  (def spec (parse-specification spec))

  ~(fn [& args]

    ,spec

    ))

#(setdyn *debug* true)

(defn print-help [spec]
  (when-let [doc-string (spec :doc)]
    (print doc-string)
    (print))

  (each [_ {:names names :type t :doc doc}]
    (sorted-by 0 (pairs (spec :flags)))
    (printf "%s %q %q" names t doc)))

(defmacro catseq [& args]
  ~(mapcat |$ (seq ,;args)))

(defmacro pdb [& exprs]
  ~(do
    ,;(seq [expr :in exprs]
        ~(eprintf "%s = %q" ,(string/format "%q" expr) ,expr))))

(defn quote-flags [flags]
  ~(struct
    ,;(catseq [[key {:type t}] :pairs flags]
      [~',key t])))

#(defn quote-keys [struct]
#  ~(struct
#    ,;(catseq [[key val] :pairs struct]
#      [~',key val])))

(defn quote-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [key ~',val])))

# TODO: you could imagine a debug mode
# where we preserve the stack frames here...
# actually maybe we should always preserve
# the stack frames, and just throw them away
# when we're using one of the user-facing macros?
# hmm. hmm hmm hmm.
(defmacro try-with-context [name & body]
  ~(try (do ,;body)
    ([err fib]
      (errorf "%s: %s" ,name err))))

# flags: sym -> type description
# lookup: string -> sym
# callbacks: string -> sym
(defn parse-args [args flags lookup refs]
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

(defmacro immediate [doc-string & spec]
  (def spec (parse-specification spec))

  (def syms (spec :declared-order))
  (def gensyms (struct ;(catseq [sym :in syms] [sym (gensym)])))

  (pdb syms)
  (pdb gensyms)

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
    (do
      ,;var-declarations
      (,parse-args
        (,dyn ,*args*)
        ,(quote-flags (spec :flags))
        ,(quote-values (spec :names))
        (struct ,;refs))
      [,;finalizations])))

(pp
  (macex1 '(immediate "hi"
    --something :number "good"
    --other :number)))

(immediate "hi"
    --something :number "good"
    --other (optional :number 10))

(pp something)
(pp other)
