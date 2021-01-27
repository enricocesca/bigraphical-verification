open Logic

let genid =
  let r = ref 0 in
  fun () ->
    let res = string_of_int !r in
    r := !r + 1;
    res

let genids formals =
  List.map (fun formal -> (formal,genid())) formals

type ide = string
type propsyn = string
type model =
    MODEL of (string*string*string) (* Kripke, Space, Eval *)
  | URI of string
      
type fsyn =
    TRUE
  | FALSE
  | NOT of fsyn
  | AND of (fsyn * fsyn)
  | OR of (fsyn * fsyn)
  | PROP of propsyn
  | VPROP of propsyn * string * float
  | NEAR of fsyn
  | NEARN of (int * fsyn)
  | INT of fsyn
  | INTN of (int * fsyn)
  | SURROUNDED of (fsyn * fsyn)
  | CALL of ide * (fsyn list)		    
  | STATCMP of (string * fsyn * string * fsyn * float * string * float * float * float * int)
  (* atom fmla atom fmla radius operator threshold bin_min bin_max nbins *)
  | SCMPIMA of (string * string * fsyn * float * string * float * float * float * int)
  (* atom atom fmla radius operator threshold bin_min bin_max nbins *)
  | ASM of (string * fsyn * float * string * float)
  (* atom fmla radius operator threshold*)
  | EUCL of (fsyn * string * float)
  (* fmla operator threshold *)
  | EDT of (fsyn * string * float)
  (* fmla operator threshold *)
  | EDTM of (fsyn * string * float)
  (* fmla operator threshold *)
  | MDDT of (fsyn * string * float)
  (* fmla operator threshold *)
  | EX of fsyn	    
  | AX of fsyn
  | EG of fsyn
  | AG of fsyn
  | EF of fsyn
  | AF of fsyn
  | EU of fsyn * fsyn
  | AU of fsyn * fsyn
  | IFTHENELSE of cfsyn * fsyn * fsyn
  | MAXVOL of fsyn
and
  cfsyn =
  | CTRUE
  | CFALSE
  | CAND of (cfsyn * cfsyn)
  | COR of (cfsyn * cfsyn)
  | CNOT of cfsyn
  | CSHARE of (fsyn * cfsyn)
  | CGROUP of fsyn
      
type qfsyn =
  | QFLOAT of float
  | QOP of string * qfsyn * qfsyn
  | QCOUNT of fsyn


      
type decl = LET of ide * ide list * fsyn
type dseq = decl list

type com =
    CHECK of string * fsyn
  | OUTPUT of string * (string list option)
  | ASK of string * (string list) * qfsyn      
type cseq = com list
		      
type experiment = model * dseq * cseq

module MEnv = Map.Make(struct type t = ide let compare = compare end)		     
type dval = ide list * fsyn
type env = dval MEnv.t	       
let empty : env = MEnv.empty		
let bind : env -> ide -> dval -> env = fun env name value -> MEnv.add name value env
let apply : env -> ide -> dval = fun env name ->
  try MEnv.find name env
  with Not_found -> TcUtil.fail (Printf.sprintf "undefined identifier: %s" name)
		    
let zipenv : env -> ide list -> dval list -> env =
  fun env formals actuals ->
  List.fold_left
    (fun env (formal,actual) -> bind env formal actual)
    env
    (List.combine formals actuals)
    
let opsem op =
  match op with
  | "<" -> (<)
  | "<=" -> (<=)
  | ("=="|"=") -> (=)
  | ("!="|"<>") -> (!=)
  | ">" -> (>)
  | ">=" -> (>=)
  | x -> TcUtil.fail (Printf.sprintf "unknown operator %s" x)

let rec replace_fsyn replacements f =
  match f with
    PROP prop -> f 
  | VPROP (prop,op,n) -> f
  | TRUE -> f
  | FALSE -> f
  | NOT f1 -> NOT (replace_fsyn replacements f1)     
  | AND (f1,f2) -> AND (replace_fsyn replacements f1,replace_fsyn replacements f2)
  | OR (f1,f2) -> OR (replace_fsyn replacements f1,replace_fsyn replacements f2)
  | NEAR f1 -> NEAR (replace_fsyn replacements f1)
  | NEARN (n,f1) -> NEARN (n,replace_fsyn replacements f1)
  | INT f1 -> INT (replace_fsyn replacements f1)
  | INTN (n,f1) -> INTN (n,replace_fsyn replacements f1)
  | SURROUNDED (f1,f2) -> SURROUNDED (replace_fsyn replacements f1,replace_fsyn replacements f2)
  | STATCMP (p1,f1,p2,f,rad,op,thr,min,max,nbins) ->
     STATCMP (p1,replace_fsyn replacements f1,p2,replace_fsyn replacements f,rad,op,thr,min,max,nbins)
  | SCMPIMA (p1,p2,f,rad,op,thr,min,max,nbins) ->
     SCMPIMA (p1,p2,replace_fsyn replacements f,rad,op,thr,min,max,nbins) 
  | ASM (p,f,rad,op,thr) -> ASM (p,replace_fsyn replacements f,rad,op,thr)
  | EUCL (f,op,thr) -> EUCL (replace_fsyn replacements f,op,thr)
  | EDT (f,op,thr) -> EDT (replace_fsyn replacements f,op,thr)
  | EDTM (f,op,thr) -> EDTM (replace_fsyn replacements f,op,thr)
  | MDDT (f,op,thr) -> MDDT (replace_fsyn replacements f,op,thr)
  | MAXVOL f -> MAXVOL (replace_fsyn replacements f)
  | EX f1 -> EX (replace_fsyn replacements f1)
  | AX f1 -> AX (replace_fsyn replacements f1)
  | EG f1 -> EG (replace_fsyn replacements f1)
  | AG f1 -> AG (replace_fsyn replacements f1)
  | EF f1 -> EF (replace_fsyn replacements f1)
  | AF f1 -> AF (replace_fsyn replacements f1)
  | EU (f1,f2) -> EU (replace_fsyn replacements f1,replace_fsyn replacements f2)
  | AU (f1,f2) -> AU  (replace_fsyn replacements f1,replace_fsyn replacements f2)
  | CALL (ide,actuals) ->
     CALL ((try (List.assoc ide replacements) with Not_found -> ide),List.map (replace_fsyn replacements) actuals)
  | IFTHENELSE (cf,f1,f2) -> IFTHENELSE (replace_cfsyn replacements cf,replace_fsyn replacements f1,replace_fsyn replacements f2)
and
    replace_cfsyn replacements cf =
  match cf with
    CTRUE -> cf
  | CFALSE -> cf
  | CAND (cf1,cf2) -> CAND (replace_cfsyn replacements cf1,replace_cfsyn replacements cf2)
  | COR (cf1,cf2) -> COR (replace_cfsyn replacements cf1,replace_cfsyn replacements cf2)
  | CNOT cf1 -> CNOT (replace_cfsyn replacements cf1)
  | CSHARE (f,cf) -> CSHARE (replace_fsyn replacements f,replace_cfsyn replacements cf)
  | CGROUP f -> CGROUP (replace_fsyn replacements f) 

let replace_list replacements l =
  List.map (fun x -> List.assoc x replacements) l
     
let env_of_dseq ds =
  List.fold_left
    (fun env (LET (name,args,body)) ->
      let replacements = genids args in
      let args' = replace_list replacements args in
      let body' = replace_fsyn replacements body in
      bind env name (args',body'))
    empty ds
     
let rec formula_of_fsyn env f =
  match f with
    PROP prop -> Prop prop
  | VPROP (prop,op,n) ->
     VProp (prop,op,n)
  | TRUE -> T
  | FALSE -> Not T
  | NOT f1 -> Not (formula_of_fsyn env f1)     
  | AND (f1,f2) -> And (formula_of_fsyn env f1,formula_of_fsyn env f2)
  | OR (f1,f2) -> Not (And (Not (formula_of_fsyn env f1),Not (formula_of_fsyn env f2)))
  | NEAR f1 -> Near (formula_of_fsyn env f1)
  | NEARN (n,f1) -> if n <= 0 then formula_of_fsyn env f1 else Near (formula_of_fsyn env (NEARN(n-1,f1)))
  | INT f1 -> Not (Near (Not (formula_of_fsyn env f1)))
  | INTN (n,f1) -> if n <= 0 then formula_of_fsyn env f1 else formula_of_fsyn env (INT (INTN (n-1,f1)))
  | SURROUNDED (f1,f2) -> Surrounded (formula_of_fsyn env f1,formula_of_fsyn env f2)
  | STATCMP (p1,f1,p2,f,rad,op,thr,min,max,nbins) -> Threshold (op,thr,Statcmp (p1,formula_of_fsyn env f1,p2,formula_of_fsyn env f,rad,min,max,nbins))
  | SCMPIMA (p1,p2,f,rad,op,thr,min,max,nbins) -> Threshold (op,thr,Scmpima (p1,p2,formula_of_fsyn env f,rad,min,max,nbins))
  | ASM (p,f,rad,op,thr) -> Threshold (op,thr,Asm (p,formula_of_fsyn env f,rad))
  | EUCL (f,op,thr) -> Threshold (op,thr,Eucl (formula_of_fsyn env f))
  | EDT (f,op,thr) -> Threshold (op,thr,EDT (formula_of_fsyn env f))
  | EDTM (f,op,thr) -> Threshold (op,thr,EDTM (formula_of_fsyn env f))
  | MDDT (f,op,thr) -> Threshold (op,thr,ModDijkstraDT (formula_of_fsyn env f))
  | MAXVOL f -> Maxvol (formula_of_fsyn env f)
  | EX f1 -> Ex (formula_of_fsyn env f1)
  | AX f1 -> Not (Ex (Not (formula_of_fsyn env f1)))
  | EG f1 -> Not (Af (Not (formula_of_fsyn env f1)))
  | AG f1 -> Not (Eu (T,Not (formula_of_fsyn env f1)))
  | EF f1 -> Eu (T,formula_of_fsyn env f1)
  | AF f1 -> Af (formula_of_fsyn env f1)
  | EU (f1,f2) -> Eu (formula_of_fsyn env f1,formula_of_fsyn env f2)
  | AU (f1,f2) ->
     let (ff1,ff2) = (formula_of_fsyn env f1,formula_of_fsyn env f2) in
     And(Not (Eu (Not ff2,And(Not ff1,Not ff2))),Af ff2)
  | CALL (ide,actuals) ->
     let (formals,body) = apply env ide in
     let (lf,la) = (List.length formals,List.length actuals) in
     if lf <> la
     then TcUtil.fail (Printf.sprintf "identifier %s takes %d parameters, but %d were provided" ide lf la)
     else formula_of_fsyn (zipenv env formals (List.map (fun x -> ([],x)) actuals)) body
  | IFTHENELSE (cf,f1,f2) ->
     Ifthenelse (cformula_of_cfsyn env cf,formula_of_fsyn env f1,formula_of_fsyn env f2)
and
    cformula_of_cfsyn env cf =
  match cf with
    CTRUE -> Ctrue
  | CFALSE -> Cnot Ctrue     
  | CAND (cf1,cf2) -> Cand (cformula_of_cfsyn env cf1,cformula_of_cfsyn env cf2)
  | COR (cf1,cf2) -> Cnot (Cand (Cnot (cformula_of_cfsyn env cf1),Cnot (cformula_of_cfsyn env cf2)))
  | CNOT cfsyn -> Cnot (cformula_of_cfsyn env cfsyn)
  | CSHARE (f,cf) -> Cshare (formula_of_fsyn env f,cformula_of_cfsyn env cf)
  | CGROUP f -> Cgroup (formula_of_fsyn env f) 
    
       
let rec qformula_of_qfsyn env qf =
  match qf with
  | QFLOAT f -> QFloat f
  | QOP (op,qf1,qf2) -> QOp (opsem op,qformula_of_qfsyn env qf1,qformula_of_qfsyn env qf2)
  | QCOUNT f1 -> QCount (formula_of_fsyn env f1)
