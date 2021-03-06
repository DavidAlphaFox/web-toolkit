(in-package :uri-test)

(in-suite :uri-test)

(test percent-decode
  (is (equal nil (uri::percent-decode nil)))
  (is (equal "c" (uri::percent-decode "%63")))
  (is (equal "abc" (uri::percent-decode "ab%63")))
  (is (equal "❤" (uri::percent-decode "%E2%9D%A4")))
  (is (equal "爱" (uri::percent-decode "%E7%88%B1")))
  (is (equal "爱" (uri::percent-decode "爱")))
  (is (equal " " (uri::percent-decode "%20")))
  (is (equal "+" (uri::percent-decode "+"))))

(test percent-decode-bad
  (finishes (uri::percent-decode "%b6%e0%b3%a1%f1%ee%ba%cf%cf%c2%b6%fe%d1%f5%bb%af%cc%bc%d1%b9%c1%d1%c1%f7%b6%af%b4%ab%c8%c8%d3%eb%d1%d2%ca%af%cb%f0%c9%cb%cc%d8%d0%d4%d1%d0%be%bf_%c0%ee%d0%a1%bd%ad"))
  (signals error (uri::percent-decode "%%20")))
