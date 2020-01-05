(in-package :uri)

(defgeneric uri-query-alist (uri)
  (:method ((uri uri))
    (let ((query-string (uri-query uri)))
      (let ((pairs (split-sequence #\& query-string)))
        (loop for pair in pairs
           for (name value) = (split-sequence #\= pair)
           for name-decoded = (percent-decode-string name)
           for value-decoded = (percent-decode-string value)
           collect (cons name-decoded (when value value-decoded))))))
  (:method ((uri string))
    (uri-query-alist (uri uri))))

(defgeneric uri-query-plist (uri)
  (:method ((uri uri))
    (loop for (name . value) in (uri-query-alist uri)
       collect name
       collect value))
  (:method ((uri string))
    (uri-query-plist (uri uri))))

(defgeneric uri-query-hash-table (uri)
  (:method ((uri uri))
    (let ((table (make-hash-table :test 'equal)))
      (loop for (name . value) in (uri-query-alist uri)
           do (setf (gethash name table) value))
      table))
  (:method ((uri string))
    (uri-query-hash-table (uri uri))))
