(in-package :html)

(defvar *insertion-modes*
  '(initial
    before-html
    before-head
    in-head
    in-head-noscript
    after-head
    in-body
    text
    in-table
    in-table-text
    in-caption
    in-column-group
    in-table-body
    in-row
    in-cell
    in-select
    in-select-in-table
    in-template
    after-body
    in-frameset
    after-frameset
    after-after-body
    after-after-frameset))

(defmacro define-parser-insertion-mode (name &body body)
  (let ((function-name (intern (format nil "PROCESS-TOKEN-IN-~A-INSERTION-MODE" name))))
    `(defun ,function-name (parser)
       ,@(unless body '((declare (ignore parser))))
       (symbol-macrolet ((token (slot-value parser 'current-token))
                         (next-token nil)
                         (document (slot-value parser 'document))
                         (stack-of-open-elements (slot-value parser 'stack-of-open-elements))
                         (stack-of-template-insertion-modes (slot-value parser 'stack-of-template-insertion-modes))
                         (adjusted-current-node (adjusted-current-node parser))
                         (head-element-pointer (slot-value parser 'head-element-pointer))
                         (current-node (first (slot-value parser 'stack-of-open-elements)))
                         (insertion-mode (slot-value parser 'insertion-mode))
                         (original-insertion-mode (slot-value parser 'original-insertion-mode)))
         (macrolet ((switch-to (insertion-mode)
                      `(progn
                         (format t "~A -> ~A~%"
                                 (slot-value parser 'insertion-mode)
                                 ,insertion-mode)
                         (setf (slot-value parser 'insertion-mode) ,insertion-mode)))
                    (parse-error (message)))
           (flet (,@(loop for insertion-mode in *insertion-modes*
                      collect `(,(intern (format nil "PROCESS-TOKEN-IN-~A-INSERTION-MODE" insertion-mode))
                                ()
                                (,(intern (format nil "PROCESS-TOKEN-IN-~A-INSERTION-MODE" insertion-mode)) parser)))
                  (ignore-token ())
                  (stop-parsing ())
                  (reprocess-current-token ()
                    (tree-construction-dispatcher parser (slot-value parser 'current-token)))
                  (insert-comment (&optional position)
                    (declare (ignore position)))
                  (insert-character ()
                    (insert-character parser (slot-value parser 'current-token)))
                  (create-element (token)
                    (create-element-for-token token "html"))
                  (a-start-tag-whose-tag-name-is (name)
                    (let ((token (slot-value parser 'current-token)))
                      (and (typep token 'start-tag)
                           (equal name (slot-value token 'tag-name)))))
                  (a-start-tag-whose-tag-name-is-one-of (names)
                    (let ((token (slot-value parser 'current-token)))
                      (and (typep token 'start-tag)
                           (member (slot-value token 'tag-name) names :test 'equal))))
                  (an-end-tag-whose-tag-name-is (name)
                    (let ((token (slot-value parser 'current-token)))
                      (and (typep token 'end-tag)
                           (equal name (slot-value token 'tag-name)))))
                  (an-end-tag-whose-tag-name-is-one-of (names)
                    (let ((token (slot-value parser 'current-token)))
                      (and (typep token 'end-tag)
                           (member (slot-value token 'tag-name) names :test 'equal))))
                  (insert-html-element-for-token (&optional token)
                    (unless token
                      (setf token (slot-value parser 'current-token)))
                    (insert-html-element parser token))
                  (acknowledge-token-self-closing-flag ())
                  (reconstruct-active-formatting-elements ()
                    (reconstruct-active-formatting-elements parser))
                  (have-element-in-scope-p (tag-name))
                  (have-element-for-button-scope-p (tag-name))
                  (close-p-element ())
                  (parse-generic-rcdata-element ()
                    (parse-generic-rcdata-element parser)))
             ,@(if body
                   body
                 `((error "Parser ~A not implemented" ',name)))))))))

(define-parser-insertion-mode initial
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token))
    (ignore-token))
   
   ((typep token 'comment-token)
    (insert-comment))
   
   ((typep token 'doctype-token)
    ;; ...
    (switch-to 'before-html))

   (t
    ;; ...
    (switch-to 'before-html)
    (reprocess-current-token))))

(define-parser-insertion-mode before-html
  (cond
   ((typep token 'doctype-token)
    (parse-error "..."))

   ((typep token 'comment-token)
    (insert-comment))

   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token))
    (ignore-token))
    
   ((a-start-tag-whose-tag-name-is "html")
    (let ((element (create-element token)))
      (dom:append-child document element)
      (push element stack-of-open-elements))
    (switch-to 'before-head))
    
   ((an-end-tag-whose-tag-name-is-one-of '("head" "body" "html" "br"))
    ;; Same as T
    (let ((element (make-instance 'element :tag-name "html")))
      (dom:append-child document element)
      (push element stack-of-open-elements))
    (switch-to 'before-head))
    
   ((typep token 'end-tag)
    (parse-error "..."))
    
   (t
    (let ((element (make-instance 'element :tag-name "html")))
      (dom:append-child document element)
      (push element stack-of-open-elements))
    (switch-to 'before-head)
    (reprocess-current-token))))

(define-parser-insertion-mode before-head
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token))
    (ignore-token))
   
   ((typep token 'comment-token)
    (insert-comment))
   
   ((typep token 'doctype-token)
    (parse-error "...")
    (ignore-token))
   
   ((a-start-tag-whose-tag-name-is "html")
    (process-token-in-in-body-insertion-mode))

   ((a-start-tag-whose-tag-name-is "head")
    (let ((head (insert-html-element-for-token)))
      (setf head-element-pointer head)
      (switch-to 'in-head)))

   ((an-end-tag-whose-tag-name-is-one-of '("head" "body" "html" "br"))
    ;; Same as T
    (let ((head (insert-html-element-for-token (make-instance 'start-tag :tag-name "head"))))
      (setf head-element-pointer head))
    (switch-to 'in-head)
    (reprocess-current-token))
   
   ((typep token 'end-tag)
    (parse-error "...")
    (ignore-token))
   
   (t
    (let ((head (insert-html-element-for-token (make-instance 'start-tag :tag-name "head"))))
      (setf head-element-pointer head))
    (switch-to 'in-head)
    (reprocess-current-token))))

(define-parser-insertion-mode in-head
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token))
    (insert-character))
   
   ((typep token 'comment-token)
    (insert-comment))
   
   ((typep token 'doctype-token)
    (parse-error "...")
    (ignore-token))
   
   ((a-start-tag-whose-tag-name-is "html")
    (process-token-in-in-body-insertion-mode))
   
   ((a-start-tag-whose-tag-name-is-one-of '("base" "basefont" "bgsound" "link"))
    (let ((element (insert-html-element-for-token)))
      (pop stack-of-open-elements))
    (acknowledge-token-self-closing-flag))
   
   ((a-start-tag-whose-tag-name-is "meta")
    (let ((element (insert-html-element-for-token)))
      (pop stack-of-open-elements)
      (acknowledge-token-self-closing-flag)
      #|Handle encoding changing|#))

   ((a-start-tag-whose-tag-name-is "title")
    (parse-generic-rcdata-element))

   ;; TODO
   ((or (a-start-tag-whose-tag-name-is "noscript")
        (a-start-tag-whose-tag-name-is-one-of '("noframes" "style"))))
   
   ((a-start-tag-whose-tag-name-is "noscript")
    (insert-html-element-for-token)
    (switch-to 'in-head-noscript))

   ;; TODO
   ((a-start-tag-whose-tag-name-is "script"))

   ((an-end-tag-whose-tag-name-is "head")
    (pop stack-of-open-elements)
    (switch-to 'after-head))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "html" "br"))
    ;; Same as T
    (pop stack-of-open-elements)
    (switch-to 'after-head)
    (reprocess-current-token))

   ;; TODO
   ((a-start-tag-whose-tag-name-is "template"))

   ;; TODO
   ((an-end-tag-whose-tag-name-is "template"))

   ((or (a-start-tag-whose-tag-name-is "head")
        (typep token 'end-tag))
    (parse-error "...")
    (ignore-token))
   
   (t
    (pop stack-of-open-elements)
    (switch-to 'after-head)
    (reprocess-current-token))))

(define-parser-insertion-mode in-head-noscript
  (cond
   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "html"))

   ((an-end-tag-whose-tag-name-is "noscript"))

   ((or (or (eq #\tab token) (eq #\newline token)
            (eq #\page token) (eq #\return token) (eq #\space token))
        (typep token 'comment-token)
        (a-start-tag-whose-tag-name-is-one-of '("basefont" "bgsound" "link"
                                                "meta" "noframes" "style"))))

   ((an-end-tag-whose-tag-name-is "br"))

   ((or (a-start-tag-whose-tag-name-is-one-of '("head" "noscript"))
        ;; Any other end tag
        (typep token 'end-tag)))

   ;; Anything else
   (t)))

(define-parser-insertion-mode after-head
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token))
    (insert-character))
   
   ((typep token 'comment-token)
    (insert-comment))
   
   ((typep token 'doctype-token)
    (parse-error "...")
    (ignore-token))
   
   ((a-start-tag-whose-tag-name-is "html")
    (process-token-in-in-body-insertion-mode))
   
   ((a-start-tag-whose-tag-name-is "body")
    (insert-html-element-for-token)
    ;; TODO: Set the frameset-ok flag to "not ok".
    (switch-to 'in-body))
   
   ((a-start-tag-whose-tag-name-is "frameset")
    (insert-html-element-for-token)
    (switch-to 'in-frameset))

   ((a-start-tag-whose-tag-name-is-one-of '("base" "basefont" "bgsound" "link"
                                            "meta" "noframes" "script" "style"
                                            "template" "title"))
    (parse-error "...")
    (let ((node head-element-pointer))
      (push node stack-of-open-elements)
      (process-token-in-in-head-insertion-mode)
      (setf stack-of-open-elements (remove node stack-of-open-elements))))

   ;; TODO
   ((an-end-tag-whose-tag-name-is "template"))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "html" "br"))
    ;; Same as T
    (insert-html-element-for-token (make-instance 'start-tag :tag-name "body"))
    (switch-to 'in-body)
    (reprocess-current-token))

   ((or (a-start-tag-whose-tag-name-is "head")
        (typep token 'end-tag))
    (parse-error "...")
    (ignore-token))
      
   (t
    (insert-html-element-for-token (make-instance 'start-tag :tag-name "body"))
    (switch-to 'in-body)
    (reprocess-current-token))))

(define-parser-insertion-mode in-body
  (cond
   ((eq #\null token)
    (parse-error "...")
    (ignore-token))
   
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token))
    (reconstruct-active-formatting-elements)
    (insert-character))
   
   ((typep token 'cl:character)
    (reconstruct-active-formatting-elements)
    (insert-character)
    #|TODO: Set the frameset-ok flag to "not ok".|#)
   
   ((typep token 'comment-token)
    (insert-comment))
   
   ((typep token 'doctype-token)
    (parse-error "...")
    (ignore-token))
   
   ((a-start-tag-whose-tag-name-is "html")
    (parse-error "...")
    #|TODO|#)
   
   ((or (a-start-tag-whose-tag-name-is-one-of '("base" "basefont" "bgsound" "link"
                                                "meta" "noframes" "script" "style"
                                                "template" "title"))
        (an-end-tag-whose-tag-name-is "template"))
    (process-token-in-in-head-insertion-mode))
   
   ((a-start-tag-whose-tag-name-is "body")
    (parse-error "...")
    #|TODO|#)

   ((a-start-tag-whose-tag-name-is "frameset")
    (parse-error "...")
    #|TODO|#)
   
   ;; An end-of-file token
   ((typep token 'end-of-file)
    (if (null stack-of-template-insertion-modes)
        (process-token-in-in-template-insertion-mode)
      (progn
        (if (find-if-not (lambda (node)
                           (typep node '(or dd dt li optgroup option
                                            p rb rp rt rtc
                                            tbody td tfoot th thead tr
                                            body html)))
                         stack-of-open-elements)
            (parse-error "..."))
        (stop-parsing))))
   
   ((an-end-tag-whose-tag-name-is "body")
    (if (not (have-element-in-scope-p "body"))
        (progn
          (parse-error "...")
          (ignore-token))
      (if (find-if-not (lambda (node)
                         (typep node '(or dd dt li optgroup option
                                          p rb rp rt rtc
                                          tbody td tfoot th thead tr
                                          body html)))
                       stack-of-open-elements)
          (parse-error "...")))
    (switch-to 'after-body))

   ((an-end-tag-whose-tag-name-is "html")
    (if (not (have-element-in-scope-p "body"))
        (progn
          (parse-error "...")
          (ignore-token))
      (if (find-if-not (lambda (node)
                         (typep node '(or dd dt li optgroup option
                                          p rb rp rt rtc
                                          tbody td tfoot th thead tr
                                          body html)))
                       stack-of-open-elements)
          (parse-error "...")))
    (switch-to 'after-body)
    (reprocess-current-token))
   
   ((a-start-tag-whose-tag-name-is-one-of '("address" "article" "aside" "blockquote"
                                            "center" "details" "dialog" "dir" "div" "dl"
                                            "fieldset" "figcaption" "figure" "footer" "header"
                                            "hgroup" "main" "menu" "nav" "ol" "p"
                                            "section" "summary" "ul"))
    (when (have-element-for-button-scope-p "p")
      (close-p-element))
    (insert-html-element-for-token))

   ((a-start-tag-whose-tag-name-is-one-of '("h1" "h2" "h3" "h4" "h5" "h6")))

   ((a-start-tag-whose-tag-name-is-one-of '("pre" "listing")))

   ((a-start-tag-whose-tag-name-is "form"))

   ((a-start-tag-whose-tag-name-is "li"))
   
   ((a-start-tag-whose-tag-name-is-one-of '("dd" "dt")))
   
   ((a-start-tag-whose-tag-name-is "plaintext"))

   ((a-start-tag-whose-tag-name-is "button"))
   

   ((an-end-tag-whose-tag-name-is-one-of '("address" "article" "aside" "blockquote"
                                           "center" "details" "dialog" "dir" "div" "dl"
                                           "fieldset" "figcaption" "figure" "footer" "header"
                                           "hgroup" "main" "menu" "nav" "ol" "p"
                                           "section" "summary" "ul")))

   ((an-end-tag-whose-tag-name-is "form"))

   ((an-end-tag-whose-tag-name-is "p")
    (when (have-element-for-button-scope-p "p")
      (parse-error "...")
      (insert-html-element-for-token (make-instance 'start-tag :tag-name "p")))
    (close-p-element))

   ((an-end-tag-whose-tag-name-is "li"))
   
   ((an-end-tag-whose-tag-name-is-one-of '("dd" "dt")))

   ((an-end-tag-whose-tag-name-is-one-of '("h1" "h2" "h3" "h4" "h5" "h6")))
   
   ((an-end-tag-whose-tag-name-is "sarcasm"))

   ((a-start-tag-whose-tag-name-is "a"))

   ((a-start-tag-whose-tag-name-is-one-of '("b" "big" "code" "em" "font"
                                            "i" "s" "small" "strike" "strong" "tt" "u")))

   ((a-start-tag-whose-tag-name-is "nobr"))

   ((an-end-tag-whose-tag-name-is-one-of '("a" "b" "big" "code" "em" "font"
                                           "i" "s" "small" "strike" "strong" "tt" "u")))

   ((a-start-tag-whose-tag-name-is-one-of '("applet" "marquee" "object")))
   
   ((an-end-tag-whose-tag-name-is-one-of '("applet" "marquee" "object")))

   ((a-start-tag-whose-tag-name-is "table"))

   ((an-end-tag-whose-tag-name-is "br"))

   ((a-start-tag-whose-tag-name-is-one-of '("area" "br" "embed" "img" "keygen" "wbr")))
   
   ((a-start-tag-whose-tag-name-is "input"))

   ((a-start-tag-whose-tag-name-is-one-of '("param" "source" "track")))

   ((a-start-tag-whose-tag-name-is "hr"))
  
   ((a-start-tag-whose-tag-name-is "image"))

   ((a-start-tag-whose-tag-name-is "textarea"))

   ((a-start-tag-whose-tag-name-is "xmp"))

   ((a-start-tag-whose-tag-name-is "iframe"))

   ((or (a-start-tag-whose-tag-name-is "noembed")
        (a-start-tag-whose-tag-name-is "noscript")))

   ((a-start-tag-whose-tag-name-is "select"))

   ((a-start-tag-whose-tag-name-is-one-of '("optgroup" "option")))

   ((a-start-tag-whose-tag-name-is-one-of '("rb" "rtc")))

   ((a-start-tag-whose-tag-name-is-one-of '("rp" "rt")))

   ((a-start-tag-whose-tag-name-is "math"))

   ((a-start-tag-whose-tag-name-is "svg"))

   ((a-start-tag-whose-tag-name-is-one-of '("caption" "col" "colgroup"
                                            "frame" "head" "tbody" "td" "tfoot"
                                            "th" "thead" "tr")))
   
   ((typep token 'start-tag)
    (reconstruct-active-formatting-elements)
    (insert-html-element-for-token))

   ((typep token 'end-tag))))

(define-parser-insertion-mode text
  (cond
   ((typep token 'cl:character)
    (insert-character))

   ((typep token 'end-of-file)
    (parse-error "...")
    (pop stack-of-open-elements)
    (setf insertion-mode original-insertion-mode)
    (reprocess-current-token))

   ((an-end-tag-whose-tag-name-is "script"))

   ((typep token 'end-tag)
    (pop stack-of-open-elements)
    (switch-to original-insertion-mode))))

(define-parser-insertion-mode in-table
  (cond
   ((if (typep current-node '(or table tbody tfoot thead tr))
        (typep token 'cl:character)))

   ((typep token 'comment-token))

   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "caption"))

   ((a-start-tag-whose-tag-name-is "colgroup"))

   ((a-start-tag-whose-tag-name-is "col"))

   ((a-start-tag-whose-tag-name-is-one-of '("tbody" "tfoot" "thead")))

   ((a-start-tag-whose-tag-name-is-one-of '("td" "th" "tr")))

   ((a-start-tag-whose-tag-name-is "table"))

   ((an-end-tag-whose-tag-name-is "table"))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "caption" "col" "colgroup"
                                           "html" "tbody" "td" "tfoot" "th" "thead" "tr")))

   ((or (a-start-tag-whose-tag-name-is-one-of '("style" "script" "template"))
        (an-end-tag-whose-tag-name-is "template")))

   ((a-start-tag-whose-tag-name-is "input"))

   ((a-start-tag-whose-tag-name-is "form"))

   ((typep token 'end-of-file))

   (t)))

(define-parser-insertion-mode in-table-text
  (cond
   ((eq #\null token))

   ((typep token 'cl:character))

   (t)))

(define-parser-insertion-mode in-caption
  (cond
   ((an-end-tag-whose-tag-name-is "caption"))

   ((or (a-start-tag-whose-tag-name-is-one-of '("caption" "col" "colgroup"
                                                "tbody" "td" "tfoot" "th" "thead" "tr"))
        (an-end-tag-whose-tag-name-is "table")))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "col" "colgroup" "html"
                                           "tbody" "td" "tfoot" "th" "thead" "tr")))

   (t)))

(define-parser-insertion-mode in-column-group
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token)))

   ((typep token 'comment-token))

   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "html"))

   ((a-start-tag-whose-tag-name-is "col"))

   ((an-end-tag-whose-tag-name-is "colgroup"))

   ((an-end-tag-whose-tag-name-is "col"))

   ((or (a-start-tag-whose-tag-name-is "template")
        (an-end-tag-whose-tag-name-is "template")))

   ((typep token 'end-of-file))

   (t)))

(define-parser-insertion-mode in-table-body
  (cond
   ((a-start-tag-whose-tag-name-is "tr"))

   ((a-start-tag-whose-tag-name-is-one-of '("th" "td")))

   ((an-end-tag-whose-tag-name-is-one-of '("tbody" "tfoot" "thead")))

   ((or (a-start-tag-whose-tag-name-is-one-of '("caption" "col" "colgroup" "tbody"
                                                "tfoot" "thead"))
        (an-end-tag-whose-tag-name-is "table")))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "caption" "col" "colgroup"
                                           "html" "td" "th" "tr")))

   (t)))

(define-parser-insertion-mode in-row
  (cond
   ((a-start-tag-whose-tag-name-is-one-of '("th" "td")))

   ((an-end-tag-whose-tag-name-is "tr"))

   ((or (a-start-tag-whose-tag-name-is-one-of '("caption" "col" "colgroup"
                                                "tbody" "tfoot" "thead" "tr"))
        (an-end-tag-whose-tag-name-is "table")))

   ((an-end-tag-whose-tag-name-is-one-of '("tbody" "tfoot" "thead")))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "caption" "col" "colgroup"
                                           "html" "td" "th")))

   (t)))

(define-parser-insertion-mode in-cell
  (cond
   ((an-end-tag-whose-tag-name-is-one-of '("td" "th")))

   ((a-start-tag-whose-tag-name-is-one-of '("caption" "col" "colgroup"
                                            "tbody" "tfoot" "thead" "tr")))

   ((an-end-tag-whose-tag-name-is-one-of '("body" "caption" "col" "colgroup" "html")))

   ((an-end-tag-whose-tag-name-is-one-of '("table" "tbody" "tfoot" "thead" "tr")))

   (t)))

(define-parser-insertion-mode in-select
  (cond
   ((eq #\null token))

   ((typep token 'cl:character))

   ((typep token 'comment-token))

   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "html"))

   ((a-start-tag-whose-tag-name-is "option"))

   ((a-start-tag-whose-tag-name-is "optgroup"))

   ((an-end-tag-whose-tag-name-is "optgroup"))

   ((an-end-tag-whose-tag-name-is "option"))

   ((an-end-tag-whose-tag-name-is "select"))

   ((a-start-tag-whose-tag-name-is "select"))

   ((a-start-tag-whose-tag-name-is-one-of '("input" "keygen" "textarea")))

   ((or (a-start-tag-whose-tag-name-is-one-of '("script" "template"))
        (an-end-tag-whose-tag-name-is "template")))

   ((typep token 'end-of-file))

   (t)))

(define-parser-insertion-mode in-select-in-table
  (cond
   ((a-start-tag-whose-tag-name-is-one-of '("caption" "table" "tbody" "tfoot" "thead"
                                            "tr" "td" "th")))
   
   ((an-end-tag-whose-tag-name-is-one-of '("caption" "table" "tbody" "tfoot" "thead"
                                           "tr" "td" "th")))

   (t)))

(define-parser-insertion-mode in-template
  (cond
   ((or (typep token 'cl:character)
        (typep token 'comment-token)
        (typep token 'doctype-token)))

   ((or (a-start-tag-whose-tag-name-is-one-of '("base" "basefont" "bgsound" "link" "meta"
                                                "noframes" "script" "style" "template" "title"))
        (an-end-tag-whose-tag-name-is "template")))

   ((a-start-tag-whose-tag-name-is-one-of '("caption" "colgroup" "tbody" "tfoot" "thead")))

   ((a-start-tag-whose-tag-name-is "col"))

   ((a-start-tag-whose-tag-name-is "tr"))

   ((a-start-tag-whose-tag-name-is-one-of '("td" "th")))

   ((typep token 'start-tag))

   ((typep token 'end-tag))

   ((typep token 'end-of-file))))

(define-parser-insertion-mode after-body
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token)))

   ((typep token 'comment-token))

   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "html"))

   ((an-end-tag-whose-tag-name-is "html"))

   ((typep token 'end-of-file))

   (t)))

(define-parser-insertion-mode in-frameset
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token)))

   ((typep token 'comment-token))

   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "html"))

   ((a-start-tag-whose-tag-name-is "frameset"))

   ((an-end-tag-whose-tag-name-is "frameset"))

   ((a-start-tag-whose-tag-name-is "frame"))

   ((a-start-tag-whose-tag-name-is "noframes"))

   ((typep token 'end-of-file))

   (t)))

(define-parser-insertion-mode after-frameset
  (cond
   ((or (eq #\tab token) (eq #\newline token)
        (eq #\page token) (eq #\return token) (eq #\space token)))

   ((typep token 'comment-token))

   ((typep token 'doctype-token))

   ((a-start-tag-whose-tag-name-is "html"))

   ((an-end-tag-whose-tag-name-is "html"))

   ((a-start-tag-whose-tag-name-is "noframes"))

   ((typep token 'end-of-file))

   (t)))


(define-parser-insertion-mode after-after-body
  (cond
   ((typep token 'comment-token))

   ((or (typep token 'doctype-token)
        (or (eq #\tab token) (eq #\newline token)
            (eq #\page token) (eq #\return token) (eq #\space token))
        (a-start-tag-whose-tag-name-is "html")))

   ((typep token 'end-of-file))

   (t)))

(define-parser-insertion-mode after-after-frameset
  (cond
   ((typep token 'comment-token))

   ((or (typep token 'doctype-token)
        (or (eq #\tab token) (eq #\newline token)
            (eq #\page token) (eq #\return token) (eq #\space token))
        (a-start-tag-whose-tag-name-is "html")))

   ((typep token 'end-of-file))

   ((a-start-tag-whose-tag-name-is "noframes"))

   (t)))

(defclass parser ()
  ((tokenizer
    :initarg :tokenizer
    :initform nil)
   (document
    :initarg :document
    :initform (make-instance 'document))
   (insertion-mode
    :initform 'initial)
   (current-token
    :initform nil)
   (stack-of-open-elements
    :initform nil)
   (stack-of-template-insertion-modes
    :initform nil)
   (head-element-pointer
    :initform nil)))

(defun current-node (parser)
  (first (slot-value parser 'stack-of-open-elements)))

(defun adjusted-current-node (parser)
  ;; TODO: Case for HTML fragment parsing
  (current-node parser))

(defun insert-character (parser token)
  (let ((data token))
    (let ((adjusted-insertion-location (appropriate-place-for-inserting-node parser)))
      (when (typep adjusted-insertion-location 'document)
        (return-from insert-character))
      (let ((text (car (last (dom:children adjusted-insertion-location)))))
        (if (typep text 'text)
            (append-char (slot-value text 'dom:data) data)
          (let ((text (make-instance 'text :data (string data))))
            (append-child adjusted-insertion-location text)))))))

(defun insert-html-element (parser token)
  (insert-foreign-element parser token "html"))

(defun create-element-for-token (token namespace)
  (check-type token start-tag)
  (make-instance 'element :tag-name (slot-value token 'tag-name)))

(defun insert-foreign-element (parser token namespace)
  (let ((adjusted-insertion-location (appropriate-place-for-inserting-node parser)))
    (let ((element (create-element-for-token token namespace)))
      (append-child adjusted-insertion-location element)
      (push element (slot-value parser 'stack-of-open-elements))
      element)))

(defun appropriate-place-for-inserting-node (parser &optional override-target)
  (let ((target (if override-target
                    override-target
                  (first (slot-value parser 'stack-of-open-elements)))))
    target))

(defun parse-generic-rawtext-element (parser)
  (with-slots (stack-of-open-elements
               tokenizer
               original-insertion-mode
               insertion-mode) parser
    (let ((token (first stack-of-open-elements)))
      (insert-html-element parser token)
      (setf (slot-value tokenizer 'state) 'rawtext-state)
      (setf original-insertion-mode insertion-mode)
      (setf insertion-mode 'text))))

(defun parse-generic-rcdata-element (parser)
  (with-slots (stack-of-open-elements
               tokenizer
               original-insertion-mode
               insertion-mode) parser
    (let ((token (first stack-of-open-elements)))
      (insert-html-element parser token)
      (setf (slot-value tokenizer 'state) 'rcdata-state)
      (setf original-insertion-mode insertion-mode)
      (setf insertion-mode 'text))))

(defun reconstruct-active-formatting-elements (parser)
  )

(defun tree-construction-dispatcher (parser token)
  (if (or (null (slot-value parser 'stack-of-open-elements))
          t
          #|TODO: Handle other cases|#)
      (let ((function
             (case (slot-value parser 'insertion-mode)
               ('initial 'process-token-in-initial-insertion-mode)
               ('before-html 'process-token-in-before-html-insertion-mode)
               ('before-head 'process-token-in-before-head-insertion-mode)
               ('in-head 'process-token-in-in-head-insertion-mode)
               ('in-head-noscript 'process-token-in-in-head-noscript-insertion-mode)
               ('after-head 'process-token-in-after-head-insertion-mode)
               ('in-body 'process-token-in-in-body-insertion-mode)
               ('text 'process-token-in-text-insertion-mode)
               ('in-table 'process-token-in-in-table-insertion-mode)
               ('in-table-text 'process-token-in-in-table-text-insertion-mode)
               ('in-caption 'process-token-in-in-caption-insertion-mode)
               ('in-column-group 'process-token-in-in-column-group-insertion-mode)
               ('in-table-body 'process-token-in-in-table-body-insertion-mode)
               ('in-row 'process-token-in-in-row-insertion-mode)
               ('in-cell 'process-token-in-in-cell-insertion-mode)
               ('in-select 'process-token-in-in-select-insertion-mode)
               ('in-select-in-table 'process-token-in-in-select-in-table-insertion-mode)
               ('in-template 'process-token-in-in-template-insertion-mode)
               ('after-body 'process-token-in-after-body-insertion-mode)
               ('in-frameset 'process-token-in-in-frameset-insertion-mode)
               ('after-frameset 'process-token-in-after-frameset-insertion-mode)
               ('after-after-body 'process-token-in-after-after-body-insertion-mode)
               ('after-after-frameset 'process-token-in-after-after-frameset-insertion-mode))))
        (format t "~A~%" token)
        (setf (slot-value parser 'current-token) token)
        (funcall function parser))
    (error "TODO: Process the token according to the rules given in the section for parsing tokens in foreign content.")))

(defgeneric pas (source &key)
  (:method ((source string) &key)
   (with-input-from-string (stream source)
     (pas stream)))
  (:method ((stream stream) &key)
   (let ((tokenizer (make-instance 'tokenizer :stream stream)))
     (let ((parser (make-instance 'parser :tokenizer tokenizer)))
       (loop
        (handler-bind
            ((on-token (lambda (c)
                         (let ((token (slot-value c 'token)))
                           (tree-construction-dispatcher parser token)
                           (when (typep token 'end-of-file)
                             (return (slot-value parser 'document)))))))
          (funcall (slot-value tokenizer 'state) tokenizer)))))))

(defgeneric parse (source &key))

(defmethod parse (source &key)
  (let ((document nil))
    (labels ((transform (node)
               (when node
                 (let ((parent (typecase node
                                 (plump-dom:element
                                  (when-let* ((tag-name (plump:tag-name node))
                                              (constructor (constructor tag-name)))
                                    (construct constructor)))
                                 (plump-dom:text-node
                                  (make-instance 'text :data (plump-dom:text node))))))
                   (when (and parent
                              (typep node 'plump-dom:element))
                     (let ((children (mapcar #'transform
                                             (coerce (plump:children node) 'list))))
                       (loop for child in children
                             do (append-child parent child)))
                     (let ((attributes (plump:attributes node)))
                       (loop for name being the hash-keys of attributes
                             using (hash-value value)
                             do (dom:set-attribute parent name value))))
                   parent))))
      (let ((root (plump:parse source)))
        (when (and (typep root 'plump-dom:root)
                   (plusp (length (plump:children root))))
          (loop for child across (plump:children root)
                if (typep child 'plump-dom:doctype)
                do (setf document (make-instance 'document))
                else if (typep child 'plump-dom:element)
                do (when-let ((element (transform child)))
                     (if document
                         (append-child document element)
                       (return element)))
                finally (return document)))))))