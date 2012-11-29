;;;; -*- Mode: Lisp; indent-tabs-mode: nil -*-

(in-package :it.bese.fiveam)

;;;; * Tests

;;;; While executing checks and collecting the results is the core job
;;;; of a testing framework it is also important to be able to
;;;; organize checks into groups, fiveam provides two mechanisms for
;;;; organizing checks: tests and test suites. A test is a named
;;;; collection of checks which can be run and a test suite is a named
;;;; collection of tests and test suites.

(defvar *test*
  (make-hash-table :test 'eql)
  "Lookup table mapping test (and test suite)
  names to objects.")

(defun get-test (key &optional default)
  (gethash key *test* default))

(defun (setf get-test) (value key)
  (setf (gethash key *test*) value))

(defun rem-test (key)
  (remhash key *test*))

(defun test-names ()
  (loop for test being the hash-keys of *test*
        collect test))

(defmacro test (name &body body)
  "Deprecated. See DEF-TEST."
  (simple-style-warning "~A is OBSOLETE! Use ~A instead." 'test 'def-test)
  (destructuring-bind (name &rest args)
      (ensure-list name)
    `(def-test ,name (,@args) ,@body)))

(defmacro def-test (name (&key depends-on (suite nil suite-p) fixture
                            (compile-at :run-time) profile)
                    &body body)
  "Create a test named NAME.

NAME is the symbol which names the test.

DEPENDS-ON is a list of the form:

\(AND . test-names) - This test is run only if all of the tests
 in TEST-NAMES have passed, otherwise a single test-skipped
 result is generated.

\(OR . test-names) - If any of TEST-NAMES has passed this test is
 run, otherwise a test-skipped result is generated.

\(NOT test-name) - This is test is run only if TEST-NAME failed.

AND, OR and NOT can be combined to produce complex dependencies.

If DEPENDS-ON is a symbol it is interpreted as `(AND
,depends-on), this is accomadate the common case of one test
depending on another.

SUITE is the suite to put the test under. It defaults to
*SUITE* (which itself defaults to the default global suite).

FIXTURE specifies a fixture to wrap the body in.

If PROFILE is T profiling information will be collected as well.

COMPILE-AT can be either :RUN-TIME, in which case compilation of the
test code will be delayed until the test is run, or :DEFINITION-TIME,
in which case the code will be compiled when the DEF-TEST form itself
is compiled."
  (check-type compile-at (member :run-time :definition-time))
  (multiple-value-bind (forms decls docstring)
      (parse-body body :documentation t :whole name)
    (let* ((description (or docstring ""))
           (body-forms (append decls forms))
           (suite-form (if suite-p
                           `(get-test ',suite)
                           '*suite*))
           (effective-body (if fixture
                               (destructuring-bind (name &rest args)
                                   (ensure-list fixture)
                                 `((with-fixture ,name ,args ,@body-forms)))
                               body-forms)))
      `(progn
         (register-test ',name ,description ',effective-body ,suite-form ',depends-on ,compile-at ,profile)
         (when *run-test-when-defined*
           (run! ',name))
         ',name))))

(defun register-test (name description body suite depends-on compile-at profile)
  (let ((lambda-name
          (format-symbol t "%~A-~A" '#:test name))
        (inner-lambda-name
          (format-symbol t "%~A-~A" '#:inner-test name)))
    (setf (get-test name)
          (make-instance 'test-case
                         :name name
                         :runtime-package (find-package (package-name *package*))
                         :test-lambda
                         (eval
                          `(named-lambda ,lambda-name ()
                             ,@(ecase compile-at
                                 (:run-time `((funcall
                                               (let ((*package* (find-package ',(package-name *package*))))
                                                 (compile ',inner-lambda-name
                                                          '(lambda () ,@body))))))
                                 (:definition-time body))))
                         :description description
                         :depends-on depends-on
                         :collect-profiling-info profile))
    (setf (gethash name (tests suite)) name)))

(defvar *run-test-when-defined* nil
  "When non-NIL tests are run as soon as they are defined.")

;; Copyright (c) 2002-2003, Edward Marco Baringer
;; All rights reserved.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted provided that the following conditions are
;; met:
;;
;;  - Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;;
;;  - Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the distribution.
;;
;;  - Neither the name of Edward Marco Baringer, nor BESE, nor the names
;;    of its contributors may be used to endorse or promote products
;;    derived from this software without specific prior written permission.
;;
;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;; A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
