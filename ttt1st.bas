E000R
1 goto 600

10 w = z(1) : if (w=z(2) and w=z(3)) or (w=z(4) and w=z(7)) or (w=z(5) and w=z(9)) then return
11 w = 0 : return
20 w = z(2) : if (w=z(1) and w=z(3)) or (w=z(5) and w=z(8)) then return
21 w = 0 : return
30 w = z(3) : if (w=z(1) and w=z(2)) or (w=z(6) and w=z(9)) or (w=z(5) and w=z(7)) then return
31 w = 0 : return
40 w = z(4) : if (w=z(1) and w=z(7)) or (w=z(5) and w=z(6)) then return
41 w = 0 : return
50 w = z(5) : if (w=z(2) and w=z(8)) or (w=z(1) and w=z(9)) or (w=z(3) and w=z(7)) or (w=z(4) and w=z(6)) then return
51 w = 0 : return
60 w = z(6) : if (w=z(3) and w=z(9)) or (w=z(4) and w=z(5)) then return
61 w = 0 : return
70 w = z(7) : if (w=z(1) and w=z(4)) or (w=z(8) and w=z(9)) or (w=z(3) and w=z(5)) then return
71 w = 0 : return
80 w = z(8) : if (w=z(7) and w=z(9)) or (w=z(2) and w=z(5)) then return
81 w = 0 : return
90 w = z(9) : if (w=z(3) and w=z(6)) or (w=z(7) and w=z(8)) or (w=z(1) and w=z(5)) then return
91 w = 0 : return

400 d = 0 : i = 1 : v = 0 : r = 0
410 m = m + 1 : if d < 4 then 419 : gosub ( 10 * p )
415 if 0 = w then 418 : if w = 1 then r = 6 : if w = 1 then 434 : r = 4 : goto 434
418 if d = 8 then r = 5 : if d = 8 then 434
419 if i = 0 then v = 2 : if i = 0 then 421 : v = 9
421 p = 1
425 if 0 # z(p) then 460 : z(p) = i + 1
428 d1 = d + 1 : s1(d1) = p : s2(d1) = v : s4(d1) = a : s8(d1) = b : s6(d1) = i
430 i = not i : d = d + 1 : goto 410
434 d1 = d : d = d - 1 : i = s6(d1) : p = s1(d1) : v = s2(d1) : a = s4(d1) : b = s8(d1) : z(p) = 0
438 if i = 0 then 450 : if r = 4 then 490 : if r < v then v = r : if v < b then b = v
442 if b <= a then 480 : goto 460
450 if r = 6 then 490 : if r > v then v = r : if v > a then a = v : if a >= b then 480
460 p = p + 1 : if p < 10 then 425
480 r = v
490 if d = 0 then return : goto 434

600 rem Apple 1 Basic version of app to prove you can't win at tic-tac-toe
603 dim z(9), s1(10), s2(10), s4(10), s8(10), s6(10)
608 m = 0
610 for i = 1 to 9
620 z(i) = 0 : next i
640 for l = 1 to 1
641 m = 0 : a = 2 : b = 9 : z(1) = 1
645 gosub 400
658 rem a = 2 : b = 9 : z(1) = 0 : z(2) = 1
662 rem gosub 400
668 rem a = 2 : b = 9 : z(2) = 0 : z(5) = 1
672 rem gosub 400
673 z(5) = 0
680 next l
687 print "final move count (6493 or 1903 expected): "; m
688 print "iterations: "; l - 1
689 print "$"
699 end

RUN

