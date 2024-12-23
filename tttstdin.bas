E000R

20 m = m + 1 : if d < 4 then 24 : gosub ( p + 60 ) : if not w then 22 : r = 4 : if w = 1 then r = 6 : goto 28
22 if d = 8 then r = 5 : if d = 8 then 28
24 if not i then v = 2 : if i then v = 9 : p = 1
26 if z(p) then 34 : z(p) = i + 1 : d = d + 1 : s1(d) = p : s2(d) = v : s3(d) = a : s4(d) = b : i = not i : goto 20
28 i = not i : p = s1(d) : v = s2(d) : a = s3(d) : b = s4(d) : z(p) = 0 : d = d - 1
30 if not i then 32 : if r = 4 then 38 : if r < v then v = r : if v < b then b = v : if b <= a then 36 : goto 34
32 if r = 6 then 38 : if r > v then v = r : if v > a then a = v : if a >= b then 36
34 p = p + 1 : if p < 10 then 26
36 r = v
38 if not d then return : goto 28

61 w = z(1) : if (w#z(2) or w#z(3)) and (w#z(4) or w#z(7)) and (w#z(5) or w#z(9)) then w = 0 : return
62 w = z(2) : if (w#z(1) or w#z(3)) and (w#z(5) or w#z(8)) then w = 0 : return
63 w = z(3) : if (w#z(1) or w#z(2)) and (w#z(6) or w#z(9)) and (w#z(5) or w#z(7)) then w = 0 : return
64 w = z(4) : if (w#z(1) or w#z(7)) and (w#z(5) or w#z(6)) then w = 0 : return
65 w = z(5) : if (w#z(2) or w#z(8)) and (w#z(1) or w#z(9)) and (w#z(3) or w#z(7)) and (w#z(4) or w#z(6)) then w = 0 : return
66 w = z(6) : if (w#z(3) or w#z(9)) and (w#z(4) or w#z(5)) then w = 0 : return
67 w = z(7) : if (w#z(1) or w#z(4)) and (w#z(8) or w#z(9)) and (w#z(3) or w#z(5)) then w = 0 : return
68 w = z(8) : if (w#z(7) or w#z(9)) and (w#z(2) or w#z(5)) then w = 0 : return
69 w = z(9) : if (w#z(3) or w#z(6)) and (w#z(7) or w#z(8)) and (w#z(1) or w#z(5)) then w = 0 : return

70 a = 2 : b = 9 : d = 0 : i = 1 : v = 0 : r = 0
71 gosub 20 : return

80 rem Apple 1 Basic version of app to prove you can't win at tic-tac-toe
81 dim z(9), s1(9), s2(9), s3(9), s4(9)
82 for i = 1 to 9
83     z(i) = 0 : next i
85 m = 0
86 z(1) = 1 : gosub 70 : z(1) = 0
87 z(2) = 1 : gosub 70 : z(2) = 0
88 z(5) = 1 : gosub 70 : z(5) = 0
90 print "final move count (6493 or 1903 expected): "; m; "$"
99 end

RUN 80

