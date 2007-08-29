type top.
type (arrow A B) :- type A, type B.

term (app M N) :- term M, term N.
term (abs R) :- pi x\ term x => term (R x).

typeof (abs R) (arrow T U) :- pi x\ (typeof x T => typeof (R x) U).
typeof (app M N) T :- typeof M (arrow U T), typeof N U.

value (abs R).

step (app (abs R) M) (R M) :- value M.
step (app M N) (app M' N) :- step M M'.
step (app M N) (app M N') :- value M, step N N'.

nstep A A.
nstep A C :- step A B, nstep B C.