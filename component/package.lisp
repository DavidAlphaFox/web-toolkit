(in-package :cl-user)

(defpackage :component
  (:nicknames :com :wt.com :wt.component)
  (:use :cl :alexandria :utility)
  (:shadow :variable)
  (:export :id
           :define-component
           :render
           :serialize
           :root
           :children
           :append-child
           :define-variable)
  (:import-from :html
                :append-child
                :constructor
                :construct
                :serialize
                :root
                :children)
  (:import-from :closer-mop
                :allocate-instance
                :validate-superclass
                :class-slots
                :slot-definition-name))
