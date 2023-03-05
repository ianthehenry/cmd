# values shared between the param parser and the arg parser

(use ./util)

(def *spec* (keyword (gensym)))

(defn- builtin-type-parser [token]
  (case token
    :string ["STRING" |$]
    :number ["NUM" (fn [str] (if-let [num (scan-number str)] num (errorf "%s is not a number" str)))]
    (errorf "unknown type %q" token)))

(defn- get-simple-type [parser]
  (cond
    (nil? parser) ["" nil]
    (or (function? parser) (cfunction? parser)) ["_" parser]
    (keyword? parser) (builtin-type-parser parser)
    (and (tuple? parser) (has? length parser 2) (string? (first parser)))
      (let [[arg-name parser] parser]
        (def [_ parser] (get-simple-type parser))
        [arg-name parser])
    (errorf "illegal type declaration %q" parser)))

(defn- get-type [value-handling type]
  (if (and (tuple? type) (all struct? type))
    (if (= value-handling :none)
      type
      (let [[alias-remap type] type]
        [alias-remap
         (tabseq [[k v] :pairs type]
           k
           (if (tuple? v)
             (let [[tag type] v]
              [tag (get-simple-type type)])
             (get-simple-type v)))]))
  (get-simple-type type)))

(defn- quote-handler [handler]
  (-> handler
    (struct/with-proto :type ~(,get-type ,(handler :value) ,(handler :type)))
    (struct/proto-flatten)))

# TODO: this needs a more clear name. what we're doing is
# converting this into a format that can be interpreted.
# as part of this, we'll need to evaluate the parser itself,
# which we do not currently do.
(defn- quote-named-params [params]
  ~(struct
    ,;(catseq [[sym {:handler handler :doc doc}] :pairs params]
      [~',sym {:handler (quote-handler handler)
               :doc doc}])))

(defn- quote-positional-params [params]
  ~[,;(seq [{:sym sym :handler handler} :in params]
      {:handler (quote-handler handler) :sym ~',sym})])

(def unset-sentinel (gensym))

(def unset ~',unset-sentinel)

(defn unset? [x]
  (= x unset-sentinel))

(defn display-name [{:names names :sym sym}]
  (if (or (nil? names) (empty? names))
    (string sym)
    (string/join names "/")))

(defn bake-spec [ctx]
  {:named (quote-named-params (ctx :named-params))
   :names (quote-values (ctx :names))
   :pos (quote-positional-params (ctx :positional-params))
   :doc (ctx :doc)})