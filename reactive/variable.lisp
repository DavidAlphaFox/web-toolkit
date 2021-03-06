(in-package :reactive)

(define-reactive-class variable ()
  ((name
    :initarg :name
    :initform nil
    :reader variable-name)
   (form
    :initarg :form
    :initform nil
    :accessor variable-form)
   (value
    :initarg :value
    :initform nil
    :reader variable-value)))

(defun variable (symbol)
  (symbol-value (intern (format nil "V/~A" (symbol-name symbol)))))

;; TODO: better error report
(defmethod (setf variable-form) (form (variable variable))
  (let ((current-form (slot-value variable 'form))
        (current-value (slot-value variable 'value))
        (target-form form))
    ;; (format t "Set form of ~A from ~A to ~A~%" variable current-form target-form)
    (without-propagation
      (setf (slot-value variable 'form) target-form))
    (handler-bind ((error (lambda (e)
                            (declare (ignore e))
                            (without-propagation
                              (setf (slot-value variable 'form) current-form
                                    (slot-value variable 'value) current-value)))))
      (reify variable))))

(defmethod react ((variable variable) object)
  (reify variable))

(defvar *variable* nil)

(defvar *variable-dependency* nil)

(defmacro with-variable-capturing ((object) &body body)
  `(let ((*variable* ,object)
         (*variable-dependency* nil))
     (prog1
         (progn ,@body)
       (loop for v in *variable-dependency*
          do (add-dependency *variable* v)))))

(defun reify (variable)
  (let ((value (with-variable-capturing (variable)
                 (eval (variable-form variable)))))
    ;; (when (typep value 'reactive-object)
    ;;   (add-dependency variable value))
    (with-propagation
      (setf (slot-value variable 'value) value))))

(defmethod initialize-instance :after ((variable variable) &key)
  (reify variable))

(defmethod print-object ((variable variable) stream)
  (print-unreadable-object (variable stream :type t :identity t)
    (format stream "~A" (variable-name variable))))

(defmacro define-variable (name form)
  (let ((vname (intern (format nil "V/~A" name))))
    `(progn
       (defvar ,vname (make-instance 'variable
                                     :name ',name
                                     :form ',form))
       (eval-when (:compile-toplevel :load-toplevel :execute)
         ;; TODO: check if `name` is already global variable
         (define-symbol-macro ,name (prog1
                                        (variable-value ,vname)
                                      (when *variable*
                                        (push ,vname *variable-dependency*)))))
       (eval-when (:load-toplevel :execute)
         (without-propagation
           (setf (variable-form ,vname) ',form))))))
