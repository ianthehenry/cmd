# values shared between the param parser and the arg parser

(use ./util)

(def *spec* (keyword (gensym)))

# TODO: this needs a more clear name. what we're doing is
# converting this into a format that can be interpreted.
# as part of this, we'll need to evaluate the parser itself,
# which we do not currently do.
(defn quote-named-params [params]
  ~(struct
    ,;(catseq [[sym {:handler handler :doc doc}] :pairs params]
      [~',sym {:handler (struct/proto-flatten handler)
               :doc doc}])))

(defn quote-positional-params [params]
  ~[,;(seq [{:sym sym :handler handler} :in params]
      {:handler (struct/proto-flatten handler) :sym ~',sym})])

(defn quote-keys [dict]
  ~(struct
    ,;(catseq [[key val] :pairs dict]
      [~',key val])))

(defn quote-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [key ~',val])))

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
