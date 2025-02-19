(load "azolla.lisp")
(defparameter *csvline* 0)
(defparameter *csvphase* nil)
(defparameter *instmap* (list))
(defparameter *textmap* (list))
(defparameter *datamap* (list))
(defparameter *asmphase* nil)
(defparameter *pc* 0)
(defparameter *addr* 0)
(defparameter *asmerror* nil)
(defparameter *imsb* 15)
(defparameter *amsb* 14)
(defparameter *msb* 7)
(defparameter *rom* (list))
(defparameter *ram* (list))
(defparameter *macromap* (list))
(defparameter *comperror* nil)
(defparameter *level* '((SYS)))
(defparameter *letid* 0)
(defparameter *ramdump* nil)
(defparameter *romdump* nil)
(defparameter *srcdump* nil)
(defparameter *jmpid* 0)
(defparameter *fbound* (list))
(defun loadcsv (csv)
  (setf *instmap* (list))
  (with-fp-r 
    (f csv)
    (do ((line (read-line f nil 'end) (read-line f nil 'end)))
      ((equalp line 'end))
      (cond
        ((pscan "^asm," line)
         (let ()
           (setf *csvline* 0)
           (setf *csvphase* 'asm)
           ))
        ((pscan "^macro," line)
         (let ()
           (setf *csvline* 0)
           (setf *csvphase* 'macro)
           ))
        ((pscan "^opt1," line)
         (let ()
           (setf *csvline* 0)
           (setf *csvphase* 'opt1)
           ))
        )
      (if (and
            (equalp *csvphase* 'asm)
            (> *csvline* 1)
            )
        (let ((p "")
              (b 0))
          (setf line (psplit ",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)" line))
          (if (and (car line) (cdr line))
            (let ()
              (setf p (string-trim '(#\") (car line)))
              (setf b (sym+"#b"(with-output-to-string (s) 
                                 (map 'list 
                                      (lambda (i) 
                                        (if (pscan "[0,1]{1}" i) (format s "~A" i))
                                        ) 
                                      (cdr line)))))
              (setf b (logior b (ash 1 *imsb*)))
              (push (list p b) *instmap*)
              ))
          ))
      (incf *csvline*))
    )
  (setf *instmap* (remove-duplicates (reverse *instmap*) :test 'equalp))
  (map 'list
       (lambda (i)
         (if (and
               (not(equalp "number" (nth 0 i)))
               (not(pscan "^br" (nth 0 i)))
               )
         (let ((p (nth 0 i))
               (b (nth 1 i)))
           (push (list (string+"br"p) (logior b (ash 1 6))) *instmap*)
           )))
       *instmap*)
  (setf *instmap* (remove-duplicates *instmap* :test 'equalp))
  (map 'list
       (lambda (i)
         (if (and
               (not(equalp "number" (nth 0 i)))
               (not(pscan "^j" (nth 0 i)))
               )
         (let ((p (nth 0 i))
               (b (nth 1 i)))
           (push (list (string+"jeq"p) (logior b (ash #b001 12))) *instmap*)
           (push (list (string+"jlt"p) (logior b (ash #b010 12))) *instmap*)
           (push (list (string+"jgt"p) (logior b (ash #b100 12))) *instmap*)
           (push (list (string+"jle"p) (logior b (ash #b011 12))) *instmap*)
           (push (list (string+"jge"p) (logior b (ash #b101 12))) *instmap*)
           (push (list (string+"jne"p) (logior b (ash #b110 12))) *instmap*)
           (push (list (string+"jmp"p) (logior b (ash #b111 12))) *instmap*)
           )))
       *instmap*)
  (setf *instmap* (remove-duplicates *instmap* :test 'equalp))
  )
(defun asm (asmfile binfile)
  (setf *asmerror* nil)
  (setf *pc* 0)
  (setf *addr* 0)
  (setf *ram* (make-list (ash 1 (1+ *amsb*)) :initial-element 0))
  (setf *textmap* (list))
  (setf *datamap* (list))
  (with-fp-r 
    (fi asmfile)
     (do ((line (read-line fi nil 'end) (read-line fi nil 'end))
         (k 1 (+ k 1)))
      ((or
         *asmerror*
         (equalp line 'end)
         ))
      (setf line (preplace "[;]+(.*)" line ""))
      (cond
        ((pscan "^.text" line) 
         (let () 
           (setf *asmphase* 'text)
           ))
        ((pscan "^.data" line) 
         (let () 
           (setf *asmphase* 'data)
           (format *ramdump* "~4X:~A~%" *addr* line)
           ))
        ((and
           (equalp *asmphase* 'text)
           (pscan "^\\S+[:]{1}\\s*$" line)
           )
         (let ((b (psplit "\\s+" (string-trim '(#\Space #\Tab #\Return) (preplace "[:]{1}\\s*$" line " ")))))
           (push (list (car b) *pc* (cdr b)) *textmap*)
           ))
        ((and
           (equalp *asmphase* 'data)
           (pscan "^\\S+[:]{1}\\s*$" line)
           )
         (let ((b (psplit "\\s+" (string-trim '(#\Space #\Tab #\Return) (preplace "[:]{1}\\s*$" line " ")))))
           (push (list (car b) *addr* (cdr b)) *datamap*)
           (format *ramdump* "~4X:~A~%" *addr* line)
           ))
        ((and
           (equalp *asmphase* 'text)
           (pscan "^\\s+\\S+" line)
           )
         (incf *pc*))
        ((and
           (equalp *asmphase* 'data)
           (pscan "^\\s+\\S+" line)
           )
         (let ((b (list)))
           (setf line (preplace "^\\s+" line ""))
           (setf line (preplace "\\s+$" line ""))
           (setf line (preplace "[\\,]{1}\\s+" line ","))
           (setf line (preplace "\\s+[\\,]{1}" line ","))
           (setf line (preplace "\\s+" line " "))
           (format *ramdump* "~4X:  ~25A" *addr* line)
           (setf line (preplace "0x" line "#x"))
           (setf line (sym+"("(preplace "," line " ")")"))
           (map 'list
                (lambda (i)
                  (cond
                    ((stringp i)
                     (let ()
                       (map 'list
                            (lambda (c)
                              (setf b (append b (list(char-code c))))
                              (setf (nth *addr* *ram*) (char-code c))
                              (incf *addr*)
                              )
                            (coerce i 'list))
                       ))
                    ((numberp i)
                     (let ((i1 (if (< i 0) (logand(1-(ash 1 (1+ *msb*)))(1+(lognot(abs i)))) i)))
                       (setf b (append b (list i1)))
                       (setf (nth *addr* *ram*) i1)
                       (incf *addr*)
                       ))
                    ))
                line)
           (format *ramdump* "~{~2X ~}~%" b)
           ))
        )
      )
    )
  (setf *pc* 0)
  (setf *rom* (make-list (ash 1 (1+ *amsb*)) :initial-element (1-(ash 1 (1+ *imsb*)))))
  (with-fp-r (fi asmfile)
  (with-fp-wb (fo binfile) 
    (do ((line (read-line fi nil 'end) (read-line fi nil 'end))
         (k 1 (+ k 1)))
      ((or
         *asmerror*
         (equalp line 'end)
         ))
      (if (pscan "^[;]+" line) (format *romdump* "~A~%" line))
      (setf line (preplace "[;]+(.*)" line ""))
      (cond
        ((pscan "^.text" line) 
         (let () 
           (setf *asmphase* 'text)
           (format *romdump* "~4X:~A~%" *pc* line)
           ))
        ((pscan "^.data" line) 
         (let () 
           ;(setf *addr* 0)
           (setf *asmphase* 'data)
           ))
        ((and
           (equalp *asmphase* 'text)
           (pscan "^\\S+[:]{1}\\s*$" line)
           )
         (let ()
           (format *romdump* "~4X:~A~%" *pc* line)
           ))
        ((and
           (equalp *asmphase* 'data)
           (pscan "^\\S+[:]{1}\\s*$" line)
           )
         (let ()
           ))
        ((and
           (equalp *asmphase* 'text)
           (pscan "^\\s+\\S+" line)
           )
         (let ((b nil))
           (setf line (preplace "^\\s+" line ""))
           (setf line (preplace "\\s+$" line ""))
           (setf line (preplace "[\\,]{1}\\s+" line ","))
           (setf line (preplace "\\s+[\\,]{1}" line ","))
           (setf line (preplace "\\s+" line " "))
           (setf b (nth 1 (assoc line (append *textmap* *datamap* *instmap*) :test 'equalp)))
           (if (equalp b nil) 
             (cond
               ((pscan "^halt$" line) (setf b (1-(ash 1 (1+ *imsb*)))))
               ((pscan "^[-]{0,1}[0-9]+$" line) 
                (setf b (logand (sym+ line) (1-(ash 1 *imsb*)))))
               ((pscan "^0x[0-9]+$" line) 
                (setf b (logand (sym+(preplace "^0x" line "#x")) (1-(ash 1 *imsb*)))))
               ((pscan "^'[a-zA-Z]{1}'$" line) 
                (setf b (logand (char-code(sym+"#\\"(string-trim '(#\') line))) (1-(ash 1 *imsb*)))))
               ))
           (if (not b) (setf *asmerror* (string+"asm error at line "k": "line)))
           (format *romdump* "~4X:  ~25A~4X~%" *pc* line b)
           (setf (nth *pc* *rom*) b)
           (incf *pc*)
           ))
        )
      )
    (if *asmerror* 
      (format t "~A~%" *asmerror*)
      (let ()
        (dotimes (k (1+ *pc*))
          (write-byte (ldb (byte 8 0) (nth k *rom*)) fo)
          (write-byte (ldb (byte 8 8) (nth k *rom*)) fo)
          )
        ))
    )))
(defun fullsname (sym) 
  (let ((p nil))
    (map 'list
         (lambda (l)
           (map 'list
                (lambda (i)
                  (if (and
                        (not p)
                        (equalp i sym)
                        )
                    (setf p (car l))))
                (reverse (cdr l))))
         *level*)
    (if p 
      (sym+ p"_" sym)
      (let ()
        (sym+ (car(car *level*))"_"sym)
        ))))
(defun asmcmt (e) (string-downcase(preplace "\\s+" (preplace "[\\n]{1}" (string+ e) " ") " ")))
(defun emit-asm (s e)
  (if *comperror* (let () (format t "~A~%" *comperror*) (format s ";compile error: ~A~%" (asmcmt e)))
  (cond
    ((atom e)
     (cond
       ((numberp e) (format s ";~A~%  ~D~%  mov d,a~%" (asmcmt e) e))
       ((stringp e) (format s ";~A~%  ~D~%  mov d,a~%" (asmcmt e) (char-code(car(coerce e 'list)))))
       ((symbolp e) (format s ";~A~%  ~A~%  mov d,[a]~%" (asmcmt e) (fullsname e)))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (function ...)
    ((and (symbolp (car e)) (member (car e) *fbound* :test 'equalp)) (emit-asm s (append '(funcall) e)))
    ;; (halt)
    ((equalp (car e) 'halt) (format s ";~A~%  halt~%" (asmcmt e)))
    ;; (progn ...)
    ((equalp (car e) 'progn) 
     (let ()
       (format s ";(progn~%")
       (map 'list (lambda (ei) (emit-asm s ei)) (cdr e))
       (format s ";)~%")
       ))
    ;; (begin sym1) 
    ((equalp (car e) 'begin)
     (cond
       ((nth 1 e) 
        (let ()
          (format s ";~A~%" (asmcmt e))
          (push (list(nth 1 e)) *level*)
          ;(format t "~S~%" *level*)
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (end ...) 
    ((equalp (car e) 'end)
     (let ()
       (format s ";~A~%" (asmcmt e))
       (pop *level*)))
    ;; (case sym1 (...))
    ((equalp (car e) 'case)
     (cond
       ((and
          (symbolp (cadr e))
          (cddr e)
          )
        (let ((ids (list)))
          (format s ";(case ~A~%" (asmcmt (cadr e)))
          (dotimes (k (length (cddr e))) (push (sym+"case_"*jmpid*"_"k) ids))
          (incf *jmpid*)
          (map 'list
               (lambda (id pair)
                 (cond
                   ((and (listp pair) (car pair) (cadr pair))
                    (let ()
                      (emit-asm s (list 'jne id (list '- (cadr e) (car pair))))
                      (emit-asm s (cadr pair))
                      (emit-asm s (list 'deflabel id))
                      ))
                   (t (setf *comperror* (string+"compile error: "e)))))
               ids (cddr e))
          (format s ";)~%")
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (dotimes (sym1 ...1) ...2)
    ((equalp (car e) 'dotimes)
     (cond
       ((and
          (symbolp (car(nth 1 e)))
          (cadr(nth 1 e))
          (cddr e)
          )
        (let ((id (sym+"dotimes"(incf *jmpid*))))
          (format s ";(dotimes ~A~%" (asmcmt (cadr e)))
          (emit-asm 
            s 
            (list 'let (list (list (car(nth 1 e)) 0))
                  (list 'deflabel id)
                  (append '(progn) (cddr e))
                  (list 'setq (car(nth 1 e)) (list '1+ (car(nth 1 e))))
                  (list 'jlt id (list '- (car(nth 1 e)) (nth 1 (nth 1 e))))
                  ))
          (format s ";)~%")
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (waitenww1c sym1 ...)  wait and write 1 clear 
    ((equalp (car e) 'waitenw1c)
     (cond
       ((symbolp (nth 1 e))
        (let ((id (sym+"waitenclear"*jmpid*)))
          (incf *jmpid*)
          (format s ";~A~%" (asmcmt e))
          (emit-asm s (list 'setq (nth 1 e) #x0))
          (emit-asm s (list 'deflabel id))
          (emit-asm s (list 'jeq id (nth 1 e)))
          (if (nth 2 e) (emit-asm s (nth 2 e)))
          (emit-asm s (list 'setq (nth 1 e) #x1))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (waiteq sym1 ...)
    ((equalp (car e) 'waiteq)
     (cond
       ((and
          (nth 2 e)
          (or
            (symbolp (nth 1 e))
            (listp (nth 1 e))
            )
          )
        (let ((id (sym+"waiteq"*jmpid*)))
          (incf *jmpid*)
          (format s ";~A~%" (asmcmt e))
          (emit-asm s (list 'deflabel id))
          (emit-asm s (list 'jne id (list '- (nth 1 e) (nth 2 e))))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (defvar sym1 num2) -- case1 
    ;; .data
    ;; sym1:
    ;;   num2
    ;; .text
    ;; (defvar sym1 (make-array num2)) -- case2 
    ;; .data
    ;; sym1:
    ;;   0 0 ... 
    ;; .text
    ;; (defvar sym1 str2) -- case3 
    ;; .data
    ;; sym1:
    ;;   str2 
    ;; .text
    ;; (defvar sym1 sym2|exp2) -- case4 
    ;; .data
    ;; sym1:
    ;;   0
    ;; .text
    ;; (setq sym1 sym2|exp2)
    ((equalp (car e) 'defvar)
     (cond
       ((symbolp (nth 1 e))
        (cond
          ((or (equalp nil (nth 2 e)) (numberp (nth 2 e)))
           (let ()
             (setf (car *level*) (append (car *level*) (list (nth 1 e))))
             (format s ";~A~%.data~%~A:~%  ~A~%.text~%" (asmcmt e) (fullsname(nth 1 e)) (if (nth 2 e) (nth 2 e) 0))
             ))
          ((and 
             (listp (nth 2 e)) 
             (equalp (car (nth 2 e)) 'make-array)
             (numberp (eval(nth 1 (nth 2 e))))
             )
           (let ()
             (setf (car *level*) (append (car *level*) (list (nth 1 e))))
             (format s ";~A~%.data~%~A:~%  ~{~X~^,~}~%.text~%" 
                     (asmcmt e) (fullsname(nth 1 e)) 
                     (make-list (eval(nth 1 (nth 2 e))) :initial-element #x0))))
          ((stringp (nth 2 e))
           (let ()
             (setf (car *level*) (append (car *level*) (list (nth 1 e))))
             (format s ";~A~%.data~%~A:~%  ~S~%.text~%" (asmcmt e) (fullsname(nth 1 e)) (nth 2 e))))
          ((or (symbolp (nth 2 e)) (listp (nth 2 e)))
           (let ()
             (format s ";~A~%" (asmcmt e))
             (emit-asm s (list 'defvar (nth 1 e) 0))
             (emit-asm s (list 'setq (nth 1 e) (nth 2 e)))
             ))
          (t (setf *comperror* (string+"compile error: "e)))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (deflabel sym1) -- case1
    ;; .sym1:
    ((equalp (car e) 'deflabel)
     (cond
       ((symbolp (nth 1 e))
        (let ()
          (setf (car *level*) (append (car *level*) (list (nth 1 e))))
          (format s ";~A~%~A:~%" (asmcmt e) (fullsname(nth 1 e)))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (eval ...) -- case 1
    ((equalp (car e) 'eval)
     (cond
       ((nth 1 e)
        (cond
          ((or (numberp (nth 1 e)) (symbolp (nth 1 e))) (emit-asm s (nth 1 e)))
          ((listp (nth 1 e)) (emit-asm s (nth 1 e)))
          (t (setf *comperror* (string+"compile error: "e)))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (funcall sym1 ...1)
    ((equalp (car e) 'funcall)
     (cond
       ((and (symbolp (nth 1 e)) (member (nth 1 e) *fbound* :test 'equalp))
        (let ()
          (format s ";~A~%" (asmcmt e))
          (map 'list
               (lambda (arg)
                 (emit-asm s (list 'pushs0 arg))
                 )
               (reverse(cddr e)))
          (emit-asm s (list 'pushs0 '(+ 7 (pc))))
          (emit-asm s (list 'goto (nth 1 e)))
          (format s ";~A return ~%  SYS_T0~%  mov d,[a]~%" (asmcmt e))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (defun sym1 (...1) ...2)
    ((equalp (car e) 'defun)
     (cond
       ((and (symbolp (nth 1 e)) (listp (nth 2 e)))
        (format s ";~A~%" (asmcmt e))
        (let ((l1 (list))
              (sret (sym+(nth 1 e)"_ret")))
          (map 'list
               (lambda (arg)
                 (push (list arg '(pops0)) l1))
               (reverse (nth 2 e)))
          (push (list sret '(pops0)) l1)
          (emit-asm s (list 'deflabel (nth 1 e)))
          ;(push (nth 1 e) *fbound*)
          (emit-asm s (append '(let) (list l1) (cdddr e) (list(list 'goto (list 'eval sret)))))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (goto sym1) -- case 1
    ;;   sym1
    ;;   jmpnop 
    ;; (goto ()) -- case 1
    ;;   SYS_T0
    ;;   mov [a],d
    ;;   ()
    ;;   mov a,d
    ;;   jmpnop
    ((equalp (car e) 'goto)
     (cond
       ((symbolp (nth 1 e))
        (format s ";~A~%  ~A~%  jmpnop~%" (asmcmt e) (fullsname (nth 1 e))))
       ((listp (nth 1 e))
        (let ()
          (format s ";~A~%  SYS_T0~%  mov [a],d~%" (asmcmt e))
          (emit-asm s (nth 1 e))
          (format s "  mov a,d~%  jmpnop~%")))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (jeq|jgt|jlt|jne|jge|jle sym1 num2) -- case 1
    ;;   num2
    ;;   mov d,a
    ;;   sym1
    ;;   jeq|jgt|jlt|jne|jge|jlenop 
    ((member (car e) '(jeq jgt jlt jne jge jle))
     (cond
       ((symbolp (nth 1 e))
        (let ()
          (cond
            ((numberp (nth 2 e)) (format s "  ~D~%  mov d,a~%" (nth 2 e)))
            ((symbolp (nth 2 e)) (format s "  ~A~%  mov d,[a]~%" (fullsname(nth 2 e))))
            ((listp (nth 2 e)) (emit-asm s (nth 2 e)))
            (t (setf *comperror* (string+"compile error: "e))))
          (format s ";~A~%  ~A~%  ~Anop~%" (asmcmt e) (fullsname(nth 1 e)) (string-downcase(string+(car e))))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (let (pairs) body) -- case1
    ;; (begin letid)
    ;; (map-apply 'defvar pairs)
    ;; body
    ;; (end letid)
    ;; (incf letid)
    ((equalp (car e) 'let)
     (cond
       ((listp (nth 1 e))
        (let ((id (sym+"let"(incf *letid*))))
          (format s ";~A~%" (asmcmt e))
          (emit-asm s (list 'begin id))
          (map 'list
               (lambda (i)
                 (emit-asm s (append '(defvar) (subseq i 0 1)))
                 (emit-asm s (append '(setq) (subseq i 0 2)))
                 )
               (nth 1 e))
          (if (cddr e)
            (map 'list
                 (lambda (i)
                   (emit-asm s i)
                   )
                 (cddr e)))
          (emit-asm s (list 'end id))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (pushs0 ...) -- case1
    ;;    ...
    ;;    SYS_S0
    ;;    mov [a],d
    ((equalp (car e) 'pushs0)
     (cond
       ((nth 1 e)
        (let ()
          (emit-asm s (nth 1 e))
          (format s ";~A~%  SYS_S0~%  mov [a],d~%" (asmcmt e))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (pops0) -- case1
    ;;    SYS_S0
    ;;    mov d,[a]
    ((equalp (car e) 'pops0)
     (format s ";~A~%  SYS_S0~%  mov d,[a]~%" (asmcmt e)))
    ;; (pc) -- case1
    ;;    mov d,p
    ((equalp (car e) 'pc)
     (format s ";~A~%  mov d,p~%" (asmcmt e)))
    ;; (setq sym1 0) -- case0
    ;;   sym1
    ;;   0 [a]
    ;; (setq sym1 1) -- case01
    ;;   sym1
    ;;   1 [a]
    ;; (setq sym1 -1) -- case01
    ;;   sym1
    ;;   -1 [a]
    ;; (setq sym1 num2) -- case1
    ;;   num2
    ;;   mov d,a
    ;;   sym1
    ;;   mov [a],d
    ;; (setq sym1 sym2) -- case2
    ;;   sym2
    ;;   mov d,[a]
    ;;   sym1
    ;;   mov [a],d
    ;; (setq sym1 ()) -- case3
    ;;   ()
    ;;   sym1
    ;;   mov [a],d
    ;; (setq (aref sym1 ap) ...2) -- case4
    ;;   ...2
    ;;   sym1
    ;;   mov [a],d
    ;; (setq (aref sym1 ...1) ...2) -- case5
    ;;   ...1
    ;;   SYS_AP
    ;;   mov [a],d
    ;;   ...2
    ;;   sym1
    ;;   mov [a],d
    ((member (car e) '(setq) :test 'equalp)
     (cond
       ((symbolp (nth 1 e))
        (cond
          ((equalp 0 (nth 2 e)) (format s ";~A~%  ~A~%  0 [a]~%" (asmcmt e) (fullsname(nth 1 e))))
          ((equalp 1 (nth 2 e)) (format s ";~A~%  ~A~%  1 [a]~%" (asmcmt e) (fullsname(nth 1 e))))
          ((equalp -1 (nth 2 e)) (format s ";~A~%  ~A~%  -1 [a]~%" (asmcmt e) (fullsname(nth 1 e))))
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~A~%  mov [a],d~%" (asmcmt e) (nth 2 e) (fullsname(nth 1 e))))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~A~%  mov [a],d~%" (asmcmt e) (fullsname(nth 2 e)) (fullsname(nth 1 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~A~%  mov [a],d~%" (asmcmt e) (fullsname(nth 1 e)))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((listp (nth 1 e))
        (cond
          ((equalp (car (nth 1 e)) 'aref)
           (cond
             ((symbolp (nth 1 (nth 1 e)))
              (let ()
                (emit-asm s (nth 2 (nth 1 e)))
                (format s ";~A~%  SYS_AP~%  mov [a],d~%" (asmcmt e))
                (emit-asm s (nth 2 e))
                (format s ";~A~%  ~A~%  mov [a],d~%" (asmcmt e) (fullsname(nth 1 (nth 1 e))))
                ))
             (t (setf *comperror* (string+"compile error: "e)))))
          (t (setf *comperror* (string+"compile error: "e)))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (aref sym1 ...) -- case1
    ;;   ...
    ;;   SYS_AP
    ;;   mov [a],d
    ;;   sym1
    ;;   mov d,[a]
    ((equalp (car e) 'aref)
     (cond
       ((symbolp (nth 1 e))
        (cond
          ((nth 2 e)
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  SYS_AP~%  mov [a],d~%  ~A~%  mov d,[a]~%" (asmcmt e) (fullsname(nth 1 e)))
             ))
          (t (setf *comperror* (string+"compile error: "e)))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; (+ elm1 elm2 elm3 ...) -- case0
    ;; (+ elm1 (+ elm2 elm3 ...))
    ;; (+ num1 num2) -- case1
    ;;   num2
    ;;   mov d,a
    ;;   num1
    ;;   add d,a,d
    ;; (+ num1 sym2) -- case2
    ;;   sym2
    ;;   mov d,[a]
    ;;   num1
    ;;   add d,a,d
    ;; (+ num1 ()) -- case3
    ;;   ()
    ;;   num1
    ;;   add d,a,d
    ;; (+ sym1 num2) -- case4
    ;;   num2
    ;;   mov d,a
    ;;   sym1
    ;;   add d,[a],d
    ;; (+ sym1 sym2) -- case5
    ;;   sym2
    ;;   mov d,[a]
    ;;   sym1
    ;;   add d,[a],d
    ;; (+ sym1 ()) -- case6
    ;;   ()
    ;;   sym1
    ;;   add d,[a],d
    ;; (+ () num2) -- case7
    ;;   ()
    ;;   SYS_T0
    ;;   mov [a],d
    ;;   num2
    ;;   mov d,a
    ;;   SYS_T0
    ;;   add d,[a],d
    ;; (+ () sym2) -- case8
    ;;   ()
    ;;   SYS_T0
    ;;   mov [a],d
    ;;   sym2
    ;;   mov d,[a]
    ;;   SYS_T0
    ;;   add d,[a],d
    ;; (+ (1) (2)) -- case9
    ;;   (1)
    ;;   SYS_T0
    ;;   mov [a],d
    ;;   (2)
    ;;   SYS_T0
    ;;   add d,[a],d
    ((equalp (car e) '+)
     (cond
       ((cdddr e) (emit-asm s (list '+ (nth 1 e) (append '(+) (cddr e)))))
       ((numberp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~D~%  add d,a,d~%" (asmcmt e) (nth 2 e) (nth 1 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~D~%  add d,a,d~%" (asmcmt e) (fullsname(nth 2 e)) (nth 1 e)))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~D~%  add d,a,d~%" (asmcmt e) (nth 1 e))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((symbolp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~A~%  add d,[a],d~%" (asmcmt e) (nth 2 e) (fullsname(nth 1 e))))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~A~%  add d,[a],d~%" (asmcmt e) (fullsname(nth 2 e)) (fullsname(nth 1 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~A~%  add d,[a],d~%" (asmcmt e) (fullsname(nth 1 e)))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((listp (nth 1 e))
        (let ()
          (emit-asm s (nth 1 e))
          (format s "  SYS_T0~%  mov [a],d~%")
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  SYS_T0~%  add d,[a],d~%" (asmcmt e) (nth 2 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  SYS_T0~%  add d,[a],d~%" (asmcmt e) (fullsname(nth 2 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  SYS_T0~%  add d,[a],d~%" (asmcmt e))))
          (t (setf *comperror* (string+"compile error: "e))))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; - 
    ((equalp (car e) '-)
     (cond
       ((cdddr e) (emit-asm s (list '- (nth 1 e) (append '(+) (cddr e)))))
       ((numberp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~D~%  sub d,a,d~%" (asmcmt e) (nth 2 e) (nth 1 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~D~%  sub d,a,d~%" (asmcmt e) (fullsname(nth 2 e)) (nth 1 e)))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~D~%  sub d,a,d~%" (asmcmt e) (nth 1 e))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((symbolp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~A~%  sub d,[a],d~%" (asmcmt e) (nth 2 e) (fullsname(nth 1 e))))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~A~%  sub d,[a],d~%" (asmcmt e) (fullsname(nth 2 e)) (fullsname(nth 1 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~A~%  sub d,[a],d~%" (asmcmt e) (fullsname(nth 1 e)))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((listp (nth 1 e))
        (let ()
          (emit-asm s (nth 1 e))
          (format s "  SYS_T0~%  mov [a],d~%")
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  SYS_T0~%  sub d,[a],d~%" (asmcmt e) (nth 2 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  SYS_T0~%  sub d,[a],d~%" (asmcmt e) (fullsname(nth 2 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  SYS_T0~%  sub d,[a],d~%" (asmcmt e))))
          (t (setf *comperror* (string+"compile error: "e))))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; 1+ 
    ((equalp (car e) '1+)
     (cond
       ((numberp (nth 1 e)) (format s ";~A~%  ~D~%  binc d,a~%" (asmcmt e) (nth 1 e)))
       ((symbolp (nth 1 e)) (format s ";~A~%  ~A~%  binc d,[a]~%" (asmcmt e) (fullsname(nth 1 e))))
       ((listp (nth 1 e)) 
        (let ()
          (emit-asm s (nth 1 e))
          (format s ";~A~%  binc d,d~%" (asmcmt e))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; 1- 
    ((equalp (car e) '1-)
     (cond
       ((numberp (nth 1 e)) (format s ";~A~%  ~D~%  bdec d,a~%" (asmcmt e) (nth 1 e)))
       ((symbolp (nth 1 e)) (format s ";~A~%  ~A~%  bdec d,[a]~%" (asmcmt e) (fullsname(nth 1 e))))
       ((listp (nth 1 e)) 
        (let ()
          (emit-asm s (nth 1 e))
          (format s ";~A~%  bdec d,d~%" (asmcmt e))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; ash 
    ;; (ash () num2) -- case1
    ;;   ()
    ;;   num2
    ;;   sh d,a,d
    ;; (ash () sym2) -- case2
    ;;   ()
    ;;   sym2
    ;;   sh d,[a],d
    ;; (ash (1) (2)) -- case3
    ;;   (2)
    ;;   SYS_T0
    ;;   mov [a],d
    ;;   (1)
    ;;   SYS_T0
    ;;   sh d,[a],d
    ((equalp (car e) 'ash)
     (cond
       ((numberp (nth 2 e))
        (let ()
          (emit-asm s (nth 1 e))
          (format s ";~A~%  ~D~%  sh d,a,d~%" (asmcmt e) (nth 2 e))
          ))
       ((symbolp (nth 2 e))
        (let ()
          (emit-asm s (nth 1 e))
          (format s ";~A~%  ~A~%  sh d,[a],d~%" (asmcmt e) (fullsname(nth 2 e)))
          ))
       ((listp (nth 2 e))
        (let ()
          (emit-asm s (nth 2 e))
          (format s ";~A~%  SYS_T0~%  mov [a],d~%" (asmcmt e))
          (emit-asm s (nth 1 e))
          (format s ";~A~%  SYS_T0~%  sh d,[a],d~%" (asmcmt e))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; lognot 
    ((equalp (car e) 'lognot)
     (cond
       ((numberp (nth 1 e)) (format s ";~A~%  ~D~%  inv d,a~%" (asmcmt e) (nth 1 e)))
       ((symbolp (nth 1 e)) (format s ";~A~%  ~A~%  inv d,[a]~%" (asmcmt e) (fullsname(nth 1 e))))
       ((listp (nth 1 e)) 
        (let ()
          (emit-asm s (nth 1 e))
          (format s ";~A~%  inv d,d~%" (asmcmt e))))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; logand 
    ((equalp (car e) 'logand)
     (cond
       ((cdddr e) (emit-asm s (list 'logand (nth 1 e) (append '(logand) (cddr e)))))
       ((numberp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~D~%  and d,a,d~%" (asmcmt e) (nth 2 e) (nth 1 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~D~%  and d,a,d~%" (asmcmt e) (fullsname(nth 2 e)) (nth 1 e)))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~D~%  and d,a,d~%" (asmcmt e) (nth 1 e))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((symbolp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~A~%  and d,[a],d~%" (asmcmt e) (nth 2 e) (fullsname(nth 1 e))))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~A~%  and d,[a],d~%" (asmcmt e) (fullsname(nth 2 e)) (fullsname(nth 1 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~A~%  and d,[a],d~%" (asmcmt e) (fullsname(nth 1 e)))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((listp (nth 1 e))
        (let ()
          (emit-asm s (nth 1 e))
          (format s "  SYS_T0~%  mov [a],d~%")
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  SYS_T0~%  and d,[a],d~%" (asmcmt e) (nth 2 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  SYS_T0~%  and d,[a],d~%" (asmcmt e) (fullsname(nth 2 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  SYS_T0~%  and d,[a],d~%" (asmcmt e))))
          (t (setf *comperror* (string+"compile error: "e))))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    ;; logior 
    ((equalp (car e) 'logior)
     (cond
       ((cdddr e) (emit-asm s (list 'logior (nth 1 e) (append '(logior) (cddr e)))))
       ((numberp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~D~%  or d,a,d~%" (asmcmt e) (nth 2 e) (nth 1 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~D~%  or d,a,d~%" (asmcmt e) (fullsname(nth 2 e)) (nth 1 e)))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~D~%  or d,a,d~%" (asmcmt e) (nth 1 e))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((symbolp (nth 1 e))
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  ~A~%  or d,[a],d~%" (asmcmt e) (nth 2 e) (fullsname(nth 1 e))))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  ~A~%  or d,[a],d~%" (asmcmt e) (fullsname(nth 2 e)) (fullsname(nth 1 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  ~A~%  or d,[a],d~%" (asmcmt e) (fullsname(nth 1 e)))))
          (t (setf *comperror* (string+"compile error: "e)))))
       ((listp (nth 1 e))
        (let ()
          (emit-asm s (nth 1 e))
          (format s "  SYS_T0~%  mov [a],d~%")
        (cond
          ((numberp (nth 2 e))
           (format s ";~A~%  ~D~%  mov d,a~%  SYS_T0~%  or d,[a],d~%" (asmcmt e) (nth 2 e)))
          ((symbolp (nth 2 e))
           (format s ";~A~%  ~A~%  mov d,[a]~%  SYS_T0~%  or d,[a],d~%" (asmcmt e) (fullsname(nth 2 e))))
          ((listp (nth 2 e))
           (let ()
             (emit-asm s (nth 2 e))
             (format s ";~A~%  SYS_T0~%  or d,[a],d~%" (asmcmt e))))
          (t (setf *comperror* (string+"compile error: "e))))
          ))
       (t (setf *comperror* (string+"compile error: "e)))))
    (t (setf *comperror* (string+"compile error: "e))))))
(defun comp (lispfile asmfile)
  (setf *comperror* nil)
  (setf *level* '((SYS)))
  (setf *fbound* (list))
  (let ((l (list))
        (l0 (list))
        (l1 (list))
        (l2 (list)))
    (with-fp-r (fi lispfile) (do ((e (read fi nil 'end) (read fi nil 'end))) ((equalp e 'end)) (push e l)))
    (map 'list 
         (lambda (e)
           (if (and
                 (listp e)
                 (member (car e) '(defun) :test 'equalp)
                 )
             (let ()
               (push e l1)
               (push (nth 1 e) *fbound*)
               )
             (if (and
                   (listp e)
                   (member (car e) '(defvar) :test 'equalp)
                   )
               (push e l0)
               (push e l2)))) 
         l)
    (setf l (append l0 '((goto main)) l1 '((deflabel main)) l2))
    ;(format t "src:~%~S~%" l)
    ;(format t "fbound:~%~S~%" *fbound*)
    (with-fp-w (fo asmfile) (map 'list (lambda (e) (format *srcdump* "~A~%" e) (emit-asm fo e)) l))
    ))
(defun format-verilog-rom (verilogfile top)
  (with-fp-w
    (f verilogfile)
    (format f "module ~A (output reg [~D:0] inst, input [~D:0] pc, input rstb, clk);~%" top *imsb* *amsb*)
    (format f "always@(negedge rstb or posedge clk) begin~%")
    (format f " if(!rstb) inst <= 'h~,'0X;~%" (1-(ash 1 (1+ *imsb*))))
    (format f " else if('h~,'0X >= pc) begin~%" (1+ *pc*))
    (format f "   case(pc)~%")
    (dotimes (k (+ 1 *pc*)) (format f "     'h~,'0X : inst <= 'h~,'0X;~%" k (nth k *rom*)))
    (format f "   endcase~%")
    (format f " end~%")
    (format f " else inst <= 'h~,'0X;~%" (1-(ash 1 (1+ *imsb*))))
    (format f "end~%")
    (format f "endmodule~%")
    ))
(if (and
      (or
        (and
          (member "-c" (argv) :test 'equalp)
          (nth (1+(position "-c" (argv) :test 'equalp)) (argv))
          )
        (and
          (member "-s" (argv) :test 'equalp)
          (nth (1+(position "-s" (argv) :test 'equalp)) (argv))
          )
        )
      (member "-o" (argv) :test 'equalp)
      )
  (let ((bin (nth (1+(position "-o" (argv) :test 'equalp)) (argv))))
    (if (member "-ramdump" (argv) :test 'equalp) (setf *ramdump* t))
    (if (member "-romdump" (argv) :test 'equalp) (setf *romdump* t))
    (if (member "-srcdump" (argv) :test 'equalp) (setf *srcdump* t))
    (format t "load define ~A~%" "118.csv")
    (loadcsv "118.csv")
    (format t "instructions: ~6D /~6D~%" (length *instmap*) (ash 1 (1- *imsb*)))
    (if (and
          (member "-c" (argv) :test 'equalp)
          (probe-file (nth (1+(position "-c" (argv) :test 'equalp)) (argv)))
          )
      (let ((src (nth (1+(position "-c" (argv) :test 'equalp)) (argv)))
            (asm (nth (1+(position "-s" (argv) :test 'equalp)) (argv))))
        (format t "compile ~A~%" src)
        (comp src asm)
        ))
    (if (and
          (member "-s" (argv) :test 'equalp)
          (probe-file (nth (1+(position "-s" (argv) :test 'equalp)) (argv)))
          )
      (let ((asm (nth (1+(position "-s" (argv) :test 'equalp)) (argv))))
        (format t "assemble ~A~%" asm)
        (asm asm bin)
        ))
    ;(format t "ram:~%~4X~%" (subseq *ram* 0 (1+ *addr*)))
    (format t "rom:~%~4X~%~b~%" (subseq *rom* 0 (1+ *pc*)) (1+ *pc*))
    (if (and
          (member "-v" (argv) :test 'equalp)
          (nth (1+(position "-v" (argv) :test 'equalp)) (argv))
          (nth (+ 2 (position "-v" (argv) :test 'equalp)) (argv))
          )
      (let ((verilog (nth (1+(position "-v" (argv) :test 'equalp)) (argv)))
            (top (nth (+ 2 (position "-v" (argv) :test 'equalp)) (argv))))
        (format t "write verilog rom module ~A to ~A~%" top verilog)
        (format-verilog-rom verilog top)
        ))
    (format t "~X~%" *datamap*)
    )
  (let ()
    (format t "-msb <data msb (< amsb)>~%")
    (format t "-amsb <address msb (< imsb)>~%")
    (format t "-imsb <instruction msb (>= 15)>~%")
    (format t "-c <lisp source file>~%")
    (format t "-s <asm output file>~%")
    (format t "-o <bin output file>~%")
    (format t "-v <verilog rom module output file> <top name>~%")
    (format t "-ramdump ~%")
    (format t "-romdump ~%")
    (format t "-srcdump ~%")
    ))
