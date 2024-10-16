(defmacro with-sp-w ((s) &rest b) `(with-output-to-string (,s) ,@b))
(defmacro with-sp-r ((s str) &rest b) `(with-input-from-string (,s ,str) ,@b))
(defun string+ (&rest l) (with-sp-w (s) (map 'list (lambda (i) (format s "~A" i)) l)))
(defun sym+ (&rest l) (read-from-string(apply 'string+ l)))
(defun exec (s &rest l) (run-program (car l) (cdr l) :output s))
(defmacro with-fp-w ((s file) &body b)
  `(with-open-file
	 (,s ,file
		 :direction :output
		 :if-does-not-exist :create
		 :if-exists :supersede
		 )
	 ,@b))
(defmacro with-fp-w+ ((s file) &body b)
  `(with-open-file
	 (,s ,file
		 :direction :output
		 :if-does-not-exist :create
		 :if-exists :append
		 )
	 ,@b))
(defmacro with-bfp-w ((s file) &body b)
  `(with-open-file
	 (,s ,file
		 :direction :output
		 :if-does-not-exist :create
		 :if-exists :supersede
		 :element-type '(unsigned-byte 8)
		 )
	 ,@b))
(defmacro with-bfp-w+ ((s file) &body b)
  `(with-open-file
	 (,s ,file
		 :direction :output
		 :if-does-not-exist :create
		 :if-exists :append
		 :element-type '(unsigned-byte 8)
		 )
	 ,@b))
(defmacro with-fp-r ((s file) &body b)
  `(with-open-file
	 (,s ,file
		 :direction :input
		 )
	 ,@b))
(defmacro with-bfp-r ((s file) &body b)
  `(with-open-file
	 (,s ,file
		 :direction :input
		 :element-type '(unsigned-byte 8)
		 )
	 ,@b))
(defmacro argv () `*command-line-argument-list*)
(require "cl-ppcre")
(defun pscan (e s) (cl-ppcre:scan-to-strings e s))
(defun pmatch (e s) (cl-ppcre:all-matches-as-strings e s))
(defun preplace (e1 s e2) (cl-ppcre:regex-replace-all e1 s e2))
(defun psplit (e s) (cl-ppcre:split e s))
(defun pquote (b) (cl-ppcre:quote-meta-chars b))
(defmacro doline ((s end cnt line) &body b) 
  `(do ((,cnt 1 (+ ,cnt 1))
		(,line (read-line ,s nil ,end) (read-line ,s nil ,end)))
	 ((equalp ,line ,end))
	 ,@b))
(defun pmatchlines (file p)
  (let ((r (list)))
	(with-fp-r
	  (s file)
	  (doline
		(s 'end k line)
		(if (pscan p line) (push k r))))
	r))
(load "soc.lisp")
