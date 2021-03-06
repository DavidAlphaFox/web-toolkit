(in-package :cl-user)

(defpackage :uri
  (:nicknames :wt.uri)
  (:use :cl :alexandria)
  #+sb-package-locks
  (:lock t)
  (:export
   :uri
   :uri-string
   :uri-scheme
   :uri-userinfo
   :uri-host
   :uri-port
   :uri-path
   :uri-query
   :uri-fragment
   :uri-error)
   (:import-from :utility
                 :define-parser
                 :parse
                 :parser-match-all-p
                 :with-parser-stack
                 :parser-value
                 :.element :.satisfies :.or :.test :.eq :.seq :.seq/s
                 :.any :.any/s :.and :.maybe :.some :.some/s :.end :.not
                 :.n :.n/s :.m :.m/s :.s
                 :.alpha :alpha-p :.digit :digit-p :.hexdig)
   (:import-from :split-sequence
                 :split-sequence))
