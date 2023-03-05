(declare-project
  :name "cmd"
  :description "Command-line argument parser"
  :author "Ian Henry"
  :license "MIT"
  :url "https://github.com/ianthehenry/cmd"
  :repo "git+https://github.com/ianthehenry/cmd")

(declare-source
  :prefix "cmd"
  :source
    ["src/arg-parser.janet"
      "src/bridge.janet"
      "src/help.janet"
      "src/init.janet"
      "src/param-parser.janet"
      "src/util.janet"])
