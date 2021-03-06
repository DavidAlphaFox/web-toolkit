(in-package :css)

;; https://drafts.csswg.org/css-sizing-3

(define-property width ()
  ()
  (:value :auto .length .percentage :min-content :max-content))

(define-property height ()
  ()
  (:value :auto .length .percentage :min-content :max-content))

(define-property min-width ()
  ()
  (:value :auto .length .percentage :min-content :max-content))

(define-property min-height ()
  ()
  (:value :auto .length .percentage :min-content :max-content))

(define-property max-width ()
  ()
  (:value :none .length .percentage :min-content :max-content))

(define-property max-height ()
  ()
  (:value :none .length .percentage :min-content :max-content))

(define-property box-sizing ()
  ()
  (:value :content-box :border-box))

(define-property line-height ()
  ()
  (:value :normal number .length .percentage))

;; TODO: vertical-align
;; https://www.w3.org/TR/CSS2/visudet.html#propdef-vertical-align
(define-property vertical-align () ())
