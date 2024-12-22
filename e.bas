E000R
rem 271828182845904523536028747
10 h = 35 : dim a(h) : x = 0 : n = h
16 a(n) = 1 : n = n - 1 : if n > 2 then 16
20 a(2) = 2 : a(1) = 0
23 h = h - 1 : n = h
25 a(n+1) = x mod n : x = ( 10 * a(n) ) + ( x / n ) : n = n - 1 : if n > 0 then 25
30 print x; : if h > 9 then 23
40 print "" : print "done" : end
RUN



