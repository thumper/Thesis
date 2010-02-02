(* category.ml: builds a category hierarchy graph and provides analysis
   functions *)

(*

Copyright (c) 2007-2008
  Gillian Smith <gsmith@soe.ucsc.edu>
  Bo Adler <thumper@alumni.caltech.edu>
All rights reserved.

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



(* Types/modules *)

type pageid = int
type pagename = string
type catid = int
type catname = string

module CatSet = Set.Make(struct
			    type t = catid
			    let compare = compare
			 end)
module PageSet = Set.Make(struct
			    type t = pageid
			    let compare = compare
			  end)


(* Define category graph class *)  
class catgraph
  (graphfiledir_init: string) (* Directory containing graph files, usually in /home/share/catinfo/ *)
  =
object (self)
  val graphfiledir = graphfiledir_init
    
  val catids    : (catname, catid)    Hashtbl.t = Hashtbl.create 10000   (* Name -> ID lookup *)
  val catnames  : (catid,   catname)  Hashtbl.t = Hashtbl.create 10000   (* ID -> Name lookup *)
  val pagenames : (pageid,  pagename) Hashtbl.t = Hashtbl.create 100000  (* Page ID -> Page name lookup *)
  val graph     : (catid,   catid)    Hashtbl.t = Hashtbl.create 10000   (* Stores category hierarchy *)
  val mutable numcats  : int = 0
  val mutable listids : catid list = []

  (* Builds the graph - assumes perl script has already been run, read files *)
  method build_graph  : unit =
    begin
      self#read_ids;
      self#read_graph;
      (*self#read_pageids;
      self#read_pagegraph;*)
      numcats <- Hashtbl.length catids;
    end

  method get_n_subcategories (id: catid) n : CatSet.t =
    let graphcp = Hashtbl.copy graph in
    let rec dfs curr setref depth =
      if (depth == 0) then
	()
      else
	begin
	  setref := CatSet.add curr !setref;
	  let subcatslst = ref (Hashtbl.find_all graphcp curr) in
	    while (List.length !subcatslst) > 0 do
	      begin
		if (CatSet.mem (List.hd !subcatslst) !setref) then
		  subcatslst := (List.tl !subcatslst)
		else
		  begin
		    dfs (List.hd !subcatslst) setref (depth - 1);
		    subcatslst := (List.tl !subcatslst)
		  end
	      end
	    done
	end
    in
    let set = ref CatSet.empty in
      begin
	dfs id set n;
	!set
      end
      
  (* Returns list containing all subcategories from ID *)
  method get_all_subcategories (id: catid) : CatSet.t =
    let outfile = open_out "tempparchild.txt" in
    let print_parent_and_children par lst =
      let rec helper lst =
	if (List.length lst) == 0 then
	  ()
	else
	  begin
	    Printf.fprintf outfile " %s " (Hashtbl.find catnames (List.hd lst));
	    helper (List.tl lst);
	  end
      in
	begin
	  Printf.fprintf outfile "%s -- " (Hashtbl.find catnames par);
	  helper lst;
	  Printf.fprintf outfile "\n";
	end
    in
    let print_set_contents set =
      let print_func elem =
	Printf.printf " %s " (Hashtbl.find catnames elem);
      in
	begin
	  (*Printf.printf "Frontier contents: ";*)
	  CatSet.iter print_func set;
	  Printf.printf "\n";
	end
    in
    let rec add_list_elems_to_set setref duplicateref list =
      if (List.length list) == 0 then
	!setref
      else
	begin
	  if (not (CatSet.mem (List.hd list) !duplicateref)) then
	    setref := CatSet.add (List.hd list) !setref;
	  add_list_elems_to_set setref duplicateref (List.tl list)
	end
    in
    let rec calctrans frontierref seed seenref transref =
      if (CatSet.is_empty !frontierref) then
	!transref
      else
	let t = CatSet.choose !frontierref in
	let addtofrontier = Hashtbl.find_all graph t in
	  begin
	    (*Print parent and children*)
	    print_parent_and_children t addtofrontier;
	    (*Add successors of t to the frontier, if they haven't already been seen*)
	    frontierref := add_list_elems_to_set frontierref seenref addtofrontier;
	    (*Remove element from frontier*)
	    frontierref := CatSet.remove t !frontierref;
	    (*Add element to set of seen nodes*)
	    seenref := CatSet.add t !seenref;
	    (*Add element to the transitive closure*)
	    transref := CatSet.add t !transref;
	    (*Keep going*)
	    calctrans frontierref seed seenref transref
	  end
    in
    let frontierref = ref CatSet.empty in
    let transref = ref CatSet.empty in
    let seenref = ref CatSet.empty in
    let subcats = ref CatSet.empty in
      begin
	frontierref := add_list_elems_to_set frontierref seenref (Hashtbl.find_all graph id);
	(*CatSet.iter (Hashtbl.add trans id) (calctrans frontierref id seenref transref);
	  trans*)
	subcats := (calctrans frontierref id seenref transref);
	close_out outfile;
	!subcats
      end


  (* Prints hierarchy for id to file with name filename *)
  method print_all_subcategories id filename : unit =
    let subcats = CatSet.elements (self#get_all_subcategories id) in
    let outfile = open_out filename in
      (*let print_hash key value =
	Printf.fprintf outfile "%s -- %s\n" (Hashtbl.find catnames key) (Hashtbl.find catnames value)
	in*)
    let print_listsubcats memid =
      Printf.fprintf outfile "\t%d %s\n" memid (Hashtbl.find catnames memid)
    in
      begin
	Printf.fprintf outfile "Parent: %d %s\n" id (Hashtbl.find catnames id);
	List.iter print_listsubcats subcats;
	(*Hashtbl.iter print_hash hier;*)
	close_out outfile;
      end

  method print_n_subcategories id n filename : unit =
    let subcats = CatSet.elements (self#get_n_subcategories id n) in
    let outfile = open_out filename in
    let print_listsubcats memid =
      Printf.fprintf outfile "\t%d %s\n" memid (Hashtbl.find catnames memid)
    in
      begin
	Printf.fprintf outfile "Parent: %d %s\n" id (Hashtbl.find catnames id);
	List.iter print_listsubcats subcats;
	close_out outfile;
      end
	
  (* Returns list of all ids stored in the graph (same as getkeys) *)
  method get_listids : catid list =
    listids;
    

  (* Get the name of a category given an ID *)
  method get_category_name id : catname =
    Hashtbl.find catnames id
      
  (* Get the ID of a category given the name *)
  method get_category_id name : catid =
    Hashtbl.find catids name

  (* Gets a list of subcategories for given id *)
  method get_subcategories id : catid list =
    Hashtbl.find_all graph id

      
  (* Get a set of all pages in the category *)
  method get_pages_in_category id : PageSet.t =
    self#read_pagegraph (CatSet.singleton id)

  (* Get a set of all pages in the full subcategory hierarchy *)
  method get_pages_in_full_category id : PageSet.t =
    self#read_pagegraph (self#get_all_subcategories id)	  

  (* Get a set of all pages in n subcategories from id *)
  method get_pages_in_n_subcategories id n : PageSet.t =
    self#read_pagegraph (self#get_n_subcategories id n)

  (* Print pages in the given category to a file *)
  method print_pages_in_category id filename : unit =
    let pages = PageSet.elements (self#get_pages_in_category id) in
    let outfile = open_out filename in
    let rec printpages lst =
      if (List.length lst) == 0 then
	()
      else
	begin
	  Printf.fprintf outfile "Page: %d\n" (List.hd lst);
	  printpages (List.tl lst)
	end
    in
      begin
	Printf.fprintf outfile "Pages in category %s (ID: %d)\n" (Hashtbl.find catnames id) id;
	printpages pages;
	close_out outfile
      end
	
  (* Print pages in the full category to a file *)
  method print_pages_in_full_category id filename : unit =
    let pages = PageSet.elements (self#get_pages_in_full_category id) in
    let outfile = open_out filename in
    let rec printpages lst =
      if (List.length lst) == 0 then
	()
      else
	begin
	  Printf.fprintf outfile "Page: %d\n" (List.hd lst);
	  printpages (List.tl lst)
	end
    in
      begin
	Printf.fprintf outfile "Pages in full category %s (ID: %d)\n" (Hashtbl.find catnames id) id;
	printpages pages;
	close_out outfile
      end

  (* Print pages in n subcategories to a file *)
  method print_pages_in_n_subcategories id n filename : unit =
    let pages = PageSet.elements (self#get_pages_in_n_subcategories id n) in
    let outfile = open_out filename in
    let rec printpages lst =
      if (List.length lst) == 0 then
	()
      else
	begin
	  Printf.fprintf outfile "Page: %d\n" (List.hd lst);
	  printpages (List.tl lst)
	end
    in
      begin
	Printf.fprintf outfile "Pages in %d subcategories of %s (ID: %d)\n" n (Hashtbl.find catnames id) id;
	printpages pages;
	close_out outfile
      end
	
  (* Get the total number of categories *)
  method get_num_categories : int =
    numcats

  (* Get the total number of subcategories for a given category *)
  method get_num_subcategories ?id ?name () : int = 
    match (id, name) with
	(None  , None  ) -> failwith "No argument given to get_num_subcategories."
      | (None  , Some n) -> let cid = Hashtbl.find catids n in List.length (Hashtbl.find_all graph cid)
      | (Some i, None  ) -> List.length (Hashtbl.find_all graph i)
      | (_     , _     ) -> failwith "Only provide one argument to get_num_subcategories."
	  

  (* Private method, reads the idname.txt file created with perl script *)
  method private read_ids : unit =
    let infile = open_in (graphfiledir ^ "catidname.txt") in
    let rec read_ids_helper () =
      let line = input_line infile in
	(*Split the line into ID and name*)
      let splitline = Str.split (Str.regexp "[ \t]+") line in
	(*Add to catids and catnames -- format is "id -- name"*)
      let id = (int_of_string (List.nth splitline 0)) in
      let name = List.nth splitline 2 in
	begin
	  (*print_string ((string_of_int id) ^ " -- " ^ name ^ "\n");*)
	  listids <- id::listids;
	  Hashtbl.add catids name id;
	  Hashtbl.add catnames id name;
	  read_ids_helper ();
	end
    in
      Printf.printf "reading catidname.txt\n";  (* THUMPER DEBUG *)
      flush stdout;
      try read_ids_helper () with e -> close_in_noerr infile;
      Printf.printf "done reading catidname.txt\n";  (* THUMPER DEBUG *)
      flush stdout;

  (* Private method, reads the graph.txt file created with perl script *)
  method private read_graph : unit =
    let infile = open_in (graphfiledir ^ "graph.txt") in
    let rec read_graph_helper () =
      let line = input_line infile in
	(*Split the line into ID and list of child cats *)
      let halfsplit = Str.bounded_split (Str.regexp "[ \t]+") line 3 in
      let parentid = (int_of_string (List.nth halfsplit 0)) in
      let listchildren = Str.split (Str.regexp "[ \t]+") (List.nth halfsplit 2) in
	begin
	  let childrenints = List.rev_map int_of_string listchildren in
	    (*Add each child to graph*)
	    List.iter (Hashtbl.add graph parentid) childrenints;
	    (*Move on to the next line *)
	    read_graph_helper ();
	end
    in
      Printf.printf "reading graph.txt\n";  (* THUMPER DEBUG *)
      flush stdout;
      try read_graph_helper () with e -> close_in_noerr infile;
      Printf.printf "done reading graph.txt\n";  (* THUMPER DEBUG *)
      flush stdout;


  method private read_pageids : unit =
    let infile = open_in (graphfiledir ^ "pageidname.txt") in
    let rec read_ids_helper () =
      let line = input_line infile in
	(*Split the line into ID and name*)
      let splitline = Str.split (Str.regexp "[ \t]+") line in
	(*Add to pagenames -- format is "id -- name"*)
      let id = (int_of_string (List.nth splitline 0)) in
      let name = List.nth splitline 2 in
	begin
	  (*print_string ((string_of_int id) ^ " -- " ^ name ^ "\n");*)
	  Hashtbl.add pagenames id name;
	  read_ids_helper ();
	end
    in
      Printf.printf "reading pageidname.txt\n";  (* THUMPER DEBUG *)
      flush stdout;
      try read_ids_helper () with e -> close_in_noerr infile;
      Printf.printf "done reading pageidname.txt\n";  (* THUMPER DEBUG *)
      flush stdout;


  method private read_pagegraph (cats: CatSet.t) : PageSet.t =
    let infile = open_in (graphfiledir ^ "catpages.txt") in
    let pagelist members = Str.split (Str.regexp "[ \t]+") members in
    let rec read_pagegraph_line pages =
	let add_page pageid = pages := (PageSet.add (int_of_string pageid) !pages) in
	let handle_cat catnum members =
	    if (CatSet.mem catnum cats) then
		ignore (List.map add_page (pagelist members));
	in
	let line = input_line infile in
	(* NOTE: for some reason, fscanf does not work here. *)
	Scanf.sscanf line "%d -- %s@\n" handle_cat;
	read_pagegraph_line pages;
    in
    let pages = ref PageSet.empty in
    Printf.printf "reading catpages.txt\n";  (* THUMPER DEBUG *)
    flush stdout;
    try
	read_pagegraph_line pages;
    with End_of_file ->
	begin
	    Printf.printf "done reading catpages.txt\n";  (* THUMPER DEBUG *)
	    flush stdout;
	    close_in_noerr infile;
	end;
    !pages;
end
