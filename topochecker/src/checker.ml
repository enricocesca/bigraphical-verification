open Logic
open Model
open Bigarray
open TcUtil
open Slice

module IntOrdDst : sig type t=(float*int) val compare: (float*int) -> (float*int) -> int end = struct
  type t = (float*int)
  let compare = Stdlib.compare
end
module DDTSet = Set.Make(IntOrdDst)
  
type result = Slice of Slice.slice | Fun of (int -> int -> float)

type cresult = Cslice of Slice.cslice | Cfun of (int -> float)
let capply cresult = match cresult with Cfun f -> f | Cslice s -> Array1.unsafe_get s

let newid =
  let counter = ref 0 in
  fun () ->
  let tmp = !counter in
  counter := !counter + 1;
  tmp
                                                                
let compute model =
  let num_states = Graph.nb_vertex model.kripke in
  let num_points =  model.space#num_nodes in
  let count = Array1.create int c_layout num_states in (* auxiliary *)
  let stack = Array1.create int c_layout num_points in (* auxiliary *)
  let onstack = Array1.create int c_layout num_points in (* auxiliary *)
  let lowlink = Array1.create float64 c_layout num_points in (* auxiliary *)
  let new_slice dbg f = let slice = make_slice num_states num_points in let id = newid() in (debugint (Printf.sprintf "[%d] %s" id dbg); f slice;debugint (Printf.sprintf "[%d] %s done" id dbg); Slice slice) in
    let new_cslice f = let cslice = make_cslice num_states in (f cslice; Cslice cslice) in
  let rec cchecker set model (cache : formula -> int -> int -> float) cf =
    match cf with
      Ctrue -> Cfun (fun _ -> valTrue)
    | Cand (cf1,cf2) -> 
       let a1 = cchecker set model cache cf1 in
       let a2 = cchecker set model cache cf2 in
       Cfun (fun state -> valAnd (capply a1 state) (capply a2 state))
    | Cnot cf ->
       let a = cchecker set model cache cf in
       Cfun (fun state -> valNot (capply a state))
    | Cshare (f,cf) -> 
       let a = cache f in
       cchecker a model cache cf
    | Cgroup f ->
       new_cslice (fun cslice ->
	 let a = cache f in
	 let b = cache (CC f) in
	 for state = 0 to num_states - 1 do
	   let result = ref true in
	   let cc = ref 0.0 in
	   let point = ref 0 in
	   while !result && (!point < num_points) do
	     if isTrue (set state !point) then
	       if isFalse (a state !point)
	       then result := false
	       else
		 (if (!cc) = 0.0
		  then cc := b state !point
		  else (if b state !point <> !cc then result := false));
	     point := !point + 1;
	   done; 
	   Array1.set cslice state (TcUtil.ofBool !result);
	 done)
  in
  fun formula cache ->
  match formula with
  | Maxvol f ->
     let a = cache (CC f) in
     new_slice "maxvol" (fun slice ->
       for state = 0 to num_states - 1 do
	 let max = ref 0 in	 
	 Array1.fill stack 0;
         for point = 0 to num_points - 1 do
           let ncc = int_of_float (a state point) in
           if ncc > 0 then
             let n = (Array1.unsafe_get stack (ncc-1)) + 1 in
             Array1.unsafe_set stack (ncc-1) n;         
             if n > !max then max := n
         done;
	 for point = 0 to num_points - 1 do
	   let ncc = int_of_float (a state point) in
	   if ncc > 0 then
	     let n = Array1.unsafe_get stack (ncc - 1) in
	     let b = (n = !max) in
	     Array2.set slice state point (ofBool b) 
	 done
       done)
         
  | Ifthenelse (cf,f1,f2) ->
   let set = cache T in (* TODO: this sets the initial context for collective evaluation to all points (formula "T") *)
   let cresult = cchecker set model cache cf in
   let a1 = cache f1 in
   let a2 = cache f2 in
   Fun (fun state point -> if isTrue (capply cresult state) then a1 state point else a2 state point)
  | T -> Fun (fun state point -> valTrue)
  | Prop p -> let a1 = cache (Prop p) in Fun a1
  | CC f -> let a = cache f in new_slice "CC"
			         (fun slice ->
				   for state = 0 to num_states - 1 do
				     TcUtil.tarjan (a state) num_points
				       (model.space#iter_post) stack
				       (Array2.slice_left slice state) onstack lowlink;
				   done)
  | VProp (p,op,n) -> let a1 = cache (Prop p) in Fun (fun state point -> TcUtil.ofBool (Syntax.opsem op (a1 state point) n))
  | Not f1 -> let a1 = cache f1 in Fun (fun state point -> valNot (a1 state point))
  | And (f1,f2) -> 
     let a1 = cache f1 in
     let a2 = cache f2 in
     Fun (fun state point -> valAnd (a1 state point) (a2 state point)) (* TODO: check if memoization is more efficient but also exponential blowup in fmla marshalling *)
  | Threshold (op,thr,f) ->
     let a = cache f in
     Fun (fun state point ->  TcUtil.ofBool (Syntax.opsem op (a state point) thr))
  | Statcmp (p,f1,p2,f,rad,min,max,nbins) ->
     new_slice "statcmp"
       (fun slice ->
	 (match model.iter_ball with
	    None -> TcUtil.fail "model does not have distances but SCMP operator used"
	   | Some ib ->
	      let step = (max -. min) /. (float_of_int nbins) in
	      let v1 = Array.make nbins 0 in
	      let v2 = Array.make nbins 0 in
	      let a1 = cache (Prop p) in
	      let a2 = cache f in
	      let a3 = cache f1 in
	      let a4 = cache (Prop p2) in
	      for state = 0 to num_states - 1 do
		TcUtil.reset v2 0;
		for point = 0 to num_points - 1 do
		  if TcUtil.isTrue (a2 state point) then TcUtil.bin v2 (a4 state point) min max step else ()
		done;
		for point = 0 to num_points - 1 do
		  if TcUtil.isTrue (a3 state point) then
		    begin
		      TcUtil.reset v1 0;
		      ib point rad (fun point -> TcUtil.bin v1 (a1 state point) min max step);
		      let res = TcUtil.statcmp v1 v2 in
		      Array2.unsafe_set slice state point res
		    end
		  else
		    Array2.unsafe_set slice state point nan
		done
	      done))
    | Scmpima (p1,p2,f,rad,min,max,nbins) ->
       new_slice "scmpima"
	 (fun slice ->
	   (match model.iter_ball with
	     None -> TcUtil.fail "model does not have distances but SCMPIMA operator used"
	   | Some ib ->
	      let step = (max -. min) /. (float_of_int nbins) in
	      let v1 = Array.make nbins 0 in
	      let v2 = Array.make nbins 0 in
	      let a1 = cache (Prop p1) in
	      let a2 = cache (Prop p2) in
	      let a3 = cache f in
	      for state = 0 to num_states - 1 do
		for point = 0 to num_points - 1 do
		  if TcUtil.isTrue (a3 state point) then
		    begin
		      TcUtil.reset v1 0;
		      TcUtil.reset v2 0;
		      
		      ib point rad
			(fun point -> TcUtil.bin v1 (a1 state point) min max step;
		      	  TcUtil.bin v2 (a2 state point) min max step);
		      let res = TcUtil.statcmp v1 v2 in
		      Array2.unsafe_set slice state point res
		    end
		  else
		    Array2.unsafe_set slice state point nan
		done
	      done))
    | Asm (p,f,rad) ->
       new_slice "asm"
	 (fun slice ->
	   (match model.iter_ball with
	     None -> TcUtil.fail "model does not have distances but ASM operator used"
	   | Some ib ->
	      let a1 = cache (Prop p) in (* TODO: unused variable a1... *)
	      let a2 = cache f in
	      for state = 0 to num_states - 1 do
		for point = 0 to num_points - 1 do
		  if TcUtil.isTrue (a2 state point) then
		    begin
		    (* TODO: VINCENZO: che è sta roba? L'ho trovata commentata, col begin ... end vuoto *)
		    (* ???????????????????????? *)
		    (* ib point rad *)
		    (* 	(fun point -> ); *)
		    (* let res = TcUtil.statcmp v in *)
		    (* Array2.unsafe_set slice state point res *)
		    end
		  else
		    Array2.unsafe_set slice state point nan
		done
	      done))
    | Eucl f ->
       new_slice "eucl"
	 (fun slice -> (
	   try
	     let a1 = cache f in
	     for state = 0 to num_states - 1 do
	       let edgeS = TcUtil.edge (a1 state) model.space in
	       for point = 0 to num_points - 1 do
		 let dst = ref infinity in
		 if PointsSet.mem point edgeS then
		   dst := 0.0
		 else
		   TcUtil.PointsSet.iter
		     (fun e ->
		       let s = if isTrue (a1 state point) then -1.0 else 1.0 in
		       let d = model.space#euclidean_distance point e in
		       if (d < abs_float(!dst)) then dst := d*.s) edgeS;
		 Array2.unsafe_set slice state point !dst
	       done
	     done
	   with _ -> TcUtil.fail "model does not have distances but EUCL operator used"))
    | EDT f -> (*Ciesielski et al. 2010*)
       new_slice "EDT"
    	 (fun slice -> (
	   try
    	     let a1 = cache f in
    	     for state = 0 to num_states - 1 do
    	       (* F_0 *)
	       let edgeS = TcUtil.edge (a1 state) model.space in
    	       for point = 0 to num_points - 1 do
    		 (* let dt = if isTrue (a1 state point) then (float_of_int point) else -1.0 in *)
		 let dt = if PointsSet.mem point edgeS then (float_of_int point) else -1.0 in
    		 Array2.unsafe_set slice state point dt;
    	       done;

	       (* FT *)
	       let ndim = Array.length model.space#dims in
    	       for d=0 to ndim-1 do
		 let cdn = model.space#num_nodes / model.space#dims.(d) in
		 let p = Array.make ndim 0 in
		 let cddims = Array.make (ndim-1) 0 in
		 Array.blit model.space#dims 0 cddims 0 d;
		 if d<=ndim-2 then
		   Array.blit model.space#dims (d+1) cddims d (ndim-1-d);

		 for np = 0 to cdn - 1 do
		   let npc = coords_of_int np cddims in
		   p.(d)<-0;
		   Array.blit npc 0 p 0 d;
		   if d<=ndim-2 then
		     Array.blit npc d p (d+1) (ndim-1-d);
		   
		   let pp = int_of_coords p model.space#dims in
		   TcUtil.dimUp state pp d (model.space#dims) (model.space#pixdims) (model.space#euclidean_distance) slice;
		 done;
	       done;

	       (* DT *)
	       for point = 0 to num_points - 1 do
		 let s = if isTrue (a1 state point) then
		     -1.0
		   else
		     1.0 in
		 let cft = int_of_float (Array2.unsafe_get slice state point) in
		 let edt = if cft >= 0 then
		     s*.(model.space#euclidean_distance point cft)
		   else
		     infinity
		 in
		 Array2.unsafe_set slice state point edt
	       done
	     done
	   with _ -> TcUtil.fail "model is not a euclidean grid"))
    | EDTM f -> (*Ciesielski et al. 2010*)
       new_slice "EDTM"
    	 (fun slice -> (
	   try
    	     let a1 = cache f in
    	     for state = 0 to num_states - 1 do
    	       (* F_0 *)
	       let edgeS = TcUtil.edge (a1 state) model.space in
    	       for point = 0 to num_points - 1 do
    		 (* let dt = if isTrue (a1 state point) then (float_of_int point) else -1.0 in *)
		 let dt = if PointsSet.mem point edgeS then (float_of_int point) else -1.0 in
    		 Array2.unsafe_set slice state point dt;
    	       done;

	       (* FT *)
	       let ndim = Array.length model.space#dims in
    	       for d=0 to ndim-1 do
		 let cdn = model.space#num_nodes / model.space#dims.(d) in
		 let p = Array.make ndim 0 in
		 let cddims = Array.make (ndim-1) 0 in
		 Array.blit model.space#dims 0 cddims 0 d;
		 if d<=ndim-2 then
		   Array.blit model.space#dims (d+1) cddims d (ndim-1-d);

		 for np = 0 to cdn - 1 do
		   let npc = coords_of_int np cddims in
		   p.(d)<-0;
		   Array.blit npc 0 p 0 d;
		   if d<=ndim-2 then
		     Array.blit npc d p (d+1) (ndim-1-d);
		   
		   let pp = int_of_coords p model.space#dims in
		   TcUtil.dimUpM state pp d (model.space#dims) (model.space#pixdims) (model.space#euclidean_distance) slice;
		 done;
	       done;

	       (* DT *)
	       for point = 0 to num_points - 1 do
		 let s = if isTrue (a1 state point) then
		     -1.0
		   else
		     1.0 in
		 let cft = int_of_float (Array2.unsafe_get slice state point) in
		 let edt = if cft >= 0 then
		     s*.(model.space#euclidean_distance point cft)
		   else
		     infinity
		 in
		 Array2.unsafe_set slice state point edt
	       done
	     done
	   with _ -> TcUtil.fail "model is not a euclidean grid"))
    | ModDijkstraDT f ->
       new_slice "moddijkstradt"
	 (fun slice ->
	   let a1 = cache f in
	   Array2.fill slice infinity;
	   for state = 0 to num_states - 1 do
	     let edgeS = TcUtil.edge (a1 state) model.space in
	     let lSet = ref DDTSet.empty in
	     TcUtil.PointsSet.iter (fun e -> lSet:=DDTSet.add (0.0,e) !lSet;Array2.unsafe_set slice state e 0.0) edgeS;
	     while (not (DDTSet.is_empty !lSet)) do
	       let e = DDTSet.min_elt !lSet in
	       lSet:=DDTSet.remove e !lSet;
	       match e with
	       | (dst,point) ->
		  model.space#iter_post point (*pre or post?*)
		    (fun p w ->
		      let dn=Array2.unsafe_get slice state p in
		      if dn>(dst+.w) then
			begin
			  Array2.unsafe_set slice state p (dst+.w);
			  lSet:=DDTSet.add (dst+.w,p) !lSet;
			end)
	     done;
	     for point = 0 to num_points - 1 do
	       let s=
		 if isTrue (a1 state point) then
		   -1.0
		 else
		   1.0 in
	       let d = s*.(Array2.unsafe_get slice state point) in
	       Array2.unsafe_set slice state point d
	     done
	   done)
    | Near f1 ->
       new_slice "near"
	 (fun slice ->
	   Array2.fill slice valFalse;
	   let a1 = cache f1 in
	   for state = 0 to num_states - 1 do
	     for point = 0 to num_points - 1 do
	       if isTrue (a1 state point) then
		 begin
		   Array2.unsafe_set slice state point valTrue;
		   model.space#iter_post point
		     (fun point' w ->
		       Array2.unsafe_set slice state point' valTrue)
		 end
	     done
	   done)
    | Surrounded (f1,f2) ->
       new_slice "surrounded"
	 (fun slice ->
	   Array2.fill slice valFalse;
	   let a1 = cache f1 in
           let a2 = cache f2 in
           let accum = Stack.create () in
	   for state = 0 to num_states - 1 do
             for point = 0 to num_points - 1 do
	       Array2.unsafe_set slice state point (a1 state point);
	       if isTrue (a1 state point) || isTrue (a2 state point) then
		 model.space#iter_post point
		                       (fun point w ->
                                         if (isFalse (a1 state point)) &&
		                              (isFalse(a2 state point)) &&
		                                (isFalse(Array2.unsafe_get slice state point))
		                         then (Array2.unsafe_set slice state point valUtil;
			                       Stack.push point accum))
	     done;
	     while not (Stack.is_empty accum) do
	       let point = Stack.pop accum in
	       Array2.unsafe_set slice state point valFalse;
	       model.space#iter_pre point (fun point w ->
		 if isTrue (Array2.unsafe_get slice state point) then
		   begin
		     Array2.unsafe_set slice state point valFalse;
		     if isFalse (a2 state point)
		     then Stack.push point accum
		   end)
	     done;
	   done)
    | Af f1 ->
       new_slice "af"
	 (fun slice ->
	   let a1 = cache f1 in
	   for point = 0 to num_points - 1 do
	     let accum = Stack.create () in		  	    
	     for state = 0 to num_states - 1 do
	       if TcUtil.isTrue (a1 state point)
	       then (Array1.unsafe_set count state 0; Array2.unsafe_set slice state point valTrue; Stack.push state accum)
	       else Array1.unsafe_set count state (Model.Graph.out_degree model.kripke state)
	     done;
	     while not (Stack.is_empty accum) do
	       let state = Stack.pop accum in
	       Model.Graph.iter_pred
		 (fun state ->
		   let c = Array1.unsafe_get count state in
		   if c > 0 then Array1.unsafe_set count state (c-1);		 
		   if c = 1 then (Stack.push state accum;
				  Array2.unsafe_set slice state point valTrue))
		 model.kripke state
	     done	      
	   done)	   
    | Ex f1 ->
       new_slice "ex"
	 (fun slice ->
	   Array2.fill slice valFalse;
	   let a1 = cache f1 in
	   for state = 0 to num_states - 1 do
	     for point = 0 to num_points - 1 do
	       if isTrue (a1 state point)
	       then Model.Graph.iter_pred
		 (fun state -> Array2.unsafe_set slice state point valTrue)
		 model.kripke state
	     done
	   done)
    | Eu (f1,f2) ->
       new_slice "eu"
	 (fun slice ->
	   Array2.fill slice valFalse;
	   let a1 = cache f1 in
	   let a2 = cache f2 in
	   let accum = Stack.create () in
	   for state = 0 to num_states - 1 do
	     for point = 0 to num_points - 1 do
 	       if isTrue (a2 state point) then
		 begin
		   Array2.unsafe_set slice state point valTrue;
		   Model.Graph.iter_pred
		     (fun state -> if isTrue (a1 state point) &&
			 isFalse (a2 state point) &&
			 isFalse (Array2.unsafe_get slice state point)
		       then (Array2.unsafe_set slice state point valUtil;
			     Stack.push (state,point) accum))
		     model.kripke state
		 end;		
	     done
	   done;	    
	   while not (Stack.is_empty accum) do
	     let (state,point) = Stack.pop accum in
	     Array2.unsafe_set slice state point valTrue;
	     Model.Graph.iter_pred
	       (fun state -> if isTrue (a1 state point) &&
		   isFalse (a2 state point) &&
		   isFalse (Array2.unsafe_get slice state point)
		 then (Array2.unsafe_set slice state point valUtil;
		       Stack.push (state,point) accum))
	       model.kripke state;
	   done)
	 
let rec precompute model f =  
  try H.find model.eval f
  with Not_found ->
    match f with
      Prop "deadlock" ->
	fun state point ->
	  (match model.deadlocks with
	    None -> valFalse
	  | Some f -> f state)
    | _ ->
       let res = compute model f (precompute model) in
       match res with
	 Fun fn -> fn
       | Slice s -> let fn = Array2.unsafe_get s in
		    (H.add model.eval f fn;
		     (match model.hash_and_cache with
		       None -> ()
		     | Some (_,cache) -> H.add cache f s);
		     fn)
  	   
let rec qchecker points nb checker qf =
  match qf with
  | QFloat f -> f
  | QOp (qop,f1,f2) -> ofBool (qop (qchecker points nb checker f1) (qchecker points nb checker f2))
  | QCount f -> float_of_int (let res = ref 0 in
			      let c = checker f 0 in
			      if [] = points then
				for i = 0 to nb-1 do 
				  if isTrue (c i)
				  then res := !res + 1
				done
			      else
				List.iter
				  (fun i ->
				   if isTrue (c i)
				    then res := !res + 1)
				  points;
			      !res)

			     
			     
