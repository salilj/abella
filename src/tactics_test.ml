open OUnit
open Test_helper
open Term
open Metaterm
open Tactics
open Unify

let assert_object_cut ~cut ~using ~expect =
  let cut = parse_obj cut in
  let using = parse_obj using in
  let actual = object_cut cut using in
    assert_pprint_equal expect actual

let object_cut_tests =
  "Object Cut" >:::
    [
      "Simple" >::
        (fun () ->
           assert_object_cut
             ~cut:    "one |- two"
             ~using:  "one"
             ~expect: "{two}"
        );
      
      "Compound" >::
        (fun () ->
           assert_object_cut
             ~cut:    "eval A B |- typeof B C"
             ~using:  "eval A B"
             ~expect: "{typeof B C}"
        );

      "Contexts should be merged" >::
        (fun () ->
           assert_object_cut
             ~cut:    "L1, one |- two"
             ~using:  "L2 |- one"
             ~expect: "{L2, L1 |- two}"
        );

      "Context should be normalized" >::
        (fun () ->
           assert_object_cut
             ~cut:    "L, one |- two"
             ~using:  "L |- one"
             ~expect: "{L |- two}"
        );

      "Should fail on useless cut" >::
        (fun () ->
           assert_raises (Failure "Needless use of cut")
             (fun () ->
                object_cut (parse_obj "one |- two") (parse_obj "three")
             )
        );
    ]

    
let assert_object_inst ~on ~inst ~using ~expect =
  let on = freshen on in
  let using = var Eigen using 0 in
  let actual = object_inst on inst using in
    assert_pprint_equal expect actual

let object_instantiation_tests =
  "Object Instantiation" >:::
    [
      "Simple" >::
        (fun () ->
           assert_object_inst
             ~on:"{eval n1 B}"
             ~inst:"n1"
             ~using:"A"
             ~expect:"{eval A B}"
        );
      
      "Should fail if nominal is not found" >::
        (fun () ->
           assert_raises (Failure "Did not find n2")
             (fun () ->
                let dummy = var Eigen "dummy" 0 in
                  object_inst (freshen "{prove n1}") "n2" dummy
             )
        );

      "Should only work on nominals" >::
        (fun () ->
           assert_raises (Failure "Did not find A")
             (fun () ->
                let dummy = var Eigen "dummy" 0 in
                  object_inst (freshen "{prove A}") "A" dummy
             )
        );

    ]


let apply_tests =
  "Apply" >:::
    [
      "Normal" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B} -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Properly restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}* -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}*" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Needlessly restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B} -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}*" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;
      
      "Improperly restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}* -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Improperly restricted (2)" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}* -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}@" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Properly double restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}@ -> {typeof A C}** -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}@" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}**" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{typeof (abs R) (arrow S T)}" t) ;

      "Improperly double restricted" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}@ -> {typeof A C}** -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}@" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}@@" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Improperly double restricted (2)" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B}@ -> {typeof A C}** -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{typeof (abs R) (arrow S T)}**" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "Properly restricted on predicate" >::
        (fun () ->
           let h0 = freshen "forall A, foo A * -> bar A" in
           let h1 = freshen "foo A *" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "bar A" t) ;

      "Improperly restricted on predicate" >::
        (fun () ->
           let h0 = freshen "forall A, foo A * -> bar A" in
           let h1 = freshen "foo A @" in
             assert_raises (Failure "Inductive restriction violated")
               (fun () -> apply h0 [Some h1])) ;

      "Unification failure" >::
        (fun () ->
           let h0 = freshen
             "forall A B C, {eval A B} -> {typeof A C} -> {typeof B C}" in
           let h1 = freshen "{eval (abs R) (abs R)}" in
           let h2 = freshen "{bad (abs R) (arrow S T)}" in
           let clash = ConstClash (const "typeof", const "bad") in
             assert_raises (UnifyFailure clash)
               (fun () -> apply h0 [Some h1; Some h2])) ;

      "With contexts" >::
        (fun () ->
           let h0 = freshen
             ("forall E A C, {E, hyp A |- conc C} -> " ^
                "{E |- conc A} -> {E |- conc C}") in
           let h1 = freshen "{L, hyp A, hyp B1, hyp B2 |- conc C}" in
           let h2 = freshen "{L |- conc A}" in
           let t, _ = apply h0 [Some h1; Some h2] in
             assert_pprint_equal "{L, hyp B1, hyp B2 |- conc C}" t) ;

      "On non-object" >::
        (fun () ->
           let h0 = freshen "forall A, pred A -> result A" in
           let h1 = freshen "pred B" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "result B" t) ;

      "On arrow" >::
        (fun () ->
           let h0 = freshen "forall A, (forall B, foo A -> bar B) -> baz A" in
           let h1 = freshen "forall B, foo C -> bar B" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "baz C" t) ;

      "With nabla" >::
        (fun () ->
           let h0 = freshen "forall A B, nabla x, foo x A (B x) -> bar A B" in
           let h1 = freshen "foo n1 C (D n1)" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "bar C (x1\\D x1)" t) ;

      "With multiple nablas" >::
        (fun () ->
           let h0 =
             freshen "forall A B, nabla x y, foo x y (A x) (B y) -> bar A B"
           in
           let h1 = freshen "foo n1 n2 (C n1) (D n2)" in
           let t, _ = apply h0 [Some h1] in
             assert_pprint_equal "bar (x1\\C x1) (x1\\D x1)" t) ;

      "Absent argument should produce corresponding obligation" >::
        (fun () ->
           let h0 = freshen "forall L, ctx L -> {L |- pred} -> false" in
           let h1 = freshen "{L |- pred}" in
           let _, obligations = apply h0 [None; Some h1] in
             match obligations with
               | [term] ->
                   assert_pprint_equal "ctx L" term
               | _ -> assert_failure
                   ("Expected one obligation but found " ^
                      (string_of_int (List.length obligations)))) ;

      "Instantiate should not allow existing nominal" >::
        (fun () ->
           let h = freshen "nabla x, foo x n1" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", nominal_var "n1")]
               ));

      "Instantiate should not allow soon to be existing nominal" >::
        (fun () ->
           let h = freshen "forall E, nabla x, foo E x" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", nominal_var "n1");
                                       ("E", nominal_var "n1")]
               ));

      "Instantiate should not allow two identical nominals" >::
        (fun () ->
           let h = freshen "nabla x y, foo x y" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", nominal_var "n1");
                                       ("y", nominal_var "n1")]
               ));

      "Instantiate should allow distinct nominals" >::
        (fun () ->
           let h = freshen "nabla x y, foo x y" in
           let (t, _) = instantiate_withs h [("x", nominal_var "n1");
                                             ("y", nominal_var "n2")] in
             assert_pprint_equal "foo n1 n2" t);

      "Instantiate should not allow non-nominal for nabla" >::
        (fun () ->
           let h = freshen "nabla x, foo x" in
             assert_raises (Failure "Invalid instantiation for nabla variable")
               (fun () ->
                  instantiate_withs h [("x", const "A")]
               ));

      "Apply with no arguments" >::
        (fun () ->
           let h = freshen "forall E, foo E" in
           let a = const ~ts:0 "a" in
           let (t, _) = apply_with h [] [("E", a)] in
             assert_pprint_equal "foo a" t);

      "Apply with no arguments should contain about logic variables" >::
        (fun () ->
           let h = freshen "forall A B, foo A B" in
           let a = const ~ts:0 "a" in
           let (t, _) = apply_with h [] [("A", a)] in
           let logic_vars = metaterm_vars_alist Logic t in
             assert_bool "Should contain logic variable(s)"
               (List.length logic_vars > 0));

    ]

let assert_expected_cases n cases =
  assert_failure (Printf.sprintf "Expected %d case(s) but found %d case(s)"
                    n (List.length cases))

let case ?used ?(clauses=[]) ?(defs=[]) ?(global_support=[]) metaterm =
  let used =
    match used with
      | None -> metaterm_vars_alist Eigen metaterm
      | Some used -> used
  in
    case ~used ~clauses ~defs ~global_support metaterm
    
let case_tests =
  "Case" >:::
    [
      "Normal" >::
        (fun () ->
           let term = freshen "{eval A B}" in
             match case ~clauses:eval_clauses term with
               | [case1; case2] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "{eval (abs R) (abs R)}" term ;
                   assert_bool "R should be flagged as used"
                     (List.mem "R" (List.map fst case1.new_vars)) ;
                   
                   set_bind_state case2.bind_state ;
                   assert_pprint_equal "{eval (app M N) B}" term ;
                   begin match case2.new_hyps with
                     | [h1; h2] ->
                         assert_pprint_equal "{eval M (abs R)}" h1 ;
                         assert_pprint_equal "{eval (R N) B}" h2 ;
                     | _ -> assert_failure "Expected 2 new hypotheses"
                   end ;
                   assert_bool "R should be flagged as used"
                     (List.mem "R" (List.map fst case2.new_vars)) ;
                   assert_bool "M should be flagged as used"
                     (List.mem "M" (List.map fst case2.new_vars)) ;
                   assert_bool "N should be flagged as used"
                     (List.mem "N" (List.map fst case2.new_vars))
               | cases -> assert_expected_cases 2 cases) ;
      
      "Restriction should become smaller" >::
        (fun () ->
           let term = freshen "{foo A}@" in
           let clauses = parse_clauses "foo X :- bar X." in
             match case ~clauses term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "{bar A}*" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction on predicates should become smaller" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := foo X." in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "foo A *" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction should descend under binders" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := forall Y, foo X." in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "forall Y, foo A *" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction should descend only under the right of arrows" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := foo X -> foo X." in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "foo A -> foo A *" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "Restriction should only apply to matching predicates" >::
        (fun () ->
           let term = freshen "foo A @" in
           let defs = parse_defs "foo X := foo X \\/ bar X." in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   begin match case1.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "foo A * \\/ bar A" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 1 cases) ;

      "On OR" >::
        (fun () ->
           let term = freshen "{A} \\/ {B}" in
             match case term with
               | [{new_hyps=[hyp1]} ; {new_hyps=[hyp2]}] ->
                   assert_pprint_equal "{A}" hyp1 ;
                   assert_pprint_equal "{B}" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On multiple OR" >::
        (fun () ->
           let term = freshen "{A} \\/ {B} \\/ {C}" in
             match case term with
               | [{new_hyps=[hyp1]} ; {new_hyps=[hyp2]} ; {new_hyps=[hyp3]}] ->
                   assert_pprint_equal "{A}" hyp1 ;
                   assert_pprint_equal "{B}" hyp2 ;
                   assert_pprint_equal "{C}" hyp3 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On AND" >::
        (fun () ->
           let term = freshen "{A} /\\ {B}" in
             match case term with
               | [{new_hyps=[hyp1;hyp2]}] ->
                   assert_pprint_equal "{A}" hyp1 ;
                   assert_pprint_equal "{B}" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On multiple AND" >::
        (fun () ->
           let term = freshen "{A} /\\ {B} /\\ {C}" in
             match case term with
               | [{new_hyps=[hyp1;hyp2;hyp3]}] ->
                   assert_pprint_equal "{A}" hyp1 ;
                   assert_pprint_equal "{B}" hyp2 ;
                   assert_pprint_equal "{C}" hyp3 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On exists" >::
        (fun () ->
           let term = freshen "exists A B, {foo A B}" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"; "B"] var_names ;
                     assert_pprint_equal "{foo A B}" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nested exists, AND" >::
        (fun () ->
           let term = freshen "exists A B, {foo A} /\\ {bar B}" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp1; hyp2]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"; "B"] var_names ;
                     assert_pprint_equal "{foo A}" hyp1 ;
                     assert_pprint_equal "{bar B}" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nested AND, exists" >::
        (fun () ->
           let term = freshen "{foo} /\\ exists A, {bar A}" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp1; hyp2]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"] var_names ;
                     assert_pprint_equal "{foo}" hyp1 ;
                     assert_pprint_equal "{bar A}" hyp2 ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nabla" >::
        (fun () ->
           let term = freshen "nabla x, foo x" in
           let used = [] in
             match case ~used term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "foo n1" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On multiple nablas" >::
        (fun () ->
           let term = freshen "nabla x y, foo x y" in
           let used = [] in
             match case ~used term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "foo n1 n2" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nested nabla, exists" >::
        (fun () ->
           let term = freshen "nabla x, exists A B, {foo A B x}" in
           let used = [] in
             match case ~used term with
               | [{new_vars=new_vars ; new_hyps=[hyp]}] ->
                   let var_names = List.map fst new_vars in
                     assert_string_list_equal ["A"; "B"] var_names ;
                     assert_pprint_equal "{foo (A n1) (B n1) n1}" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "On nabla with n1 used" >::
        (fun () ->
           let term = freshen "nabla x, foo n1 x" in
           let used = [] in
             match case ~used term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "foo n1 n2" hyp ;
               | _ -> assert_failure "Pattern mismatch") ;

      "Should look in context for member" >::
        (fun () ->
           let term = freshen "{L, hyp A |- hyp B}" in
             match case term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "member (hyp B) (hyp A :: L)" hyp
               | _ -> assert_failure "Pattern mismatch") ;

      "Member case should not get restriction from object" >::
        (fun () ->
           let term = freshen "{L |- foo A}@" in
             match case term with
               | [{new_vars=[] ; new_hyps=[hyp]}] ->
                   assert_pprint_equal "member (foo A) L" hyp
               | _ -> assert_failure "Pattern mismatch") ;

      "Should pass along context" >::
        (fun () ->
           let term = freshen "{L |- foo A}" in
           let clauses = parse_clauses "foo X :- bar X." in
             match case ~clauses term with
               | [case1; case2] ->
                   (* case1 is the member case *)
                   
                   set_bind_state case2.bind_state ;
                   begin match case2.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "{L |- bar A}" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end ;
               | cases -> assert_expected_cases 3 cases) ;

      "On member" >::
        (fun () ->
           let term = freshen "member (hyp A) (hyp C :: L)" in
           let defs =
             parse_defs ("member A (A :: L)." ^
                                   "member A (B :: L) := member A L.")
           in
             match case ~defs term with
               | [case1; case2] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "member (hyp C) (hyp C :: L)" term ;

                   set_bind_state case2.bind_state ;
                   begin match case2.new_hyps with
                     | [hyp] ->
                         assert_pprint_equal "member (hyp A) L" hyp ;
                     | _ -> assert_failure "Expected 1 new hypothesis"
                   end
               | cases -> assert_expected_cases 2 cases) ;

      "On exists should raise over support" >::
        (fun () ->
           let term = freshen "exists A, {foo A n1}" in
           let used = [] in
             match case ~used term with
               | [{new_hyps=[hyp]}] ->
                   assert_pprint_equal "{foo (A n1) n1}" hyp
               | _ -> assert_failure "Pattern mismatch") ;

      "Should raise over nominal variables in definitions" >::
        (fun () ->
           let defs = parse_defs "pred M N." in
           let term = freshen "pred (A n1) B" in
             match case ~defs term with
               | [case1] -> ()
               | cases -> assert_expected_cases 1 cases) ;
             
      "Should raise over nominal variables in clauses" >::
        (fun () ->
           let clauses = parse_clauses "pred M N." in
           let term = freshen "{pred (A n1) B}" in
             match case ~clauses term with
               | [case1] -> ()
               | cases -> assert_expected_cases 1 cases) ;

      "Should raise when nabla in predicate head" >::
        (fun () ->
           let defs =
             parse_defs "nabla x, ctx (var x :: L) := ctx L." in
           let term = freshen "ctx K" in
             match case ~defs term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "ctx (var n1 :: L)" term
               | cases -> assert_expected_cases 1 cases) ;
             
      "Should permute when nabla is in the head" >::
        (fun () ->
           let defs =
             parse_defs "nabla x, ctx (var x :: L) := ctx L." in
           let term = freshen "ctx (K n2)" in
           let global_support = [nominal_var "n2"] in
             match case ~defs ~global_support term with
               | [case1; case2] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "ctx (var n1 :: L n2)" term ;

                   set_bind_state case2.bind_state ;
                   assert_pprint_equal "ctx (var n2 :: L)" term
               | cases -> assert_expected_cases 2 cases) ;

      "With multiple nabla in the head" >::
        (fun () ->
           let defs =
             parse_defs "nabla x y, ctx (pair x y :: L) := ctx L." in
           let term = freshen "ctx (K n2)" in
           let global_support = [nominal_var "n2"] in
             match case ~defs ~global_support term with
               | [case1; case2; case3] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "ctx (pair n1 n3 :: L n2)" term ;

                   set_bind_state case2.bind_state ;
                   assert_pprint_equal "ctx (pair n1 n2 :: L)" term ;
                     
                   set_bind_state case3.bind_state ;
                   assert_pprint_equal "ctx (pair n2 n1 :: L)" term ;
               | cases -> assert_expected_cases 3 cases) ;
      
      "Should not use existing nabla variables as fresh" >::
        (fun () ->
           let defs = parse_defs "nabla x, name x." in
           let term = freshen "name A" in
           let global_support = [nominal_var "n1"] in
             match case ~defs ~global_support term with
               | [case1] ->
                   set_bind_state case1.bind_state ;
                   assert_pprint_equal "name n2" term
               | cases -> assert_expected_cases 1 cases) ;

      "Should not apply to coinductive restriction" >::
        (fun () ->
           let term = freshen "foo A +" in
             assert_raises
               (Failure "Cannot case analyze hypothesis\
                         \ with coinductive restriction")
               (fun () -> case term)) ;

    ]

let induction_tests =
  "Induction" >:::
    [
      "Single" >::
        (fun () ->
           let stmt = freshen
               "forall A, {first A} -> {second A} -> {third A}" in
           let (ih, goal) = single_induction 1 1 stmt in
             assert_pprint_equal
               "forall A, {first A}* -> {second A} -> {third A}"
               ih ;
             assert_pprint_equal
               "forall A, {first A}@ -> {second A} -> {third A}"
               goal) ;
      
      "Nested" >::
        (fun () ->
           let stmt = freshen
               "forall A, {first A} -> {second A} -> {third A}" in
           let (ih, goal) = single_induction 1 1 stmt in
             assert_pprint_equal
               "forall A, {first A}* -> {second A} -> {third A}" ih ;
             assert_pprint_equal
               "forall A, {first A}@ -> {second A} -> {third A}" goal ;
             let (ih, goal) = single_induction 2 2 goal in
               assert_pprint_equal
                 "forall A, {first A}@ -> {second A}** -> {third A}" ih ;
               assert_pprint_equal
                 "forall A, {first A}@ -> {second A}@@ -> {third A}" goal) ;
      
      "With OR on left of arrow" >::
        (fun () ->
           let stmt = freshen "forall X, {A} \\/ {B} -> {C} -> {D}" in
           let (ih, goal) = single_induction 2 1 stmt in
             assert_pprint_equal
               "forall X, {A} \\/ {B} -> {C}* -> {D}"
               ih ;
             assert_pprint_equal
               "forall X, {A} \\/ {B} -> {C}@ -> {D}"
               goal) ;
      
      "On predicate" >::
        (fun () ->
           let stmt = freshen
             "forall A, first A -> second A -> third A" in
           let (ih, goal) = single_induction 1 1 stmt in
             assert_pprint_equal
               "forall A, first A * -> second A -> third A"
               ih ;
             assert_pprint_equal
               "forall A, first A @ -> second A -> third A"
               goal) ;
      
      "Mutual on objects" >::
        (fun () ->
           let stmt = freshen
             "(forall A, {one A} -> {two A} -> {three A}) /\\
              (forall B, {four B} -> {five B})" in
             match induction [2; 1] 1 stmt with
               | [ih1; ih2], goal ->
                  assert_pprint_equal
                    "forall A, {one A} -> {two A}* -> {three A}"
                    ih1 ;
                   assert_pprint_equal
                     "forall B, {four B}* -> {five B}"
                     ih2 ;
                   assert_pprint_equal
                     ("(forall A, {one A} -> {two A}@ -> {three A}) /\\ " ^
                        "(forall B, {four B}@ -> {five B})")
                     goal
               | _ -> failwith "Expected 2 inductive hypotheses")
    ]

let coinduction_tests =
  "CoInduction" >:::
    [
      "Single" >::
        (fun () ->
           let stmt = freshen "forall A, first A -> second A -> third A" in
           let (ch, goal) = coinduction 1 stmt in
             assert_pprint_equal
               "forall A, first A -> second A -> third A +"
               ch ;
             assert_pprint_equal
               "forall A, first A -> second A -> third A @"
               goal) ;
      
    ]


let assert_search ?(clauses="") ?(defs="")
    ?(hyps=[]) ~goal ~expect () =
  let depth = 5 in
  let clauses = parse_clauses clauses in
  let defs = parse_defs defs in
  let hyps = List.map freshen hyps in
  let goal = freshen goal in
  let actual = search ~depth ~hyps ~clauses ~defs goal in
    if expect then
      assert_bool "Search should succeed" actual
    else
      assert_bool "Search should fail" (not actual)

let search_tests =
  "Search" >:::
    [
      "Should check hypotheses" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B}"]
             ~goal:"{eval A B}"
             ~expect: true
        );
      
      "Should should succeed if clause matches" >::
        (fun () ->
           assert_search ()
             ~clauses:eval_clauses_string
             ~goal:"{eval (abs R) (abs R)}"
             ~expect: true
        );
      
      "Should backchain on clauses" >::
        (fun () ->
           assert_search ()
             ~clauses:"foo X :- bar X, baz X."
             ~hyps:["{bar A}"; "{baz A}"]
             ~goal:"{foo A}"
             ~expect: true
        );

      "On left of OR" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B}"]
             ~goal:"{eval A B} \\/ false"
             ~expect: true
        );
      
      "On right of OR" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B}"]
             ~goal:"false \\/ {eval A B}"
             ~expect: true
        );

      "On AND" >::
        (fun () ->
           assert_search ()
             ~hyps:["{one}"; "{two}"]
             ~goal:"{one} /\\ {two}"
             ~expect: true
        );

      "On AND (failure)" >::
        (fun () ->
           assert_search ()
             ~hyps:["{one}"]
             ~goal:"{one} /\\ {two}"
             ~expect: false
        );

      "On exists" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists R, {eq (app M N) R}"
             ~expect: true
        );

      "On exists (double)" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists R1 R2, {eq (app M N) (app R1 R2)}"
             ~expect: true
        );

      "On exists (failure)" >::
        (fun () ->
           assert_search ()
             ~clauses:"eq X X."
             ~goal:"exists R, {eq (app M N) (app R R)}"
             ~expect: false
        );

      "Should use meta unification" >::
        (fun () ->
           assert_search ()
             ~hyps:["{A} /\\ {B}"]
             ~goal:"{A} /\\ {B}"
             ~expect: true
        );
      
      "Should fail if there is no proof" >::
        (fun () ->
           assert_search ()
             ~clauses:eval_clauses_string
             ~goal:"{eval A B}"
             ~expect: false
        );
      
      "Should fail if hypothesis has non-subcontext" >::
        (fun () ->
           assert_search ()
             ~hyps:["{eval A B |- eval A B}"]
             ~goal:"{eval A B}"
             ~expect: false
        );

      "Should preserve context while backchaining" >::
        (fun () ->
           assert_search ()
             ~clauses:eval_clauses_string
             ~defs:"member A (A :: L). member A (B :: L) := member A L."
             ~goal:"{eval M (abs R), eval (R N) V |- eval (app M N) V}"
             ~expect: true
        );

      "Should move implies to the left" >::
        (fun () ->
           assert_search ()
             ~hyps:["{one |- two}"]
             ~goal:"{one => two}"
             ~expect: true
        );

      "Should replace pi x\\ with nominal variable" >::
        (fun () ->
           assert_search ()
             ~hyps:["{pred n1 n1}"]
             ~goal:"{pi x\\ pred x x}"
             ~expect: true
        );

      "Should look for member" >::
        (fun () ->
           assert_search ()
             ~hyps:["member (hyp A) L"]
             ~goal:"{L |- hyp A}"
             ~expect: true
        );

      "On nablas" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo n1 n2"]
             ~goal:"nabla x y, foo x y"
             ~expect: true
        );

      "Should backchain on definitions" >::
        (fun () ->
           assert_search ()
             ~defs:"member A (B :: L) := member A L."
             ~hyps:["member E K"]
             ~goal:"member E (F :: K)"
             ~expect: true
        );

      "Should undo partial results in favor of overall goal" >::
        (fun () ->
           assert_search ()
             ~hyps:["one A"; "one B"; "two B"]
             ~goal:"exists X, one X /\\ two X"
             ~expect:true
        );

      "Should raise definitions over support" >::
        (fun () ->
           assert_search ()
             ~defs:"foo X."
             ~goal:"foo (A n1)"
             ~expect: true
        );

      "Should raise object clauses over support" >::
        (fun () ->
           assert_search ()
             ~clauses:"foo X."
             ~goal:"{foo (A n1)}"
             ~expect: true
        );

      "Should raise exists over support" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo n1 n1"]
             ~goal:"exists X, foo n1 X"
             ~expect: true
        );

      "Should work with nabla in the head" >::
        (fun () ->
           assert_search ()
             ~defs:"nabla x, ctx (var x :: L) := ctx L."
             ~hyps:["ctx L"]
             ~goal:"ctx (var n1 :: L)"
             ~expect: true
        );

      "Should work with nabla in the head despite nominal name" >::
        (fun () ->
           assert_search ()
             ~defs:"nabla x, ctx (var x :: L) := ctx L."
             ~hyps:["ctx L"]
             ~goal:"ctx (var n2 :: L)"
             ~expect: true
        );

      "Should work with multiple nabla in the head" >::
        (fun () ->
           assert_search ()
             ~defs:"nabla x y, ctx (pair x y :: L) := ctx L."
             ~hyps:["ctx L"]
             ~goal:"ctx (pair n3 n2 :: L)"
             ~expect: true
        );
      
      "Should permute nominal constants" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo n1"]
             ~goal:"foo n2"
             ~expect: true
        );

      "Should permute nominal constants in derivability" >::
        (fun () ->
           assert_search ()
             ~hyps:["{L, hyp n1 |- foo n2}"]
             ~goal:"{L, hyp n2, hyp n3 |- foo n2}"
             ~expect:true
        );

      "Should delay non-llambda pairs for clauses - simple" >::
        (fun () ->
           assert_search ()
             ~hyps:["{pr t1 (abs t3)}"; "{pr t2 t4}"]
             ~goal:"{pr (app t1 t2) (t3 t4)}"
             ~clauses:"pr (app A B) (C D) :- pr A (abs C), pr B D."
             ~expect:true
        );

      "Should delay non-llambda pairs for clauses - complex" >::
        (fun () ->
           assert_search ()
             ~hyps:["{pr t1 (abs (t3 t4))}"; "{pr t2 (t5 t6)}"]
             ~goal:"{pr (app t1 t2) (t3 t4 (t5 t6))}"
             ~clauses:"pr (app A B) (C D) :- pr A (abs C), pr B D."
             ~expect:true
        );

      "Should delay non-llambda pairs for defs - simple" >::
        (fun () ->
           assert_search ()
             ~hyps:["pr t1 (abs t3)"; "pr t2 t4"]
             ~goal:"pr (app t1 t2) (t3 t4)"
             ~defs:"pr (app A B) (C D) := pr A (abs C) /\\ pr B D."
             ~expect:true
        );

      "Should not match co-restricted hypothesis (1)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A +"]
             ~goal:"foo A"
             ~expect:false
        );

      "Should not match co-restricted hypothesis (2)" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A +"]
             ~goal:"foo A @"
             ~expect:false
        );

      "Should match co-restricted hypothesis after unfolding" >::
        (fun () ->
           assert_search ()
             ~hyps:["foo A +"]
             ~goal:"foo (s A) @"
             ~defs:"foo (s X) := foo X."
             ~expect:true
        );

    ]

    
let unfold_tests =
  "Unfold" >:::
    [
      "Should pick matching clause" >::
        (fun () ->
           let defs =
             parse_defs "pred (f X) := foo X. pred (g X) := bar X."
           in
           let goal = freshen "pred (g a)" in
           let result = unfold ~defs goal in
             assert_pprint_equal "bar a" result) ;

      "Should work with nominals" >::
        (fun () ->
           let defs = parse_defs "pred X := foo X." in
           let goal = freshen "pred (f n1)" in
           let result = unfold ~defs goal in
             assert_pprint_equal "foo (f n1)" result) ;

      "Should avoid variable capture" >::
        (fun () ->
           let defs = parse_defs "pred X := forall A, foo X A." in
           let goal = freshen "pred A" in
           let result = unfold ~defs goal in
             assert_pprint_equal "forall A1, foo A A1" result) ;

      "Should work on nabla in the head (permute)" >::
        (fun () ->
           let defs = parse_defs "nabla x, foo x Z := bar Z." in
           let goal = freshen "foo n1 D" in
           let result = unfold ~defs goal in
             assert_pprint_equal "bar D" result) ;

      "Should reduce coinductive restriction" >::
        (fun () ->
           let defs = parse_defs "foo X := foo X." in
           let goal = freshen "foo D @" in
           let result = unfold ~defs goal in
             assert_pprint_equal "foo D +" result) ;

      "Should not reduce restriction for different signature" >::
        (fun () ->
           let defs = parse_defs "foo X := bar X." in
           let goal = freshen "foo D @" in
           let result = unfold ~defs goal in
             assert_pprint_equal "bar D" result) ;

    ]

    
let tests =
  "Tactics" >:::
    [
      object_cut_tests ;
      object_instantiation_tests ;
      apply_tests ;
      case_tests ;
      induction_tests ;
      coinduction_tests ;
      search_tests ;
      unfold_tests ;
    ]
    
