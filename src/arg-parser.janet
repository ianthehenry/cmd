# runtime parser for actual arguments

(use ./util)
(use ./bridge)
(use ./help)

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
      :variadic+ nil
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
    (match ((param :handler) :value)
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
      (handling (or (= handling :variadic) (= handling :variadic+)))
        (while (> num-variadic-args 0)
          (assign param (take-arg))
          (-- num-variadic-args))
      :greedy nil
      _ (assert false)))

  (when (< arg-index num-args)
    (table/push errors "" (string/format "unexpected argument %s" (args arg-index))))
  errors)

# this is the absolute worst kind of macro
(defmacro- consume [name expr]
  ~(let [{:update handle :type t} handler]
    (try-with-context ,name errors
      (set-ref ref (handle t (if (string? ,name) ,name) (get-ref ref) ,expr)))))

# args: [string]
# spec:
#   named: sym -> param
#   names: string -> sym
#   pos: [param]
# refs: sym -> ref
(defn- parse-args [args {:named named-params :names param-names :pos positional-params} refs]
  (var i 0)
  (def errors @{})
  (def positional-args @[])
  (var soft-escaped? false)

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
    (if (positional? arg)
      (if (and positional-hard-escape-param (final-positional?))
        (let [{:sym sym :handler handler} positional-hard-escape-param
               ref (assert (refs sym))]
          (consume sym arg)
          (while (< i (length args)) (consume sym (next-arg))))
        (array/push positional-args arg))
      (let [sym (param-names arg)]
        # TODO: nice error message for negative number
        (if (nil? sym)
          (table/push errors arg "unknown parameter")
          (let [{:handler handler} (assert (named-params sym))
                {:value value-handling} handler]
            (if (= value-handling :soft-escape)
              (set soft-escaped? true)
              (let [takes-value? (not= value-handling :none)
                    ref (assert (refs sym))]
                (case value-handling
                  :none (consume arg nil)
                  :greedy (while (< i (length args)) (consume arg (next-arg)))
                  (consume arg (next-arg))))))))))
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

(defn args [] (normalize-args (drop 1 (dyn *args*))))

(defn- print-parse-errors [err-table]
  (if-let [ctxless-errors (err-table "")]
    (each err ctxless-errors
      (eprint err))
    (loop [[context errs] :pairs err-table :when (not= context "")]
      (eprintf "%s: %s" context (first errs)))))

(defn assignment [spec baked-spec args]
  (def params (spec :params))
  (def all-syms (seq [sym :keys params :when (not= (((params sym) :handler) :value) :soft-escape)] sym))
  (def {true private-syms false public-syms} (group-by |(truthy? (((params $) :handler) :symless)) all-syms))
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
      (let [,$spec ,(or baked-spec (bake-spec spec))] (with-dyns [,*spec* ,$spec]
        ,;var-declarations
        (def ,$errors (,parse-args
          ,args
          ,$spec
          (,struct ,;refs)))
        ,;(finalizations-of private-syms)
        (def ,$results [,;(finalizations-of public-syms)])
        (unless (,empty? ,$errors)
          (,print-parse-errors ,$errors)
          (,os/exit 1))
        ,$results)))))

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
    (if (empty? errors)
      result
      (error errors))))
