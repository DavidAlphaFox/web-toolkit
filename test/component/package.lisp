(in-package :cl-user)

(defpackage :component-test
  (:nicknames :com-test :wt.component-test :wt.com-test)
  (:use :cl :component :test :alexandria)
  (:shadow :variable)
  (:export :run!))

(in-package :component-test)
(def-suite :component-test)
