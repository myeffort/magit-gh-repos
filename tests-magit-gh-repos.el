(require 'ert)
(require 'noflet)
(require 'magit-gh-repos)

(defun test-magit-gh-repos-mock (cls &rest args)
  (cl-case cls 
    (gh-api-paged-response
     (apply 'make-instance cls :data
            (list (test-magit-gh-repos-mock 'gh-repos-repo)
                  (test-magit-gh-repos-mock 'gh-repos-repo)) args))
    (t (apply 'make-instance cls args))))

(ert-deftest tests-magit-gh-repos/configurable ()
  "Should format repo output through evaluation of configured forms."
  (let ((magit-gh-repos-list-format
         '((format "%-4s%s" name language) description))) 
    (magit-gh-repos-pretty-printer 
     (test-magit-gh-repos-mock 'gh-repos-repo 
                               :name "foo"
                               :language "bar"
                               :description "baz"))
    (should (equal "foo bar\nbaz\n" 
                   (buffer-substring-no-properties
                    (point-min) (point-max))))))

(ert-deftest tests-magit-gh-repos/list-sections ()
  "Listing should have at least one section."
  (let (magit-root-section)
    (should-not magit-root-section)
    (noflet ((gh-repos-user-list (&rest args)
               (test-magit-gh-repos-mock 'gh-api-paged-response))
             (magit-gh-repos-pretty-printer (&rest args)))
      (magit-gh-repos-load-next-page nil))
    (should (magit-section-p magit-root-section))))

(ert-deftest tests-magit-gh-repos/repo-sections ()
  "Repos should have a section of their own."
  (let ((magit-gh-repos-list-format '(name)) magit-root-section)
    (noflet ((gh-repos-user-list (&rest args)
               (test-magit-gh-repos-mock 'gh-api-paged-response)))
      (magit-gh-repos-load-next-page nil))
    (should (= 2 (length 
                  (magit-section-children magit-root-section))))))

(ert-deftest tests-magit-gh-repos/ewoc ()
  "Should record printer offsets into EWOC object."
  (let (ewoc-created node-added) 
    (catch 'ok
      (noflet ((gh-repos-user-list (&rest args)
                 (test-magit-gh-repos-mock 'gh-api-paged-response))
               (magit-gh-repos-pretty-printer (&rest args))
               (ewoc-create (pp &rest args) 
                 (cond ((not ewoc-created) (setq ewoc-created t))
                       (t (throw 'fail 
                            "`ewoc-create' called twice"))))
               (ewoc-enter-last (ew nd &rest args)
                 (cond (node-added (throw 'ok nil))
                       (ewoc-created (setq node-added 1))
                       (t (throw 'fail 
                            "`ewoc-created' was not called")))))
        (magit-gh-repos-load-next-page nil)))))

(ert-deftest tests-magit-gh-repos/magit-setup ()
  "Should let magit to set up the buffer."
  (catch 'ok
    (noflet ((magit-mode-init (&rest args)
               (throw 'ok nil)))
      (magit-gh-repos))
    (throw 'fail "Did not call `magit-mode-init'")))

(ert-deftest tests-magit-gh-repos/switch-function ()
  "Should use magit config and allow passing as argument."
  (noflet ((show-buffer-fn (x &rest args) (throw 'ok nil)))
    (catch 'ok (magit-gh-repos nil 'show-buffer-fn)
           (throw 'fail "did not call specified switch-function")))
  (noflet ((another-fn (x &rest args) (throw 'ok nil)))
    (let ((magit-gh-repos-switch-function 'another-fn))
      (catch 'ok (magit-gh-repos nil 'another-fn)
             (throw 'fail 
               "Did not call configured switch-function")))))

(ert-deftest test-magit-gh-repos/username-query ()
  "Should pass optional parameters to `gh-repos-user-list'."
  (catch 'ok
    (noflet ((gh-repos-user-list (a u &rest args)
               (cond ((equal u "foobar") (throw 'ok nil))
                     (t (throw 
                            "Requested repos for wrong username.")))))
      (magit-gh-repos "foobar")
      (throw 'fail "Did not request repos for any username."))))

(ert-deftest test-magit-gh-repos/interactive ()
  "Should be able to accept username through interactive input."
  (catch 'ok
    (noflet ((gh-repos-user-list (api username &rest args)
               (cond ((string= "foobar" username) (throw 'ok nil))
                     (t (throw 'fail "Input was not processed.")))))
      (magit-gh-repos "foobar"))))

(ert-deftest test-magit-gh-repos/interactive-2 ()
  "Should reset empty username to nil before sending it to the API."
  (catch 'ok
    (noflet ((gh-repos-user-list (api username &rest args)
               (cond ((not username) (throw 'ok nil))
                     (t (throw 'fail "Username was not a nil.")))))
      (magit-gh-repos ""))))
