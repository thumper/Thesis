
TYPE_CONV_PATH "UCSC_WIKI_RESEARCH"

open Editlist;;

type word = string
type heap_el = int * int * int
type index_t = ((word * word), int) Hashtbl_bounded.t

exception Heap_Too_Large

(** This is the maximum number of matches for a
 *  word pair that we track. If a word pair has
 *  more than this number of matches, we disregard
 *  them all, as we classify the word pair as not
 *  sufficiently distinctive.
 *)
let max_matches = 50
let max_heaplen = ref 1000
let thumper_min_copy_len = 3

module Heap = Coda.PriorityQueue
type match_quality_t = Coda.match_quality_t

(* Quality functions for matches.
 * l is the length of the match.
 * len1 and len2 are the two lengths (in number of
 *      words) of the pieces being compared.
 * i1 and i2 are the two starting points.
 * ch1_idx is the chunk number.
 * The lower the quality, the more the match is
 * considered, as elements are * removed starting
 * from the lowest from the priority queue.
 *)

let quality_live (l: int) (i1: int) (len1: int)
                (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t =
  let i1' = (float_of_int (2 * i1 + l)) /. 2. in
  let len1' = float_of_int len1 in
  let i2' = (float_of_int (2 * i2 + l)) /. 2. in
  let len2' = float_of_int len2 in
  let q = abs_float ((i1' /. len1') -. (i2' /. len2'))
  in
  (-l, -ch1_idx, q)

let quality_1 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t = (-l, ch1_idx, 0.0)

let quality_2 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t = (-l, -ch1_idx, 0.0)

let quality_3 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t = (ch1_idx, -l, 0.0)

let quality_4 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t = (-ch1_idx, -l, 0.0)

let quality_5 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t =
  let i1' = (float_of_int (2 * i1 + l)) /. 2. in
  let len1' = float_of_int len1 in
  let i2' = (float_of_int (2 * i2 + l)) /. 2. in
  let len2' = float_of_int len2 in
  let l' = float_of_int l in
  let correction = 0.3 *. abs_float ((i1' /. len1')
        -. (i2' /. len2')) in
  let q = l' /. (min len1' len2') -. correction
  in
  (0, -ch1_idx, 0.0 -. q)

let quality_6 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t =
  let i1' = (float_of_int (2 * i1 + l)) /. 2. in
  let len1' = float_of_int len1 in
  let i2' = (float_of_int (2 * i2 + l)) /. 2. in
  let len2' = float_of_int len2 in
  let l' = float_of_int l in
  let correction = 0.3 *. abs_float ((i1' /. len1')
        -. (i2' /. len2')) in
  let q = l' /. (min len1' len2') -. correction
  in
  (-l, -ch1_idx, 0.0 -. q)

let quality_7 (l: int) (i1: int) (len1: int)
            (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t =
  let i1' = (float_of_int (2 * i1 + l)) /. 2. in
  let len1' = float_of_int len1 in
  let i2' = (float_of_int (2 * i2 + l)) /. 2. in
  let len2' = float_of_int len2 in
  let l' = float_of_int l in
  let correction = 0.3 *. abs_float ((i1' /. len1')
        -. (i2' /. len2')) in
  let q = l' /. (min len1' len2') -. correction
  in
  (-l, ch1_idx, 0.0 -. q)

let quality_8 (l: int) (i1: int) (len1: int)
        (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t
  = quality_live l i1 len1 i2 len2 ch1_idx

let quality_9 (l: int) (i1: int) (len1: int)
        (i2: int) (len2: int) (ch1_idx: int)
    : match_quality_t =
  let i1' = (float_of_int (2 * i1 + l)) /. 2. in
  let len1' = float_of_int len1 in
  let i2' = (float_of_int (2 * i2 + l)) /. 2. in
  let len2' = float_of_int len2 in
  let q = abs_float ((i1' /. len1') -. (i2' /. len2'))
  in
  (-l, ch1_idx, q)


let m_quality_func = ref quality_live

let set_match_quality (i: int) =
  if i = 0 then m_quality_func := quality_live
  else if i = 1 then m_quality_func := quality_1
  else if i = 2 then m_quality_func := quality_2
  else if i = 3 then m_quality_func := quality_3
  else if i = 4 then m_quality_func := quality_4
  else if i = 5 then m_quality_func := quality_5
  else if i = 6 then m_quality_func := quality_6
  else if i = 7 then m_quality_func := quality_7
  else if i = 8 then m_quality_func := quality_live
  else if i = 9 then m_quality_func := quality_9

let make_index_diff (words: word array) : index_t =
  let len = Array.length words in
  let idx = Hashtbl_bounded.create (1 + len)
        (10 * max_matches) in
  for i = 0 to len - 2 do
    let word_tuple = (words.(i), words.(i + 1)) in
    Hashtbl_bounded.add idx word_tuple i
  done;
  idx;;

let get_matches matched idx word_tuple =
  if Hashtbl_bounded.mem idx word_tuple then begin
    let all_matches =
        Hashtbl_bounded.find_all idx word_tuple in
    let filt i = matched.(i) = 0 in
    let matches = List.filter filt all_matches in
    if (List.length all_matches) > max_matches then begin
      (* too many, so empty list *)
      Hashtbl_bounded.remove_all idx word_tuple;
      [];
    end else matches;
  end else [];;

(* This function is directly based on the
 * code included in Reichenberger1991, but
 * modified to respect the values in matched1/2.
 *)
let build_reichenberger
            (w1: word array) (w2: word array)
            matched1
            matched2
            l1 l2 =
  let editscript = ref [] in
  let idx2 = make_index_diff w2 in
  let oldPos = ref 0 in
  let addStart = ref 0 in
  let emitAdd () =
    if !addStart < !oldPos then begin
      let k = !oldPos - !addStart in
      editscript := Del (!addStart, k) :: !editscript;
      for i = !addStart to !oldPos-1 do
        matched1.(i) <- !oldPos - i;
      done;
    end
  in
  while !oldPos < l1 - 2 do
    (* for every unmatched word in w1,
     * find list of matches in w2 *)
    if matched1.(!oldPos) = 0 then begin
      let word_tuple = (w1.(!oldPos), w1.(!oldPos+1)) in
      let matches = get_matches matched2 idx2 word_tuple in
      let i1 = !oldPos in
      let heap = Heap.create () in
      let process_match (i2: int) =
        let k = ref 1 in
        while i1 + !k < l1 && i2 + !k < l2
        && w1.(i1 + !k) = w2.(i2 + !k) do
          k := !k + 1;
        done;
        let q = !m_quality_func !k i1 l1 i2 l2 0 in
        ignore (Heap.add heap (!k, i1, i2) q);
      in
      List.iter process_match matches;
      if not (Heap.is_empty heap) then begin
        let m = Heap.take heap in
        let (copyLen, i1',  copyStart) = m.Heap.contents in
        if copyLen >= thumper_min_copy_len then begin
          emitAdd ();
          editscript := Mov (!oldPos, copyStart, copyLen)
            :: !editscript;
          for i = 0 to copyLen - 1 do
	    let nextMatch = copyLen - i in
            matched2.(copyStart + i) <- nextMatch;
            matched1.(!oldPos + i) <- nextMatch;
          done;
          oldPos := !oldPos + copyLen;
          addStart := !oldPos;
        end else
          oldPos := !oldPos + 1;
      end else
        oldPos := !oldPos + 1;
    end else begin
      if !addStart < !oldPos then emitAdd ();
      oldPos := !oldPos + matched1.(!oldPos);
      addStart := !oldPos;
    end;
  done;
  (* we can skip the final emitAdd, since
   * cover_unmatched will cleanup *)
  editscript;;

let compute_heap
            (w1: word array) (w2: word array)
            matched1 matched2
            skipmatch eachk maxk =
  let l1 = Array.length w1 in
  let l2 = Array.length w2 in
  let idx1 = make_index_diff w1 in
  let prev_matches = ref [] in
  let i2 = ref 0 in
  while !i2 < l2 - 1 do
    let skip = matched2.(!i2) in
    if skip = 0 then begin
      let word_tuple = (w2.(!i2), w2.(!i2+1)) in
      let matches = get_matches matched1 idx1 word_tuple in
      let process_match (i1: int) =
        if not (skipmatch i1 !i2 prev_matches) then begin
          let k = ref 1 in
          eachk i1 l1 !i2 l2 !k;
          while i1 + !k < l1 && !i2 + !k < l2
          && w1.(i1 + !k) = w2.(!i2 + !k) do
            eachk i1 l1 !i2 l2 (!k + 1);
            k := !k + 1;
          done;
          maxk i1 l1 !i2 l2 !k
        end
      in
      List.iter process_match matches;
      prev_matches := matches;
    end else prev_matches := [];
    i2 := !i2 + (max 1 skip)
  done;;

(**
 * This version only puts the longest matches in the heap,
 * and it only checks the list of previous matches
 * from the last match to see if a new match
 * should be added.
 *)
let build_heap_fastpm
            (w1: word array) (w2: word array)
            matched1 matched2 =
  let heap = Heap.create () in
  let skipmatch i1 i2 prev_matches =
    (* if (i1-1) is in prev_matches, then we've
     * already investigated a longer match
     * starting at (i1-1, i2-1) (or even earlier),
     * so we can skip this one *)
    List.mem (i1 - 1) !prev_matches
  in
  let eachk i1 l1 i2 l2 k = () in
  let maxk i1 l1 i2 l2 k =
    if k >= thumper_min_copy_len then begin
      let q = !m_quality_func k i1 l1 i2 l2 0 in
      ignore (Heap.add heap (k, i1, i2) q);
    end
  in
  compute_heap w1 w2 matched1 matched2 skipmatch eachk maxk;
  heap

(** This version only puts the longest match into
 * the heap, but uses a hashtable to keep track of
 * what matches have been made, rather than just
 * checking the previous list of matches.
 *)
let build_heap_fasthash
            (w1: word array) (w2: word array)
            matched1 matched2 =
  let len1 = Array.length w1 in
  let len2 = Array.length w2 in
  let matched = Hashtbl.create (len1 + len2) in
  let heap = Heap.create () in
  let skipmatch i1 i2 prev_matches =
    let idx = (i1, i2) in
    try Hashtbl.find matched idx
    with Not_found -> false
  in
  let eachk i1 l1 i2 l2 k = () in
  let maxk i1 l1 i2 l2 k =
    if k >= thumper_min_copy_len then begin
      for i = 0 to (k-1) do
        let idx = (i1+i, i2+i) in
        Hashtbl.replace matched idx true
      done;
      let q = !m_quality_func k i1 l1 i2 l2 0 in
      ignore (Heap.add heap (k, i1, i2) q);
    end
  in
  compute_heap w1 w2 matched1 matched2 skipmatch eachk maxk;
  heap

(** This version of heap building is the slowest,
 * because it includes every single possible match
 * in the heap, not just the longest possible
 * match.  This ends up using a very large amount
 * of memory; on the order of gigabytes, versus
 * the roughly 500MB that the longest-match
 * version uses for the PAN2010 evaluation.
 *)
let build_heap_slow
            (w1: word array) (w2: word array)
            matched1 matched2 =
  let heap = Heap.create () in
  let skipmatch i1 i2 prev_matches = false
  in
  let eachk i1 l1 i2 l2 k =
    if k >= thumper_min_copy_len then begin
      let q = !m_quality_func k i1 l1 i2 l2 0 in
      ignore (Heap.add heap (k, i1, i2) q);
    end
  in
  let maxk i1 l1 i2 l2 k =
    (* already done in eachk *)
    ()
  in
  compute_heap w1 w2 matched1 matched2 skipmatch eachk maxk;
  heap

(**
 * Find a region where 'test' is 0,
 * and return the bounds of that region.
 * The 'test' parameter otherwise tells
 * us an upper bound on how far forward
 * we can safely skip.
 *)
let scan_and_test len test =
  let rec find_start curstart =
    if curstart >= len then curstart
    else begin
      let incr = test curstart in
      if incr = 0 then curstart
      else find_start (curstart + incr)
    end
  in
  let rec find_finish curend =
    if curend >= len then curend
    else begin
      let incr = test curend in
      if incr > 0 then curend
      else find_finish (curend + 1)
    end
  in
  let start = find_start 0 in
  let finish = find_finish (start + 1) in
  if start >= len then (-1, -1)
  else (start, finish)
  ;;

let process_best_matches heap matched1 matched2 l1 l2 =
  let editscript = ref [] in
  let record_match i1 i2 k =
    editscript := Mov (i1, i2, k) :: !editscript;
    for i = 0 to k-1 do
      let nextMatch = k - i in
      matched1.(i1 + i) <- nextMatch;
      matched2.(i2 + i) <- nextMatch;
    done
  in
  let make_test i1 i2 =
    let is_matched offset =
      max matched1.(i1 + offset) matched2.(i2 + offset)
    in
    is_matched
  in
  let rec add_smaller i1 i2 start finish limit =
    if start >= 0 then begin
      let k = finish - start in
      let i1 = i1 + start in
      let i2 = i2 + start in
      if k >= thumper_min_copy_len then begin
        let q = !m_quality_func k i1 l1 i2 l2 0 in
        ignore (Heap.add heap (k, i1, i2) q)
      end;
      (* compute range for next possible sub-match *)
      let i1 = i1 + k in
      let i2 = i2 + k in
      let limit = limit - finish in
      let is_matched = make_test i1 i2 in
      let (start, finish) = scan_and_test limit is_matched in
      add_smaller i1 i2 start finish limit
    end else ()
  in
  let heaplen = Heap.length heap in
  if heaplen > !max_heaplen + 1000 then begin
    max_heaplen := heaplen;
    print_endline
      (Printf.sprintf "new max heap: %d" !max_heaplen);
    flush stdout;
  end;
  if heaplen > 1000000 then begin
    raise Heap_Too_Large;
  end;
  while not (Heap.is_empty heap) do
    let m = Heap.take heap in
    let (k, i1,  i2) = m.Heap.contents in
    let (start, finish) = scan_and_test k (make_test i1 i2) in
    if start >= 0 then begin
      if finish - start = k then begin
        (* the whole sequence is still unmatched *)
        record_match i1 i2 k
      end else begin
        (* found an unmatched subregion, but it's for less
         * than the size we were hoping for.  So we must add
         * the smaller matches back into the heap... starting
         * with the match we just found. *)
        add_smaller i1 i2 start finish k
      end;
    end;
  done;
  editscript
  ;;

let cover_unmatched matched len editScript op =
  let i = ref 0 in
  let l = ref len in
  let complete = ref false in
  while not !complete do
    let test x = matched.(!i + x) in
    let (start, finish) = scan_and_test !l test in
    if start >= 0 then begin
      let tuple = op (!i + start) (finish - start) in
      editScript := tuple :: !editScript;
      i := !i + finish;
      l := !l - finish;
    end
      else complete := true
  done;
  editScript
  ;;

let match_endpoint (w1: word array) (w2: word array)
            matched1 matched2 xform1 xform2 =
  let l1 = Array.length w1 in
  let l2 = Array.length w2 in
  let k = min l1 l2 in
  let rec find_first_nonmatch x =
    if x >= k then k
    else begin
      let i1 = xform1 x in
      let i2 = xform2 x in
      if matched1.(i1) > 0 || matched2.(i2) > 0
	|| w1.(i1) <> w2.(i2)
      then x
      else find_first_nonmatch (x + 1)
    end
  in
  let nonmatch = find_first_nonmatch 0 in
  if nonmatch > 0 then begin
    let endpoint1 = max (xform1 (-1)) nonmatch in
    let endpoint2 = max (xform2 (-1)) nonmatch in
    for i = 0 to nonmatch - 1 do
      matched1.(xform1 i) <- abs (endpoint1 - i);
      matched2.(xform2 i) <- abs (endpoint2 - i);
    done;
    let beginpt1 = min (xform1 0) (xform1 (nonmatch-1)) in
    let beginpt2 = min (xform2 0) (xform2 (nonmatch-1)) in
    [ Mov (beginpt1, beginpt2, nonmatch) ];
  end else [ ]
  ;;

let match_header (w1: word array) (w2: word array)
            matched1 matched2 =
  let xform1 x = x in
  let xform2 x = x in
  match_endpoint w1 w2 matched1 matched2 xform1 xform2
  ;;

let match_trailer (w1: word array) (w2: word array)
        matched1 matched2 =
  let l1 = Array.length w1 in
  let l2 = Array.length w2 in
  let xform1 x = l1 - x - 1 in
  let xform2 x = l2 - x - 1 in
  match_endpoint w1 w2 matched1 matched2 xform1 xform2
  ;;

let match_nothing (w1: word array) (w2: word array)
        matched1 matched2 = [ ]
let makeDel i l = Del (i, l)
let makeIns i l = Ins (i, l)

let core_diff w1 w2 mkHeader mkTrailer mkEditScript =
  let l1 = Array.length w1 in
  let l2 = Array.length w2 in
  let matched1 = Array.make l1 0 in
  let matched2 = Array.make l2 0 in
  let header = mkHeader w1 w2 matched1 matched2 in
  let trailer = mkTrailer w1 w2 matched1 matched2 in
  let editScript =
      mkEditScript w1 w2 matched1 matched2 l1 l2 in
  let editScript = cover_unmatched matched1 l1
    editScript makeDel in
  let editScript = cover_unmatched matched2 l2
    editScript makeIns in
  header @ !editScript @ trailer

let diff_1 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    build_reichenberger w1 w2 matched1 matched2 l1 l2 in
  core_diff w1 w2
        match_nothing match_nothing
        myCore

let diff_2 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    build_reichenberger w1 w2 matched1 matched2 l1 l2 in
  core_diff w1 w2
        match_header match_trailer
        myCore

let diff_3 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    let heap =
        build_heap_fasthash w1 w2 matched1 matched2 in
    process_best_matches heap matched1 matched2 l1 l2
  in
  core_diff w1 w2
        match_header match_trailer
        myCore

let diff_4 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    let heap = build_heap_fastpm w1 w2 matched1 matched2 in
    process_best_matches heap matched1 matched2 l1 l2
  in
  core_diff w1 w2
        match_nothing match_nothing
        myCore

let diff_5 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    let heap = build_heap_fastpm w1 w2 matched1 matched2 in
    process_best_matches heap matched1 matched2 l1 l2
  in
  core_diff w1 w2
        match_header match_trailer
        myCore

let diff_8 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    let heap = build_heap_fasthash w1 w2 matched1 matched2 in
    process_best_matches heap matched1 matched2 l1 l2
  in
  core_diff w1 w2
        match_nothing match_nothing
        myCore

let diff_9 (w1: word array) (w2: word array) =
  let myCore w1 w2 matched1 matched2 l1 l2 =
    let heap = build_heap_slow w1 w2 matched1 matched2 in
    process_best_matches heap matched1 matched2 l1 l2
  in
  core_diff w1 w2
        match_header match_trailer
        myCore



let diff_func = ref diff_1

let set_diff (i: int) =
  if i = 1 then diff_func := diff_1
  else if i = 2 then diff_func := diff_2
  else if i = 3 then diff_func := diff_3
  else if i = 4 then diff_func := diff_4
  else if i = 5 then diff_func := diff_5
  else if i = 8 then diff_func := diff_8
  else if i = 9 then diff_func := diff_9

let edit_diff (words1: word array) (words2: word array)
  : edit list = !diff_func words1 words2

