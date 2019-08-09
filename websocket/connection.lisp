(in-package :websocket)

(defclass connection ()
  ((input-stream     :initarg :input-stream
                     :initform (error "Must make connection with input stream"))
   (output-stream    :initarg :output-stream
                     :initform (error "Must make connection with output streams"))
   ;; (request    :initarg :request
   ;;             :reader connection-request
   ;;             :initform (error "Must make clients with requests"))
   (write-lock :initform (bt:make-lock))
   (state      :initform :disconnected)
   (pending-fragments :initform nil)
   (pending-opcode    :initform nil)))

(defun send-frame (connection opcode &optional data)
  (with-slots (write-lock output-stream) connection
    (bt:with-lock-held (write-lock)
      (write-frame output-stream opcode data))))

(defun receive-frame (connection)
  (with-slots (input-stream) connection
    (read-frame input-stream)))

(defun close-connection (connection &key (data nil data-supplied-p)
                                      (status 1000)
                                      (reason "Normal close"))
  (send-frame connection
              +connection-close+
              (if data-supplied-p
                  data
                  (concatenate 'vector
                               (coerce (list (logand (ash status -8) #xff)
                                             (logand status #xff))
                                       'vector)
                               (flexi-streams:string-to-octets
                                reason
                                :external-format :utf-8)))))
