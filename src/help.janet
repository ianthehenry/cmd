(use ./util)

(defn- right-pad [str len]
  (string str (string/repeat " " (max 0 (- len (length str))))))

(defn- word-wrap-line [line len]
  (def lines @[])
  (var current-line @"")
  (each word (string/split " " line)
    (when (and (not (empty? current-line))
             (>= (+ (length current-line) 1 (length word)) len))
      (array/push lines current-line)
      (set current-line @""))
    (when (not (empty? current-line))
      (buffer/push-string current-line " "))
    (buffer/push-string current-line word))
  (array/push lines current-line)
  lines)

(defn- word-wrap [str len]
  (mapcat |(word-wrap-line $ len) (string/split "\n" str)))

(defn- zip-lines [lefts rights f]
  (def end (max (length lefts) (length rights)))
  (def last-i (- end 1))
  (for i 0 end
    (f (= i 0) (= i last-i) (get lefts i "") (get rights i ""))))

(defn- executable-name []
  (if (is-probably-interpreter?)
    (or (first (dyn *args*)) (dyn *executable*))
      (dyn *executable*)))

(defn- format-param [str handler]
  (def value-handling (handler :value))

  # for a simple type:

  (def arg (if (= value-handling :none)
    nil
    (let [[first second] (handler :type)]
      (if (string? first)
        first
        (let [sym (first str)
              # [tag [arg-name type]]
              [_ [arg _]] (second sym)]
          arg)))))

  (case value-handling
    :required (string str " " arg)
    :none (string "["str"]")
    :optional (string "["str" "arg"]")
    :variadic (string "["str" "arg"]...")
    :greedy (string "["str" "arg"]...")
    (errorf "BUG: unknown value handling %q" value-handling)))

(defn print-help [spec]
  (def {:named named-params
        :names param-names
        :pos positional-params
        :doc doc-string} spec)

  (when doc-string
    (print doc-string)
    (print))

  (prin "  " (executable-name))
  (each param positional-params
    (prin " ")
    # TODO: should we show the type annotation instead, and reserve
    # the doc for elsewhere?
    (def name (or (param :doc) (string/ascii-upper (param :sym))))
    (prin (format-param name (param :handler))))
  (print "\n")

  (def params-and-names (sorted-by 0 (pairs (transpose-dict param-names))))
  (def named-arg-entries
    (seq [[sym names] :in params-and-names]
      (def param (named-params sym))
      (def names (sorted-by |(string/triml $ "-") names))
      (def formatted-names (map |(format-param $ (param :handler)) names))
      # 2 is the length of the initial "  " and the separator ", "
      (def total-length (sum-by |(+ (length $) 2) formatted-names))
      (def lines (if (<= total-length 30)
        [(string/join formatted-names ", ")]
        formatted-names))
      [lines (or (param :doc) "undocumented")]))

  (unless (empty? named-arg-entries)
    (print "=== flags ===\n")

    (def left-column-width (max-by |(max-by length (0 $)) named-arg-entries))
    (each [lefts docstring] named-arg-entries
      (def rights (word-wrap docstring (max 40 (- 80 left-column-width))))

      (zip-lines lefts rights (fn [first? last? left right]
        (def separator (if first? " : " (if (empty? right) "" "   ")))
        (def pad-to (if (empty? right) 0 left-column-width))
        (print "  " (right-pad left pad-to) separator right)
        )))))
