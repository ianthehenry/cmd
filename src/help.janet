(use ./util)

# janet has no built-in way to detect the terminal width.
# might be nice to allow the user to set a dynamic variable,
# though...
(def- desired-width 80)

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

(defn- format-arg-string [handler &opt str]
  (def {:value value-handling :type type} handler)
  (if (= value-handling :none)
    nil
    (let [[first second] type]
      (if (string? first)
        first
        (let [sym (first str)
              # [tag [arg-name type]]
              [_ [arg _]] (second sym)]
          arg)))))

(defn- format-param [str handler]
  (def value-handling (handler :value))
  (def arg (format-arg-string handler str))
  (case value-handling
    :required (string str " " arg)
    :none (string "["str"]")
    :optional (string "["str" "arg"]")
    :variadic (string "["str" "arg"]...")
    :greedy (string "["str" "arg"]...")
    :soft-escape (string "["str"]")
    (errorf "BUG: unknown value handling %q" value-handling)))

(defn- print-wrapped [str len]
  (each line (word-wrap str len)
    (print line)))

(defn- lines [str]
  (string/split "\n" str))

(defn blank? [str]
  (all |(= (chr " ") $) str))

(defn parse-docstring [str]
  (if (nil? str)
    [nil nil]
    (let [[summary & detail] (lines str)]
      (def detail (drop-while blank? detail))
      [summary (if (not (empty? detail))
        (string/join detail "\n"))])))

(defn docstring-summary [{:doc str}]
  (or (first (parse-docstring str)) ""))

(defn group [spec]
  # TODO: word wrap
  (def {:doc docstring :commands commands} spec)
  (when docstring
    (print-wrapped docstring desired-width)
    (print))

  (eachp [name command] commands
    (printf "%s - %s" name (docstring-summary command))))

(defn- default-description [param]
  (case ((param :handler) :value)
    :soft-escape "Treat all subsequent arguments as positional"
    "undocumented"
    ))

(defn single [spec]
  (def {:named named-params
        :names param-names
        :pos positional-params
        :doc docstring} spec)

  (def [summary details] (parse-docstring docstring))
  (when summary
    (print-wrapped summary desired-width)
    (print))

  (prin "  " (executable-name))
  (each param positional-params
    (prin " ")
    (prin (format-arg-string (param :handler))))
  (print "\n")

  (when details
    (print-wrapped details desired-width)
    (print))

  (def params-and-names (sorted-by 0 (pairs (transpose-dict param-names))))
  (def named-arg-entries
    (seq [[sym names] :in params-and-names]
      (def param (named-params sym))
      (def names (sorted-by |(string/triml $ "-") names))
      (def formatted-names (map |(format-param $ (param :handler)) names))
      # 2 is the length of the initial "  " and the separator ", "
      (def total-length (sum-by |(+ (length $) 2) formatted-names))
      (def lines (if (<= total-length (/ desired-width 3))
        [(string/join formatted-names ", ")]
        formatted-names))
      [lines (or (param :doc) (default-description param))]))

  (unless (empty? named-arg-entries)
    (print "=== flags ===\n")

    (def left-column-width (max-by |(max-by length (0 $)) named-arg-entries))
    (each [lefts docstring] named-arg-entries
      (def rights (word-wrap docstring (max (/ desired-width 2) (- desired-width left-column-width))))

      (zip-lines lefts rights (fn [first? last? left right]
        (def separator (if first? " : " (if (empty? right) "" "   ")))
        (def pad-to (if (empty? right) 0 left-column-width))
        (print "  " (right-pad left pad-to) separator right)
        )))))
