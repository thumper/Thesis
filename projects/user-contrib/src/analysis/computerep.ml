(*

Copyright (c) 2007-2008 The Regents of the University of California
All rights reserved.

Authors: Luca de Alfaro, B. Thomas Adler, Vishwanath Raman

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. The names of the contributors may not be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

 *)

(** Module Computerep 
    This module computes the reputation, and produces as output two lists, 
    of edit, and data, reputation evaluations *)

open Evaltypes;;
open Rephist;;

let initial_reputation = 0.1
let debug = false
let single_debug = false
let single_debug_id = 57

class users 
  (rep_scaling: float) 
  (max_rep: float)
  (gen_exact_rep: bool)
  (include_domains: bool)
  (ip_nbytes: int)
  (user_history_file: out_channel option) 
  =
  object (self)
    val tbl = Hashtbl.create 1000 

    (* This method, when called for anonymous users returns a user id generated
       from the user ip address, if we want to include user domains in computing
       reputation. It simply returns the user id passed in input, otherwise *)

    method private generate_user_id (uid: int) (ip_addr: string) : int =
      if (uid = 0 && include_domains) then begin
	let domain = ref 0 in
	let rec accumulate (i: int) (bytes: string list) : int =
	  if (i > 0) then begin
	    try
	      domain := !domain lsl 8;
	      domain := !domain lor int_of_string(List.hd bytes);
	      accumulate (i - 1) (List.tl bytes)
	    with _ -> !domain
	  end else !domain
	in
	  -(accumulate ip_nbytes (Str.split (Str.regexp_string ".") ip_addr))
      end else uid

    method inc_rep (uid: int) (username: string) (q: float) (timestamp: Rephist.RepHistory.key) : unit = 
      if (uid <> 0 || include_domains) then 
        begin
	  let user_id = self#generate_user_id uid username in
	    if Hashtbl.mem tbl user_id then 
              begin
		let u = Hashtbl.find tbl user_id in 
		  if debug then Printf.printf "Uid %d rep: %f " user_id u.rep; 
		  if debug then Printf.printf "inc: %f\n" (q /. rep_scaling);
		  u.rep <- max 0.0 (min max_rep (u.rep +. (q /. rep_scaling)));
		  match user_history_file with 
		      None -> ()
		    | Some f -> begin 
			let new_weight = log (1.0 +. (max 0.0 u.rep)) in 
			  if new_weight > (float_of_int u.rep_bin) +. 1.2 
			    || new_weight < (float_of_int u.rep_bin) -. 0.2 
			    || gen_exact_rep
			  then (* must write out the change in reputation *)
			    let new_bin = int_of_float new_weight in 
			      if gen_exact_rep then
				Printf.fprintf f "%f %7d %2d %2d %f\n" timestamp user_id u.rep_bin new_bin u.rep
			      else
				Printf.fprintf f "%f %7d %2d %2d\n" timestamp user_id u.rep_bin new_bin;
			      u.rep_bin <- new_bin 
		      end;
			if user_id = single_debug_id && single_debug then 
			  Printf.printf "Rep of %d: %f\n" user_id u.rep
              end
            else 
              begin
		(* New user *)
		let u = {
                  uname = username;
		  rep = initial_reputation; 
                  contrib = 0.0;
		  cnt = 0.0; 
		  rep_bin = 0; 
		  rep_history = RepHistory.empty } in 
		u.rep <- max 0.0 (min max_rep (u.rep +. (q /. rep_scaling)));
		match user_history_file with 
		    None -> ()
		  | Some f -> begin 
		      let new_weight = log (1.0 +. (max 0.0 u.rep)) in 
		      let new_bin = int_of_float new_weight in 
			if gen_exact_rep then
			  Printf.fprintf f "%f %7d %2d %2d %f\n" timestamp user_id (-1) new_bin u.rep
			else
			  Printf.fprintf f "%f %7d %2d %2d\n" timestamp user_id (-1) new_bin;
			u.rep_bin <- new_bin 
		    end;
		Hashtbl.add tbl user_id u; 
              end
        end
	  
    method inc_contrib (uid: int) (username: string) (amount: float) (include_anons: bool) 
		       (contrib_type: Evaltypes.contrib_type_t) : unit = 
      if (uid <> 0 || include_anons || include_domains) then 
        begin
	  let user_id = self#generate_user_id uid username in
            if Hashtbl.mem tbl user_id then begin
	      (* Existing user *)
              let u = Hashtbl.find tbl user_id in 
	        if debug then Printf.printf "Uid %d rep: %f " user_id u.rep; 
		match contrib_type with
		    ReputationExact -> u.contrib <- max 0.0 (min max_rep (u.contrib +. (amount /. rep_scaling)))
		  | _ -> u.contrib <- u.contrib +. amount;
            end
            else begin
              (* New user *)
	      let initial_contribution =
		match contrib_type with
		    ReputationExact -> max 0.0 (min max_rep (amount /. rep_scaling))
		  | _ -> amount
	      in
              let u = {
                uname = username;
		rep = initial_reputation; 
		contrib = initial_contribution;
		cnt = 0.0; 
		rep_bin = 0; 
		rep_history = RepHistory.empty } in 
                Hashtbl.add tbl user_id u; 
            end
        end

    method inc_count (uid: int) (timestamp: float) : unit = 
      if (uid <> 0 || include_domains) then 
        begin
          if Hashtbl.mem tbl uid then 
            begin
              let u = Hashtbl.find tbl uid in 
              u.cnt <- u.cnt +. 1.0
            end
          else 
            begin
              (* New user *)
              let u = {
                uname = "PlaceHolder";
                rep = 0.0; 
                contrib = 0.0; 
                cnt = 1.0; 
                rep_bin = 0; 
                rep_history = RepHistory.empty } in 
                Hashtbl.add tbl uid u
            end
        end

    method get_rep (uid: int) : float = 
      if uid = 0 
      then initial_reputation
      else
        begin
          if Hashtbl.mem tbl uid then 
            begin
              let u = Hashtbl.find tbl uid in 
              u.rep 
            end
          else
            initial_reputation
        end

    method get_contrib (uid: int) : float =
      if uid = 0 
      then 0.0
      else
        begin
          if Hashtbl.mem tbl uid then 
            begin
              let u = Hashtbl.find tbl uid in 
              u.contrib
            end
          else
            0.0
        end

    method get_weight (uid: int) : float = 
      let r = self#get_rep uid in 
      log (1.0 +. (max 0.0 r))
        
    method get_count (uid: int) : float = 
      if uid = 0 
      then 0.0 
      else 
        begin
          if Hashtbl.mem tbl uid then 
            begin
              let u = Hashtbl.find tbl uid in 
              u.cnt
            end
          else
            0.0
        end
      
    method get_users : (int, Evaltypes.user_data_t) Hashtbl.t = tbl

    method print_contributions (out_ch: out_channel) : unit =
      let write_contrib uid u =
        Printf.fprintf out_ch "Uid %d    Name %S    Reputation %d    Contribution %0.7f\n" 
          uid u.uname u.rep_bin u.contrib
      in
        Hashtbl.iter write_contrib tbl;

  end (* class users *)

class rep 
  (params: params_t) (* The parameters used for evaluation *)
  (include_anons: bool) (* Whether to include anonymous users in evaluation *)
  (rep_intv: time_intv_t) (* The interval of time for which reputation is evaluated *)
  (eval_intv: time_intv_t) (* The time interval for which reputation is evaluated *)
  (user_history_file: out_channel option) (* File where to write the history of user reputations *)
  (print_monthly_stats: bool) (* Prints monthly precision and recall statistics *)
  (do_cumulative_months: bool) (* True if the monthly statistics have to be cumulative *)
  (do_firstcut: bool) (* True if we want to compute reputations as we did in our first release *)
  (gen_exact_rep: bool) (* True if we want to create an extra column in the user history file with exact rep values *)
  (include_domains: bool) (* Indicates that we want to extract reputation for anonymous user domains *)
  (ip_nbytes: int) (* the number of bytes to use from the user ip address *)
  (output_channel: out_channel) (* Used to print automated stuff like monthly stats *)
  =
object (self)
  (* This is the object keeping track of all users *)
  val user_data = new users params.rep_scaling params.max_rep gen_exact_rep include_domains ip_nbytes user_history_file
    (* These are for computing the statistics on the fly *)
  val mutable stat_text = new Computestats.stats params eval_intv
  val mutable stat_edit = new Computestats.stats params eval_intv
    (* Remembers the last month for which statistics were printed *)
  val mutable last_month = -1
  val contribs_tbl = Hashtbl.create 1000

  method add_data (datum: wiki_data_t) : unit = 
    (* quality normalization function *)
    let normalize x = max (min x 1.0) (-. 1.0) in 
    (* Breaks apart the event time *)
    let date = 
      match datum with 
	EditLife e -> begin
          let uid = e.edit_life_uid0 in 
          let uname = e.edit_life_uname0 in
            if (uid <> 0 || include_anons || include_domains) 
	      && e.edit_life_delta > 0. 
              && e.edit_life_time >= rep_intv.start_time
              && e.edit_life_time <= rep_intv.end_time
            then begin
	      if debug then begin 
	        Printf.printf "EditLife T: %f rep_weight: %f data_weight: %f spec_q: %f\n" 
		  e.edit_life_time
		  (user_data#get_weight uid)
		  (e.edit_life_delta *. (float_of_int e.edit_life_n_judges))
		  (normalize e.edit_life_avg_specq) (* debug *)
	      end; 
	      stat_edit#add_event 
	        e.edit_life_time 
	        (user_data#get_weight uid)
	        (e.edit_life_delta *. (float_of_int e.edit_life_n_judges))
	        (normalize e.edit_life_avg_specq);
              match params.contribution_type with
                  EditOnly -> 
                    user_data#inc_contrib uid uname e.edit_life_delta include_anons params.contribution_type
                | EditLong2 ->
                    user_data#inc_contrib uid uname (e.edit_life_delta *. (normalize e.edit_life_avg_specq))
		      include_anons params.contribution_type
                | TextWithPunish2 ->
                    user_data#inc_contrib uid uname (min (e.edit_life_delta *. (normalize e.edit_life_avg_specq)) 0.)
		      include_anons params.contribution_type
                | _ -> ()
	    end;
	    e.edit_life_time
	end
      | TextLife t -> begin 
          let uid = t.text_life_uid0 in 
          let uname = t.text_life_uname0 in
          if (uid <> 0 || include_anons || include_domains)
            && t.text_life_time >= rep_intv.start_time
            && t.text_life_time <= rep_intv.end_time 
	    && t.text_life_new_text > 0 
	  then begin 
	    if debug then begin
	      Printf.printf "Textlife T: %f rep_weight: %f data_weight: %f spec_q: %f\n"
		t.text_life_time
		(user_data#get_weight uid)
		(float_of_int t.text_life_new_text)
		(normalize t.text_life_text_decay) (* debug *)
	    end; 
	    stat_text#add_event 
	      t.text_life_time
	      (user_data#get_weight uid)
	      (float_of_int t.text_life_new_text)
              (normalize t.text_life_text_decay);
            match params.contribution_type with
                TextLong 
              | TextWithPunish ->
                  user_data#inc_contrib uid uname 
                    ((normalize t.text_life_text_decay) *. (float_of_int t.text_life_new_text))
		    include_anons params.contribution_type
              | TextWithPunish2 ->
                  user_data#inc_contrib uid uname 
                    ((normalize t.text_life_text_decay) *. (float_of_int t.text_life_new_text))
		    include_anons params.contribution_type
              | TextOnly ->
                  user_data#inc_contrib uid uname (float_of_int t.text_life_new_text)
		    include_anons params.contribution_type
              | _ -> ()
	  end;
	  t.text_life_time
	end
      | EditInc e -> begin 
          let uid = e.edit_inc_uid0 in 
	  let uname = e.edit_inc_uname0 in
          (* increments non-anonymous users or anonymous user domains, 
	     if delta > 0, and if it is in the time range *)
          if (uid <> 0 || include_domains)
	    && e.edit_inc_d12 > 0.
            && e.edit_inc_time >= rep_intv.start_time
            && e.edit_inc_time <= rep_intv.end_time
	    && e.edit_inc_uid1 <> e.edit_inc_uid0 
	    && ((not do_firstcut) || (do_firstcut && e.edit_inc_n01 = 1))
          then 
            begin
              let spec_q = min 1.0 
		((params.edit_leniency *. e.edit_inc_d01 -. e.edit_inc_d02) 
		/. e.edit_inc_d12)
              in 
              (* takes into account of delta and the length exponent *)
              let q = spec_q *. (e.edit_inc_d12 ** params.length_exponent) in 
              (* punish the people who do damage *)
              let q1 = if q < 0.0 then q *. params.punish_factor else q in 
              let judge_w = user_data#get_weight e.edit_inc_uid1 in 
              let q2 = q1 *. judge_w *. (1.0 -. params.text_vs_edit_weight) in 
	        if debug then Printf.printf "EditInc Uid %d q %f\n" uid q2; (* debug *)
                user_data#inc_rep uid uname q2 e.edit_inc_time;
                match params.contribution_type with
                    EditLong ->
                      user_data#inc_contrib uid uname (e.edit_inc_d12 *. spec_q)
			include_anons params.contribution_type
                  | TextWithPunish ->
                      user_data#inc_contrib uid uname (min (e.edit_inc_d12 *. spec_q) 0.)
			include_anons params.contribution_type
                  | Reputation 
                  | ReputationExact -> 
                      user_data#inc_contrib uid uname q2 include_anons params.contribution_type
                  | _ -> ()
            end;
	  e.edit_inc_time 
      end
    | TextInc t -> begin 
        let uid = t.text_inc_uid0 in 
	let uname = t.text_inc_uname0 in
        if (uid <> 0 || include_domains)
	  && t.text_inc_orig_text > 0
	  && t.text_inc_seen_text > 0
          && t.text_inc_time >= rep_intv.start_time
          && t.text_inc_time <= rep_intv.end_time
	  && t.text_inc_uid1 <> t.text_inc_uid0 
	  && ((not do_firstcut) || (do_firstcut && t.text_inc_n01 <= 10))
        then 
          begin 
            let ratio_live = (float_of_int t.text_inc_seen_text) /. 
	      (float_of_int t.text_inc_orig_text) in 
            let merit = ratio_live *. 
	      ((float_of_int t.text_inc_orig_text) ** params.length_exponent) in 
            let judge_w = user_data#get_weight t.text_inc_uid1 in 
            let q = merit *. judge_w *. params.text_vs_edit_weight in 
	      if debug then Printf.printf "TextInc Uid %d q %f\n" uid q; (* debug *)
              user_data#inc_rep uid uname q t.text_inc_time;
              match params.contribution_type with
                  Revisions ->
                    if (t.text_inc_n01 <= params.n_rev_contribs) then
                      user_data#inc_contrib uid uname (float_of_int t.text_inc_seen_text)
			include_anons params.contribution_type
                | Reputation 
                | ReputationExact -> 
                    user_data#inc_contrib uid uname q include_anons params.contribution_type
                | _ -> ()
          end;
	t.text_inc_time
      end
    in 
    (* Checks whether we have to print precision and recall at the end of the month *)
    let (new_year, new_month, _, _, _, _) = Timeconv.float_to_time date in 
    if new_month <> last_month && print_monthly_stats then begin 
      last_month <- new_month; 
      let null_ch = open_out ("/dev/null") in 
      let se = stat_edit#compute_stats false null_ch in 
      let st = stat_text#compute_stats true  null_ch in 
      Printf.fprintf output_channel "%2d/%4d %f %12.1f %6.3f %7.5f %7.5f %12.1f %6.3f %7.5f %7.5f\n" 
	new_month new_year date 
	se.stat_total_weight se.stat_bad_perc se.stat_bad_precision se.stat_bad_recall 
	st.stat_total_weight st.stat_bad_perc st.stat_bad_precision st.stat_bad_recall; 
      flush output_channel; 
      (* If the statistics are not cumulative, then resets them *)
      if not do_cumulative_months then begin
	stat_text <- new Computestats.stats params eval_intv;
	stat_edit <- new Computestats.stats params eval_intv
      end
    end


  (* This method computes the statistics, and returns the edit_stats * text_stats *)
  method compute_stats (contrib_out_ch: out_channel option) (out_ch: out_channel) : stats_t * stats_t = 
    begin
      match contrib_out_ch with
          Some f -> user_data#print_contributions f
        | None -> ()
    end;
    Printf.fprintf out_ch "\nEdit Stats:\n"; 
    let edit_s = stat_edit#compute_stats false out_ch in 
    Printf.fprintf out_ch "\nText Stats:\n";
    let text_s = stat_text#compute_stats true  out_ch in 
    (edit_s, text_s) 

  method get_users : (int, Evaltypes.user_data_t) Hashtbl.t = user_data#get_users

end;; (* class rep *)
