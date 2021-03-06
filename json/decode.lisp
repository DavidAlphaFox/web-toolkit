(in-package :json)

(defparameter +json-lisp-symbol-tokens+
  `(("true" . ,true)
    ("null" . ,null)
    ("false" . ,false))
  "Mapping between JSON literal names and Lisp boolean values.")

(defun read-json-token (stream)
  "Read a JSON token (literal name, number or punctuation char) from
the given STREAM, and return 2 values: the token category (a symbol)
and the token itself, as a string or character."
  (let ((c (peek-char nil stream)))
    (case c
      ((#\{ #\[ #\] #\} #\" #\: #\,)
       (values :punct (read-char stream)))
      ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\-)
       (read-json-number-token stream))
      ((#\Space #\Newline #\Return #\Tab) (read-char stream) (read-json-token stream))
      (t (if (alpha-char-p c)
             (read-json-name-token stream)
             (json-syntax-error stream "Invalid char on JSON input: `~C'"
                                c))))))

(defun peek-json-token (stream)
  "Return 2 values: the category and the first character of the next
token available in the given STREAM.  Unlike READ-JSON-TOKEN, this
function can not discriminate between integers and reals (hence, it
returns a single :NUMBER category), and cannot check whether the next
available symbol is a valid boolean or not (hence, the category for
such tokens is :SYMBOL)."
  (let ((c (peek-char nil stream)))
    (values
     (case c
       ((#\{ #\[ #\] #\} #\" #\: #\,) :punct)
       ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\-) :number)
       ((#\Space #\Newline #\Return #\Tab) (read-char stream)
        (return-from peek-json-token
          (peek-json-token stream)))
       (t (if (alpha-char-p c)
              :symbol
              (json-syntax-error stream "Invalid char on JSON input: `~C'"
                                 c))))
     c)))

(defun read-json-number-token (stream)
  "Read a JSON number token from the given STREAM, and return 2
values: the token category (:INTEGER or :REAL) and the token itself,
as a string."
  (let* ((chars (cons nil nil))
         (chars-tail chars)
         (category :integer)
         (c (read-char stream nil)))
    (flet ((next-char ()
             (setf chars-tail (setf (cdr chars-tail) (cons c nil))
                   c (read-char stream nil))))
      (macrolet ((read-part (name divider &rest sign)
                   `(loop for part-length upfrom 0
                       initially
                         ,@(if divider
                               `((if (and c (char-equal c ,divider))
                                     (next-char)
                                     (return))))
                         ,@(if sign
                               (let ((sign
                                      `(or ,@(loop for s in sign
                                                collect `(char= c ,s)))))
                                 `((if (and c ,sign) (next-char)))))
                         ,@(if (eq name 'int)
                               `((when (and c (char= c #\0))
                                   (next-char)
                                   (return))))
                       while (and c (char<= #\0 c #\9))
                       do (next-char)
                       finally
                         ,(let ((error-fmt
                                 (format nil
                                         "Invalid JSON number: no ~:(~A~) digits"
                                         name)))
                            `(if (zerop part-length)
                                 (json-syntax-error stream ,error-fmt)))
                         ,@(unless (eq name 'int)
                             `((setq category :real))))))
        (read-part Int nil #\-)
        (read-part Frac #\.)
        (read-part Exp #\e #\- #\+)
        (if c (unread-char c stream))
        (values category (coerce (cdr chars) 'string))))))

(defun read-json-name-token (stream)
  "Read a JSON literal name token from the given STREAM, and return 2
values: the token category (:BOOLEAN) and the token itself, as a
string."
  (let ((name
         (loop for c = (read-char stream nil)
            while (and c (alpha-char-p c))
            collect c into chars
            finally (if c (unread-char c stream))
              (return (coerce chars 'string)))))
    (if (assoc name +json-lisp-symbol-tokens+ :test #'equal)
        (values :boolean name)
        (json-syntax-error stream "Invalid JSON literal name: ~A"
                           name))))

(define-condition no-char-for-code (error)
  ((offending-code :initarg :code :reader offending-code))
  (:report (lambda (condition stream)
             (format stream "No character corresponds to code #x~4,'0X."
                     (offending-code condition))))
  (:documentation
   "Signalled when, in a JSON String, an escaped code point (\uXXXX)
is encountered which is greater than the application's CHAR-CODE-LIMIT
or for which CODE-CHAR returns NIL."))

(defmacro escaped-char-dispatch (char &key code-handler default-handler)
  "Compiles the escaped character alist to a (CASE ...) match expression."
  `(case ,char
     ,@(loop for (c . unescaped) in +json-lisp-escaped-chars+
          if (characterp unescaped)
          collect (list c unescaped)
          else if (consp unescaped)
          collect
            (destructuring-bind ((len rdx) &body body) code-handler
              (destructuring-bind (len-v . rdx-v) unescaped
                `(,c (let ((,len ,len-v) (,rdx ,rdx-v)) ,@body)))))
     (t ,default-handler)))

(defun read-json-string-char (stream)
  "Read a JSON String char (or escape sequence) from the STREAM and
return it.  If an end of string (unescaped quote) is encountered,
return NIL."
  (let ((esc-error-fmt "Invalid JSON character escape sequence: ~A~A")
        (c (read-char stream)))
    (case c
      (#\" nil)                         ; End of string
      ((or #\Newline #\Linefeed #\Tab #\Page #\Null)
       (json-syntax-error stream
                          (format nil "Unescaped character ~S" c)))
      (#\\ (let ((c (read-char stream)))
             (escaped-char-dispatch
              c
              :code-handler
              ((len rdx)
               (let ((code
                      (let ((repr (make-string len)))
                        (dotimes (i len)
                          (setf (aref repr i) (read-char stream)))
                        (handler-case (parse-integer repr :radix rdx)
                          (parse-error ()
                            (json-syntax-error stream esc-error-fmt
                                               (format nil "\\~C" c)
                                               repr))))))
                 (restart-case
                     (or (and (< code char-code-limit) (code-char code))
                         (error 'no-char-for-code :code code))
                   (substitute-char (char)
                     :report "Substitute another char."
                     :interactive
                     (lambda ()
                       (format *query-io* "Char: ")
                       (list (read-char *query-io*)))
                     char)
                   (pass-code ()
                     :report "Pass the code to char handler."
                     code))))
              :default-handler
              (if *use-strict-json-rules*
                  (json-syntax-error stream esc-error-fmt "\\" c)
                  c))))
      (t c))))

(defvar *json-input* (make-synonym-stream '*standard-input*)
  "The default input stream for decoding operations.")

(define-custom-var (:integer *integer-handler*) (constantly 0)
  "Designator for a function of 1 string argument (integer token).")
(define-custom-var (:real *real-handler*) (constantly 0)
  "Designator for a function of 1 string argument (real token).")
(define-custom-var (:boolean *boolean-handler*) (constantly t)
  "Designator for a function of 1 string argument (boolean token).")

(define-custom-var (:beginning-of-string *beginning-of-string-handler*)
    (constantly t)
  "Designator for a function of no arguments (called at encountering
an opening quote for a String).")
(define-custom-var (:string-char *string-char-handler*) (constantly t)
  "Designator for a function of 1 character argument (String char).")
(define-custom-var (:end-of-string *end-of-string-handler*) (constantly "")
  "Designator for a function of no arguments (called at encountering
a closing quote for a String).")

(define-custom-var (:beginning-of-array *beginning-of-array-handler*)
    (constantly t)
  "Designator for a function of no arguments (called at encountering
an opening bracket for an Array).")
(define-custom-var (:array-member *array-member-handler*) (constantly t)
  "Designator for a function of 1 arbitrary argument (decoded member
of Array).")
(define-custom-var (:end-of-array *end-of-array-handler*) (constantly nil)
  "Designator for a function of no arguments (called at encountering
a closing bracket for an Array).")

(define-custom-var (:array-type *json-array-type*) 'vector
  "The Lisp sequence type to which JSON Arrays are to be coerced.")

(define-custom-var (:beginning-of-object *beginning-of-object-handler*)
    (constantly t)
  "Designator for a function of no arguments (called at encountering
an opening brace for an Object).")
(define-custom-var (:object-key *object-key-handler*) (constantly t)
  "Designator for a function of 1 string argument (decoded member key
of Object).")
(define-custom-var (:object-value *object-value-handler*) (constantly t)
  "Designator for a function of 1 arbitrary argument (decoded member
value of Object).")
(define-custom-var (:end-of-object *end-of-object-handler*)
    (constantly nil)
  "Designator for a function of no arguments (called at encountering
a closing brace for an Object).")

(define-custom-var (:internal-decoder *internal-decoder*) 'decode-json
  "Designator for a function of 1 stream argument called (instead of
DECODE-JSON) to decode a member of an Array or of an Object.")

(define-custom-var (:object-scope *object-scope-variables*)
    '(*internal-decoder*)
  "A list of symbols naming dynamic variables which should be re-bound
in the scope of every JSON Object.")
(define-custom-var (:array-scope *array-scope-variables*)
    '(*internal-decoder*)
  "A list of symbols naming dynamic variables which should be re-bound
in the scope of every JSON Array.")
(define-custom-var (:string-scope *string-scope-variables*)
    nil
  "A list of symbols naming dynamic variables which should be re-bound
in the scope of every JSON String.")
(define-custom-var (:aggregate-scope *aggregate-scope-variables*)
    nil
  "A list of symbols naming dynamic variables which should be re-bound
in the scope of every JSON aggregate value (Object, Array or String).")

(defvar *decode-depth* 0)

(defvar *max-decode-depth* 20)

(defun decode-json-from-stream-0 (&optional (stream *json-input*))
  (multiple-value-bind (dispatch-token-type dispatch-token)
      (read-json-token stream)
    (ecase dispatch-token-type
      (:punct
       (case dispatch-token
         (#\" (decode-json-string stream))
         (#\[ (let ((*decode-depth* (1+ *decode-depth*)))
                (decode-json-array stream)))
         (#\{ (let ((*decode-depth* (1+ *decode-depth*)))
                (decode-json-object stream)))
         (t (json-syntax-error stream
                               "Token out of place on JSON input: `~C'"
                               dispatch-token))))
      (:integer (funcall *integer-handler* dispatch-token))
      (:real (funcall *real-handler* dispatch-token))
      (:boolean (funcall *boolean-handler* dispatch-token)))))

(defun decode-json-from-stream (stream &key strict junked-allowed)
  (when strict
    (assert (member (peek-char t stream) '(#\{ #\[))))
  (prog1
      (decode-json-from-stream-0 stream)
    (unless junked-allowed
      (tagbody :check-junk
         (let ((c (peek-char nil stream nil nil)))
           (case c
             ((nil))
             ((#\Space #\Newline #\Return #\Tab) (read-char stream) (go :check-junk))
             (t (json-syntax-error stream "Invalid char on JSON input: `~C'" c))))))))

(defun decode-json-from-source (source &key strict junked-allowed)
  (etypecase source
    (pathname
     (with-open-file (stream source)
       (decode-json-from-stream stream
                                :strict strict
                                :junked-allowed junked-allowed)))
    (string
     (with-input-from-string (stream source)
       (decode-json-from-stream stream
                                :strict strict
                                :junked-allowed junked-allowed)))
    (stream
     (decode-json-from-stream source
                              :strict strict
                              :junked-allowed junked-allowed))))

(defmacro aggregate-scope-progv (variables &body body)
  "Establish a dynamic environment where all VARIABLES are freshly
bound (to their current values), and execute BODY in it, returning the
result."
  `(progv ,variables (mapcar #'symbol-value ,variables)
     ,@body))

(defun decode-json-array (stream)
  "Read comma-separated sequence of JSON Values until a closing bracket,
calling array handlers as it goes."
  (when (> *decode-depth* *max-decode-depth*)
    (error "Exceeding depth limit, give up"))
  (aggregate-scope-progv *array-scope-variables*
    (aggregate-scope-progv *aggregate-scope-variables*
      (funcall *beginning-of-array-handler*)
      (multiple-value-bind (type token) (peek-json-token stream)
        (if (and (eql type :punct) (char= token #\]))
            (progn
              (read-json-token stream)
              (return-from decode-json-array
                (funcall *end-of-array-handler*)))
            (funcall *array-member-handler*
                     (funcall *internal-decoder* stream))))
      (loop
         (multiple-value-bind (type token) (read-json-token stream)
           (if (eql type :punct)
               (case token
                 (#\] (return-from decode-json-array
                        (funcall *end-of-array-handler*)))
                 (#\, (setq token nil))))
           (if token
               (json-syntax-error
                stream
                "Token out of place in Array on JSON input: `~A'"
                token)))
         (funcall *array-member-handler*
                  (funcall *internal-decoder* stream))))))

(defun decode-json-object (stream)
  "Read comma-separated sequence of JSON String:Value pairs until a
closing brace, calling object handlers as it goes."
  (when (> *decode-depth* *max-decode-depth*)
    (error "Exceeding depth limit, give up"))
  (aggregate-scope-progv *object-scope-variables*
    (aggregate-scope-progv *aggregate-scope-variables*
      (loop with key = nil and expect-key = t
         for first-time-p = t then nil
         initially (funcall *beginning-of-object-handler*)
         do (multiple-value-bind (type token) (read-json-token stream)
              (if (eql type :punct)
                  (case token
                    (#\}
                     (if first-time-p
                         (return-from decode-json-object
                           (funcall *end-of-object-handler*))))
                    (#\"
                     (setq key (decode-json-string stream)
                           expect-key nil))))
              (if expect-key
                  (json-syntax-error
                   stream
                   "Expected a key String in Object on JSON input ~
                    but found `~A'"
                   token)
                  (funcall *object-key-handler* key)))
           (multiple-value-bind (type token) (read-json-token stream)
             (unless (and (eql type :punct) (char= token #\:))
               (json-syntax-error
                stream
                "Expected a `:' separator in Object on JSON input ~
                 but found `~A'"
                token)))
           (funcall *object-value-handler*
                    (funcall *internal-decoder* stream))
           (multiple-value-bind (type token) (read-json-token stream)
             (if (eql type :punct)
                 (case token
                   (#\} (return-from decode-json-object
                          (funcall *end-of-object-handler*)))
                   (#\, (setq key nil expect-key t))))
             (if (not expect-key)
                 (json-syntax-error
                  stream
                  "Expected a `,' separator or `}' in Object on JSON ~
                   input but found `~A'"
                  token)))))))

(defun decode-json-string (stream)
  "Read JSON String characters / escape sequences until a closing
double quote, calling string handlers as it goes."
  (aggregate-scope-progv *string-scope-variables*
    (aggregate-scope-progv *aggregate-scope-variables*
      (handler-bind ((no-char-for-code (lambda (c)
                                         (declare (ignore c))
                                         (invoke-restart 'substitute-char #\?))))
        (loop initially (funcall *beginning-of-string-handler*)
           for c = (read-json-string-char stream)
           while c
           do (funcall *string-char-handler* c)
           finally (return (funcall *end-of-string-handler*)))))))

;;; handling numerical read errors in ACL
#+allegro
(defun allegro-read-numerical-overflow-p (condition)
  (and (typep condition 'simple-error)
       (search "is too large to be converted"
               (slot-value condition 'excl::format-control))))

#+allegro
(deftype allegro-reader-numerical-overflow ()
  `(and error (satisfies allegro-read-numerical-overflow-p)))


;;; The default semantics

(defun parse-number (token)
  "Take a number token and convert it to a numeric value."
  ;; We can be reasonably sure that nothing but well-formed (both in
  ;; JSON and Lisp sense) number literals get to this point.
  (flet ((floatify (x)
           (float x
                  (ecase *read-default-float-format*
                    (short-float 1.0s0)
                    (single-float 1.0)
                    (double-float 1.0d0)
                    (long-float 1.0l0)))))
    (let* ((negated (char-equal #\- (aref token 0)))
           (token (string-left-trim '(#\-) token)))
      (let ((f-marker (position #\. token :test #'char-equal))
            (e-marker (position #\e token :test #'char-equal)))
        (if (or e-marker f-marker)
            (let* ((int-part
                    (subseq token 0 (or f-marker e-marker)))
                   (frac-part
                    (if f-marker
                        (subseq token (1+ f-marker) e-marker)
                        "0"))
                   (significand
                    (+ (parse-integer int-part)
                       (* (parse-integer frac-part)
                          (expt 10 (- (length frac-part))))))
                   (exponent
                    (if e-marker
                        (parse-integer (subseq token (1+ e-marker)))
                        0)))
              (restart-case
                  ;; FIXME: the below have to be double-float when that's the value of
                  ;; *read-default-float-format*: short-float, single-float, double-float, long-float
                  (let ((value
                         (* (floatify significand) (expt 10 (floatify exponent)))))
                    (if negated
                        (- value)
                        value))
                (bignumber-string (&optional (prefix "BIGNUMBER:"))
                  :report "Return the number token prefixed as big number."
                  (concatenate 'string (if negated "-" "") prefix token))
                (rational-approximation ()
                  :report "Use rational instead of float."
                  (let ((rat
                         (* significand (expt 10 exponent))))
                    (if negated (- rat) rat)))
                (placeholder (value)
                  :report "Return a user-supplied placeholder value."
                  value)))
            (let ((int (parse-integer token)))
              (if negated (- int) int)))))))

(defun json-boolean-to-lisp (token)
  "Take a literal name token and convert it to a boolean value."
  ;; We can be reasonably sure that nothing but well-formed boolean
  ;; literals get to this point.
  (cdr (assoc token +json-lisp-symbol-tokens+ :test #'string=)))

(defvar *accumulator* nil
  "List or vector where elements are stored.")
(defvar *accumulator-last* nil
  "If *ACCUMULATOR* is a list, this refers to its last cons.")

(defun init-accumulator ()
  "Initialize a list accumulator."
  (let ((head (cons nil nil)))
    (setq *accumulator* head)
    (setq *accumulator-last* head)))

(defun accumulator-add (element)
  "Add ELEMENT to the end of the list accumulator."
  (setq *accumulator-last*
        (setf (cdr *accumulator-last*) (cons element nil))))

(defun accumulator-add-key (key)
  "Add a cons whose CAR is KEY to the end of the list accumulator."
  (setq *accumulator-last*
        (setf (cdr *accumulator-last*) (cons (cons key nil) nil))))

(defun accumulator-add-value (value)
  "Set the CDR of the most recently accumulated cons to VALUE."
  (setf (cdar *accumulator-last*) value)
  *accumulator-last*)

(defun accumulator-get-sequence ()
  "Return all values accumulated so far in the list accumulator as
*JSON-ARRAY-TYPE*."
  (make-instance 'array :value (coerce (cdr *accumulator*) *json-array-type*)))

(defun accumulator-get-string ()
  "Return all values accumulated so far in the list accumulator as
*JSON-ARRAY-TYPE*."
  (coerce (cdr *accumulator*) 'string))

(defun accumulator-get ()
  "Return all values accumulated so far in the list accumulator as a
list."
  (cdr *accumulator*))

(defun accumulator-get-object ()
  "Return a CLOS object, using keys and values accumulated so far in
the list accumulator as slot names and values, respectively. Create a OBJECT with slots interned in *JSON-SYMBOLS-PACKAGE*."
  (let ((bindings (cdr *accumulator*)))
    (make-instance 'object :pairs bindings)))

(defun init-string-stream-accumulator ()
  "Initialize a string-stream accumulator."
  (setq *accumulator* (make-string-output-stream)))

(defun string-stream-accumulator-add (char)
  "Add CHAR to the end of the string-stream accumulator."
  (write-char char *accumulator*)
  *accumulator*)

(defun string-stream-accumulator-get ()
  "Return all characters accumulated so far in a string-stream
accumulator and close the stream."
  (prog1 (get-output-stream-string *accumulator*)
    (close *accumulator*)))

(defun set-decoder-semantics ()
  "Set the decoder semantics to the following:
  * Strings and Numbers are decoded naturally, reals becoming floats.
  * The literal name true is decoded to T, false and null to NIL.
  * Arrays are decoded to sequences of the type *JSON-ARRAY-TYPE*.
  * Objects are decoded to alists.  Object keys are converted by the
function *JSON-IDENTIFIER-NAME-TO-LISP* and then interned in the
package *JSON-SYMBOLS-PACKAGE*."
  (set-custom-vars
   :integer #'parse-number
   :real #'parse-number
   :boolean #'json-boolean-to-lisp
   :beginning-of-array #'init-accumulator
   :array-member #'accumulator-add
   :end-of-array #'accumulator-get-sequence
   :array-type 'list
   :beginning-of-object #'init-accumulator
   :object-key #'accumulator-add-key
   :object-value #'accumulator-add-value
   :end-of-object #'accumulator-get-object
   :beginning-of-string #'init-string-stream-accumulator
   :string-char #'string-stream-accumulator-add
   :end-of-string #'string-stream-accumulator-get
   :aggregate-scope (union *aggregate-scope-variables*
                           '(*accumulator* *accumulator-last*))
   :internal-decoder #'decode-json-from-stream-0))

(defmacro with-decoder-semantics (&body body)
  "Execute BODY in a dynamic environement where the decoder semantics
is such as set by SET-DECODER-SEMANTICS."
  `(with-shadowed-custom-vars
     (set-decoder-semantics)
     ,@body))

(set-decoder-semantics)

(defun decode (source &key strict junked-allowed)
  (typecase source
    ((or string pathname stream) (decode-json-from-source
                                  source
                                  :strict strict
                                  :junked-allowed junked-allowed))
    (cl:null nil)
    (t (error "unknown source"))))
