(defparameter *socdb* ".db.lisp")
(defun init-socdb () 
  (with-fp-w 
	(f *socdb*) 
	(format f "; universal-time ~A~%" (get-universal-time)))
  (format t "init soc with db: ~S~%" *socdb*))
(defun read-rtl-marks (file &key identifier)
  (let ((id (if identifier identifier "//#"))
		(rec nil))
	(format t "read rtl marks from ~A with identifier: ~S~%" file id)
	(with-fp-r 
	  (s file)
	  (with-fp-w+
		(f *socdb*)
		(format f "(mark ~S~%" file)
		(doline 
		  (s 'end cnt line)
		  (if (and (not rec) (pscan"module\\s+\\S+"line) (pscan id line))
			(let ()
			  (format f " (module ~S ~%" (nth 1 (psplit"\\s+"(pscan"module\\s+\\S+"line))))
			  (setf rec t)))
		  (if (and rec (pscan id line))
			(let ()
			  ;(setf line (preplace id line ";"))
			  (setf line (preplace "[\\(]{1}" line " ("))
			  (setf line (preplace "(reg|wire)" line " "))
			  (setf line (string+"line="cnt"; "line))
			  (setf line (preplace "\\s+" line " "))
			  (format f "  (line ~S) " cnt)
			  (if (pscan"(input|output|inout)[^/]+"line)
				(let ((p (pscan"(input|output|inout)[^/]+"line)))
				  (if (pscan"input"p) (format f "(input "))
				  (if (pscan"output"p) (format f "(output "))
				  (if (pscan"inout"p) (format f "(inout "))
				  (setf p (preplace "(input|output|inout)" p ""))
				  (if (pscan"[\\[]{1}[^\\]]+[\\]]"p)
					(let ((r (pscan"[\\[]{1}[^\\]]+[\\]]"p)))
					  (format f "~S " r)
					  (setf p (preplace "[\\[]{1}[^\\]]+[\\]]" p ""))
					  ))
				  (setf p (psplit "[,\\s]+" p))
				  (setf p (remove-if #'(lambda (i) (if (pscan"\\S+"i) nil t)) p))
				  (format f "~{~S ~}) " p)
				  ))
			  (if (pscan"bus:[^;]+"line)
				(let ((bus (pscan "bus:[^;]+"line)))
				  (format f "(bus ")
				  (if (pscan"slave=[^;,\\s]+"bus) (format f "~S " (psplit"[=]+"(pscan"slave=[^;,\\s]+"bus))))
				  (if (pscan"addr0=[^;,\\s]+"bus) (format f "~S " (psplit"[=]+"(pscan"addr0=[^;,\\s]+"bus))))
				  (if (pscan"addr=[^;,\\s]+"bus) (format f "~S " (psplit"[=]+"(pscan"addr=[^;,\\s]+"bus))))
				  (if (pscan"data[\\[]{1}[^\\]]+[\\]]"bus) (format f "(data ~S) " (preplace"data"(pscan"data[\\[]{1}[^\\]]+[\\]]"bus)"")))
				  (if (pscan"type=[^;,\\s]+"bus) (format f "~S " (psplit"[=]+"(pscan"type=[^;,\\s]+"bus))))
				  (format f ") ")
				  ))
			  (if (pscan"io:[^;]+"line)
				(let ((io (pscan"io:[^;]+"line)))
				  (format f "(io ")
				  (if (pscan"mux=[^;\\s]+"io) (format f "~S " (psplit"[=]+"(pscan"mux=[^;\\s]+"io))))
				  (format f ") ")
				  ))
        (if (pscan"[\"]{1}[^\"]+[\"]{1}"line)
          (let ((comment (string-trim '(#\") (pscan"[\"]{1}[^\"]+[\"]{1}"line))))
            (format f "(comment ~S) " comment)
            ))
			  (format f "	;; ~A~%" line)
			  ))
		  (if (and rec (pscan"endmodule"line))
			(let ()
			  (format f " )~%")
			  (setf rec nil))))
		(format f ")~%")))))
