open Term

type restriction =
  | Smaller of int
  | Equal of int
  | Irrelevant

type obj = { context : Context.t ;
             term : term }
    
type lppterm =
  | Obj of obj * restriction
  | Arrow of lppterm * lppterm
  | Forall of id list * lppterm
  | Exists of id list * lppterm
  | Or of lppterm * lppterm
  | Pred of term

(* Constructions *)

let context_obj ctx t = { context = ctx ; term = t }
let obj t = { context = Context.empty ; term = t }

let termobj t = Obj(obj t, Irrelevant)
let arrow a b = Arrow(a, b)
let forall ids t = Forall(ids, t)
let exists ids t = Exists(ids, t)
let lpp_or a b = Or(a, b)

let member e ctx = Pred (app (Term.const "member") [e; ctx])
  
(* Manipulations *)

let obj_to_member obj =
  member obj.term (Context.context_to_term obj.context)

let rec filter_objs ts =
  match ts with
    | [] -> []
    | Obj(obj, _)::rest -> obj::(filter_objs rest)
    | _::rest -> filter_objs rest

let rec filter_preds ts =
  match ts with
    | [] -> []
    | Pred(p)::rest -> p::(filter_preds rest)
    | _::rest -> filter_preds rest

let term_to_obj t =
  match t with
    | Obj(obj, _) -> obj
    | _ -> failwith "term_to_obj called on non-object"
  
let apply_restriction r t =
  match t with
    | Obj(obj, _) -> Obj(obj, r)
    | _ -> failwith "Attempting to apply restriction to non-object"

let reduce_restriction r =
  match r with
    | Irrelevant -> Irrelevant
    | Equal i -> Smaller i
    | Smaller i -> Smaller i
        
let add_to_context elt obj =
  {obj with context = Context.add elt obj.context}

let add_context ctx obj =
  {obj with context = Context.union ctx obj.context}

let map_objs f t =
  let rec aux t =
    match t with
      | Obj(obj, r) -> Obj(f obj, r)
      | Arrow(a, b) -> Arrow(aux a, aux b)
      | Forall(bindings, body) -> Forall(bindings, aux body)
      | Exists(bindings, body) -> Exists(bindings, aux body)
      | Or(a, b) -> Or(aux a, aux b)
      | Pred _ -> t
  in
    aux t

let rec collect_terms t =
  match t with
    | Obj(obj, r) -> (Context.context_to_list obj.context) @ [obj.term]
    | Arrow(a, b) -> (collect_terms a) @ (collect_terms b)
    | Forall(bindings, body) -> collect_terms body
    | Exists(bindings, body) -> collect_terms body
    | Or(a, b) -> (collect_terms a) @ (collect_terms b)
    | Pred p -> [p]

let map_term_list f t = List.map f (collect_terms t)

let normalize_contexts t =
  map_objs (fun obj -> {obj with context = Context.normalize obj.context}) t

(* Variable Renaming *)

let remove_assoc_list to_remove alist =
  let rec aux alist =
    match alist with
      | (a, b)::rest ->
          if List.mem a to_remove
          then aux rest
          else (a, b)::(aux rest)
      | [] -> []
  in
    aux alist
      
let replace_term_vars alist t =
  let rec aux t =
    match observe t with
        | Var {name=name} when List.mem_assoc name alist ->
            List.assoc name alist
        | Var _
        | DB _ -> t
        | Lam(i, t) -> lambda i (aux t)
        | App(t, ts) -> app (aux t) (List.map aux ts)
        | Susp _ -> failwith "Susp found during replace_term_vars"
        | Ptr _ -> assert false
  in
    aux t

let replace_obj_vars alist obj =
  let aux t = replace_term_vars alist t in
    { context = Context.map aux obj.context ;
      term = aux obj.term }
      
let rec replace_lppterm_vars alist t =
  let aux t = replace_lppterm_vars alist t in
    match t with
      | Obj(obj, r) -> Obj(replace_obj_vars alist obj, r)
      | Arrow(a, b) -> Arrow(aux a, aux b)
      | Forall _ -> failwith "Cannot replace vars inside forall"
      | Exists(bindings, body) ->
          let alist' = remove_assoc_list bindings alist in
          let body' = replace_lppterm_vars alist' body in
            Exists(bindings, body')
      | Or(a, b) -> Or(aux a, aux b)
      | Pred(p) -> Pred(replace_term_vars alist p)

      
(* Pretty printing *)

let restriction_to_string r =
  match r with
    | Smaller i -> String.make i '*'
    | Equal i -> String.make i '@'
    | Irrelevant -> ""

let bindings_to_string ts =
  String.concat " " ts

let priority t =
  match t with
    | Obj _ -> 3
    | Pred _ -> 3
    | Or _ -> 2
    | Arrow _ -> 1
    | Forall _ -> 0
    | Exists _ -> 0

let obj_to_string obj =
  let context =
    if Context.is_empty obj.context
    then ""
    else (Context.context_to_string obj.context ^ " |- ")
  in
  let term = term_to_string obj.term in
    "{" ^ context ^ term ^ "}"
    
let lppterm_to_string t =
  let rec aux pr_above t =
    let pr_curr = priority t in
    let pp =
      match t with
        | Obj(obj, r) -> (obj_to_string obj) ^ (restriction_to_string r)
        | Arrow(a, b) ->
            (aux (pr_curr + 1) a) ^ " -> " ^ (aux pr_curr b)
        | Forall(ids, t) ->
            "forall " ^ (bindings_to_string ids) ^ ", " ^ (aux pr_curr t)
        | Exists(ids, t) ->
            "exists " ^ (bindings_to_string ids) ^ ", " ^ (aux pr_curr t)
        | Or(a, b) ->
            (aux pr_curr a) ^ " or " ^ (aux (pr_curr + 1) b)
        | Pred(p) -> term_to_string p
    in
      if pr_curr >= pr_above then pp else "(" ^ pp ^ ")"
  in
    aux 0 t


(* Error reporting *)

let invalid_lppterm_arg t =
  invalid_arg (lppterm_to_string t)

