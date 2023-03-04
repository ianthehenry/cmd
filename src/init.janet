(use ./util)
(import ./help :prefix "" :export true)
(use ./param-parser)
(use ./arg-parser)
(use ./bridge)

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

(defmacro spec [& s]
  (bake-spec (parse-specification s)))

(def args args)
(def parse parse)
