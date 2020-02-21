;;;; -*- Mode: LISP -*-

(defsystem wt.websocket
  :version "0.0.0"
  :author "Xiangyu He"
  :mailto "xh@coobii.com"
  :depends-on (:wt.http
               :wt.uri
               :alexandria
               :ironclad
               :bordeaux-threads
               :cl-cont
               :closer-mop
               :usocket
               (:feature :sbcl (:require :sb-introspect))
               :cl-base64)
  :defsystem-depends-on (:wt.vendor)
  :serial t
  :components ((:module "websocket"
                        :serial t
                        :components ((:file "package")
                                     (:file "utility")
                                     (:file "handler")
                                     (:file "session")
                                     (:file "endpoint")
                                     (:file "frame")
                                     (:file "connection")
                                     (:file "protocol")
                                     (:file "client"))))
  :in-order-to ((test-op (test-op :wt.websocket/test))))

(defsystem wt.websocket/test
  :depends-on (:wt.websocket
               :wt.json
               :wt.test
               :cl-ppcre
               :split-sequence
               :cl-fad
               :find-port)
  :serial t
  :components ((:module "test"
                        :components ((:module "websocket"
                                              :serial t
                                              :components ((:file "package")
                                                           (:file "helper")
                                                           (:file "autobahn")
                                                           (:file "endpoint")
                                                           (:file "session")
                                                           (:file "websocket"))))))
  :perform (test-op (o c)
                    (symbol-call :test :run! :websocket-test)))
