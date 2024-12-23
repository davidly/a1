E000R

1 w = z(1) : if (w#z(2) or w#z(3)) and (w#z(4) or w#z(7)) and (w#z(5) or w#z(9)) then w = 0 : return
2 w = z(2) : if (w#z(1) or w#z(3)) and (w#z(5) or w#z(8)) then w = 0 : return
3 w = z(3) : if (w#z(1) or w#z(2)) and (w#z(6) or w#z(9)) and (w#z(5) or w#z(7)) then w = 0 : return
4 w = z(4) : if (w#z(1) or w#z(7)) and (w#z(5) or w#z(6)) then w = 0 : return
5 w = z(5) : if (w#z(2) or w#z(8)) and (w#z(1) or w#z(9)) and (w#z(3) or w#z(7)) and (w#z(4) or w#z(6)) then w = 0 : return
6 w = z(6) : if (w#z(3) or w#z(9)) and (w#z(4) or w#z(5)) then w = 0 : return
7 w = z(7) : if (w#z(1) or w#z(4)) and (w#z(8) or w#z(9)) and (w#z(3) or w#z(5)) then w = 0 : return
8 w = z(8) : if (w#z(7) or w#z(9)) and (w#z(2) or w#z(5)) then w = 0 : return
9 w = z(9) : if (w#z(3) or w#z(6)) and (w#z(7) or w#z(8)) and (w#z(1) or w#z(5)) then w = 0 : return

400 m = m + 1 : if d < 4 then 415 : gosub p
405 if not w then 410 : if w = 1 then r = 6 : if w = 1 then 434 : r = 4 : goto 434
410 if d = 8 then r = 5 : if d = 8 then 434
415 if not i then v = 2 : if not i then 420 : v = 9
420 p = 1
425 if z(p) then 460 : z(p) = i + 1
428 d = d + 1 : s1(d) = p : s2(d) = v : s3(d) = a : s4(d) = b : i = not i : goto 400
434 i = not i : p = s1(d) : v = s2(d) : a = s3(d) : b = s4(d) : z(p) = 0 : d = d - 1
438 if not i then 450 : if r = 4 then 490 : if r < v then v = r : if v < b then b = v
442 if b <= a then 480 : goto 460
450 if r = 6 then 490 : if r > v then v = r : if v > a then a = v : if a >= b then 480
460 p = p + 1 : if p < 10 then 425
480 r = v
490 if not d then return : goto 434

500 a = 2 : b = 9
510 d = 0 : i = 1 : v = 0 : r = 0
520 gosub 400
530 return

600 rem Apple 1 Basic version of app to prove you can't win at tic-tac-toe
603 dim z(9), s1(9), s2(9), s3(9), s4(9)
608 m = 0
610 for i = 1 to 9
620     z(i) = 0 : next i
640 for l = 1 to 1
642     m = 0
645     z(1) = 1 : gosub 500 : z(1) = 0
650     rem z(2) = 1 : gosub 500 : z(2) = 0
655     rem z(5) = 1 : gosub 500 : z(5) = 0
660 next l
665 print "final move count (6493 or 1903 expected): "; m
670 print "iterations: "; l - 1
675 print "$"
699 end

RUN 600

