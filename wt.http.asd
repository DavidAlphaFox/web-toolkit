;;;; -*- Mode: LISP -*-

(defsystem wt.http
  :version "0.0.0"
  :author "Xiangyu He"
  :mailto "xh@coobii.com"
  :depends-on (:wt.uri
               :hunchentoot
               :alexandria
               :closer-mop
               :cl-change-case
               :split-sequence
               :cl-fad
               :trivial-garbage
               :trivial-backtrace
               :drakma)
  :serial t
  :components ((:module "http"
                        :serial t
                        :components ((:file "package")
                                     (:file "util")
                                     (:file "header-field")
                                     (:file "header")
                                     (:file "mime")
                                     (:file "body")
                                     (:file "request")
                                     (:file "status")
                                     (:file "version")
                                     (:file "response")
                                     (:file "reply")
                                     (:file "redirect")
                                     (:file "handler")
                                     (:file "router")
                                     (:file "static")
                                     (:file "websocket")
                                     (:file "listener")
                                     (:file "server")
                                     (:file "client"))))
  :in-order-to ((test-op (test-op :wt.http/test))))

(defsystem wt.http/test
  :depends-on (:wt.http
               :fiveam)
  :serial t
  :components ((:module "test"
                        :components ((:module "http"
                                              :components ((:file "package")
                                                           (:file "static"))))))
  :perform (test-op (o c)
                    (symbol-call :fiveam :run! :http-test)))
