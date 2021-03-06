;;;; -*- Mode: LISP -*-

(defsystem wt.dom
  :author "Xiangyu He"
  :mailto "xh@coobii.com"
  :license "BSD 3-Clause"
  :depends-on (:alexandria
               :split-sequence)
  :defsystem-depends-on (:wt.vendor)
  :components ((:module "dom"
                :serial t
                :components ((:file "package")
                             (:file "tree")
                             (:file "mixin")
                             (:file "node")
                             (:file "document")
                             (:file "element")
                             (:file "attribute")
                             (:file "text")
                             (:file "traversal"))))
  :in-order-to ((test-op (test-op :wt.dom/test)))
  :perform (load-op :after (o c)
             #+lispworks
             (pushnew :dom hcl:*packages-for-warn-on-redefinition*)))

(defsystem wt.dom/test
  :depends-on (:wt.dom
               :wt.test)
  :components ((:module "test/dom"
                :serial t
                :components ((:file "package")
                             (:file "helper")
                             (:file "node")
                             (:file "traversal")
                             (:file "element"))))
  :perform (test-op (o c)
             (symbol-call :test :run! :dom-test)))
