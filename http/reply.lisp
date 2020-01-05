(in-package :http)

(defun add-header-field (header header-field)
  (if-let ((header-field-0 (find-header-field header (header-field-name header-field))))
    (setf (header-field-value header-field-0)
          (header-field-value header-field))
    (appendf (header-fields header) (list header-field))))

(defmacro reply (&rest forms)
  (with-gensyms (object header-field)
    `(let ((*response* (or *response* (make-instance 'response))))
       ,@(loop for form in forms
            collect
              `(let ((,object ,form))
                 (typecase ,object
                   (status (setf (response-status *response*) ,object))
                   (header-field (add-header-field (response-header *response*)
                                                   ,object))
                   (header (loop for ,header-field in (header-fields ,object)
                              do (add-header-field (response-header *response*)
                                                   ,header-field)))
                   (t (setf (response-body *response*) ,object)))))
       *response*)))

(defgeneric reply-object (object response))

(defmethod reply-object ((status status) (response response))
  (setf (response-status response) status))

(defmethod reply-object ((header-field header-field) (response response))
  (add-header-field (response-header response) header-field))

(defmethod reply-object ((header header) (response response))
  (loop for header-field in (header-fields header)
     do (add-header-field (response-header response) header-field)))

(defmethod reply-object (object (response response))
  (setf (response-body response) object))