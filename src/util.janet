(defn fold-map [f g init coll]
  (reduce (fn [acc x] (f acc (g x))) init coll))

(defn hasnt? [dict k]
  (nil? (dict k)))

(defn table/push [t k v]
  (when (hasnt? t k)
    (put t k @[]))
  (array/push (t k) v))

(defn sum-by [f coll]
  (fold-map + f 0 coll))

(defn max-by [f coll]
  (fold-map max f 0 coll))

(defn transpose-dict [dict]
  (def result @{})
  (eachp [k v] dict
    (when (nil? (result v))
      (put result v @[]))
    (array/push (result v) k))
  result)

# TODO: you could imagine a debug mode
# where we preserve the stack frames here...
# actually maybe we should always preserve
# the stack frames, and just throw them away
# when we're using one of the user-facing macros?
# hmm. hmm hmm hmm.
(defmacro try-with-context [name errors & body]
  (with-syms [$err]
    ~(try (do ,;body)
      ([,$err _] (,table/push ,errors ,name ,$err)))))

(defn table/union [left right]
  (eachp [key right-values] right
    (def left-values (left key))
    (if left-values
      (array/concat left-values right-values)
      (put left key right-values))))

(defn has? [p x y]
  (= (p x) y))

(defmacro catseq [& args]
  ~(mapcat |$ (seq ,;args)))

(defn ^ [chars]
  ~(* (not (set ,chars)) 1))

(defmacro pdb [& exprs]
  ~(do
    ,;(seq [expr :in exprs]
        ~(eprintf "%s = %q" ,(string/format "%q" expr) ,expr))))

(defn assertf [pred str & args]
  (assert pred (string/format str ;args)))

(defn type+ [form]
  (let [t (type form)]
    (case t
      :tuple (case (tuple/type form)
        :brackets :tuple-brackets
        :parens :tuple-parens)
      t)))

(defn putf! [table key value str & args]
  (assertf (hasnt? table key) str ;args)
  (put table key value))

(defn put! [table key value]
  (assert (hasnt? table key))
  (put table key value))

(defn set-ref [ref value]
  ((ref :set) value))

(defn get-ref [ref]
  ((ref :get)))

(defn quote-keys [dict]
  ~(struct
    ,;(catseq [[key val] :pairs dict]
      [~',key val])))

(defn quote-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [key ~',val])))

(defn quote-keys-and-values [struct]
  ~(struct
    ,;(catseq [[key val] :pairs struct]
      [~',key ~',val])))
