// Copyright 2009, B. Thomas Adler

(function() {
    var prefService = Components.classes["@mozilla.org/preferences-service;1"].
		getService(Components.interfaces.nsIPrefBranch);

    function getPrefBool(pref, defval) {
	var prefname = "extensions.wikitrust." + pref;
	try {
	    var value = prefService.getBoolPref(prefname);
	    return value;
	} catch (ex) {
	    prefService.setBoolPref(prefname, defval);
	    return defval;
	}
    }

    function getPrefStr(pref, defval) {
	var prefname = "extensions.wikitrust." + pref;
	try {
	    var value = prefService.getCharPref(prefname);
	    return value;
	} catch (ex) {
	    return defval;
	}
    }

    var aConsoleService = Components.classes["@mozilla.org/consoleservice;1"].
		getService(Components.interfaces.nsIConsoleService);

    function log(str) {
	var now = new Date();
	aConsoleService.logStringMessage("wikitrust: "
		+ now.getTime() + ": " + str);
    }

    function http_get(path, success, failure) {
	if (!path) return failure(null);
	var request = new XMLHttpRequest();
	request.onreadystatechange = function() {
	    log("http_get: readyState=" + request.readyState + ", status=" + request.status + ", path=" + path);
	    if(request.readyState == 4)
	      if(request.status == 200) {
		success(request);
		var entry = {
		    url: path,
		    req: request
		};
	      } else
		failure(request);
	};
	request.open('GET', path, true);
	request.setRequestHeader("Cache-Control", "max-age=0");
	request.send(null);
    }

    function getQueryVariable(search, varname) {
	var query = search.substring(1);
	var vars = query.split('&');
	for (var i = 0; i < vars.length; i++) {
	    var pair = vars[i].split('=');
	    if (pair[0] == varname)
		return pair[1];
	}
	return '';
    }

    function isEnabledWiki(loc) {
	var hostname = "en.wikipedia.org";
	hostname = getPrefStr('hostname', hostname);
	if (loc.host == hostname) return true;
	else return false;
    }

    function getTitleFUrl(loc) {
	var title = getQueryVariable(loc.search, 'title');
	if (title != '') return title;
	var match = /^\/wiki\/(.*)$/.exec(loc.pathname);
	if (match[1] != '') return match[1];
	match = /^\/w\/index\.php\/(.*)$/.exec(loc.pathname);
	if (match[1] != '') return match[1];
	
	return null;
    }

    function getWikiTrustURL(loc) {
	if (/&diff=/.test(loc.search)) return null;
	if (/&action=/.test(loc.search)) return null;
	var title = getTitleFUrl(loc);
	var revID = getQueryVariable(loc.search, 'oldid');
	if (revID == '') revID = getQueryVariable(loc.search, 'diff');

	if (revID == '' && title == '') {
	    log("Couldn't figure out vars from: " + loc.href);
	    return null;
	}

	if (getPrefBool('newapi', false)) {
	    var defaultUrl = 'http://redherring.cse.ucsc.edu/firefox/frontend/index.php';
	    var url = getPrefStr('ajaxurl', defaultUrl);
	    url = url + '?action=ajax&rs=WikiTrust::ajax_getColoredText'
		+ '&rsargs[]=' + escape(title)
		+ '&rsargs[]='
		+ '&rsargs[]=' + revID;
	    return url;
	} else {
	    return 'http://wiki-trust.cse.ucsc.edu/index.php?title=' + escape(title) + '&oldid=' + revID;
	}
    }

    function getStrippedURL(loc) {
	if (/&diff=/.test(loc.search) || /&action=/.test(loc.search)
		|| /trust/.test(loc.search))
	{
	    var title = getTitleFUrl(loc);
	    log("stripped action: title = " + title);
	    return "/wiki/" + title;
	}
	log("stripped nothing: search = " + loc.search);
	return loc.pathname + loc.search;
    }

    function getTrustTabURL(loc) {
	if (/[?&]trust/.test(loc.search)) return loc.href;
	var url = getStrippedURL(loc);
	if (/\?/.test(url)) return url + '&trust';
	else return url + '?trust';
    }

    function fixHrefs(node) {
        if (node.nodeName == 'A') {
            var url = node.getAttribute('HREF');
	    if (url) {
		if (!getPrefBool('newapi', false))
		    url = url.replace(/^\/index\.php\//, '/wiki/');
		var sep = '&';
		if (url.indexOf('?') == -1) {
		    sep = '?';
		}
		var add = false;
		if (/^\/wiki\//.test(url))
		    add = true;
		if (/^\/w\/index\.php/.test(url))
		    add = true;
		if (add)
		    url += sep + 'trust';
		node.setAttribute('HREF', url);
	    }
        }
        var children = node.childNodes;
        for (var i=0; i<children.length; i++) {
            fixHrefs(children[i]);
        }
    }

    function getWarningBox(page) {
	var div = page.createElement('div');
	div.setAttribute('id', 'mw-revision-info');
	var provider = "the <a href='http://wiki-trust.cse.ucsc.edu/' class='external text'>WikiTrust</a> project";
	if (getPrefBool('newapi', false))
	    provider = "the new WikiTrust AJAX API";
	div.innerHTML="<table id='revision-info' class='plainlinks fmbox fmbox-warning' style='clear: both; margin: 0.2em 0; border: 1px solid #aaa; background: #f9f9f9; width: 100%; background: #FFDBDB; border: 1px solid #BB7070;'><tr><td class='mbox-text'><b>This is an old revision, as provided by "+provider+".  It may differ significantly from the current revision.</b></td></tr></table>";
	return div;
    }

    function addTrustHeaders(page) {
	var css = page.createElement('style');
	//css.setAttribute('type', 'text/css');
	css.innerHTML= ".trust0 {\n"
	    + "background-color:#FFB947;\n"
	    + "}\n"
	    + ".trust1 {\n"
	    + "background-color:#FFC05C;\n"
	    + "}\n"
	    + ".trust2 {\n"
	    + "background-color:#FFC870;\n"
	    + "}\n"
	    + ".trust3 {\n"
	    + "background-color:#FFD085;\n"
	    + "}\n"
	    + ".trust4 {\n"
	    + "background-color:#FFD899;\n"
	    + "}\n"
	    + ".trust5 {\n"
	    + "background-color:#FFE0AD;\n"
	    + "}\n"
	    + ".trust6 {\n"
	    + "background-color:#FFE8C2;\n"
	    + "}\n"
	    + ".trust7 {\n"
	    + "background-color:#FFEFD6;\n"
	    + "}\n"
	    + ".trust8 {\n"
	    + "background-color:#FFF7EB;\n"
	    + "}\n"
	    + ".trust9 {\n"
	    + "background-color:#FFFFFF;\n"
	    + "}\n"
	    + ".trust10 {\n"
	    + "background-color:#FFFFFF;\n"
	    + "}\n";

	var script = page.createElement('script');
	script.innerHTML = 'function showOrigin(revnum) { document.location.href = "/w/index.php?title=" + wgPageName + "&oldid=" + revnum; }';

	var head = page.getElementsByTagName('head')[0];
	head.appendChild(css);
	head.appendChild(script);

	var tooltipURL = 'http://redherring.cse.ucsc.edu/firefox/frontend/extensions/Trust/js/wz_tooltip.js';
	// var tooltipURL = 'http://www.soe.ucsc.edu/~thumper//wz_tooltip.js';
	log("Requesting tooltip url = " + tooltipURL);
	http_get(tooltipURL,
	    function (req) {
		var script = page.createElement('script');
		script.innerHTML = req.responseText;
		head.appendChild(script);
	    },
	    function (req) {
		log("ERROR downloading tooltip code, status = " + req.status);
	    });
	return null;
    }

    function max(a,b) { return (a > b) ? a : b; }

    function darkenPage(page) {
	var dropSheet=page.createElement('div');
	dropSheet.setAttribute('id','dropSheet');
	dropSheet.style.position = 'absolute';
	dropSheet.style.top = '0px';
	dropSheet.style.left = '0px';
	dropSheet.style.overflow = 'hidden';
	dropSheet.style.MozOpacity = 0.7;
	dropSheet.style.zIndex = 20;
	dropSheet.style.backgroundColor='#000000';
	dropSheet.style.width='100%';
	dropSheet.style.height='100%';

	var body = page.getElementsByTagName('body')[0];
	var dropSheetWidth=max(body.scrollWidth,page.documentElement.clientWidth);
	var dropSheetHeight=max(body.scrollHeight,document.documentElement.clientHeight);

	dropSheet.style.width=dropSheetWidth+'px';
	dropSheet.style.height=dropSheetHeight+'px';

	body.appendChild(dropSheet);

	return dropSheet;
    }

    function showDialog(page,msg,width,height){
	var dialog = page.createElement('div');
	dialog.id="details";
	dialog.style.width=width+'px';
	dialog.style.height=height+'px';
	dialog.style.position = 'absolute';
	dialog.style.backgroundColor = '#FF9B00';
	dialog.style.padding = '5px';
	dialog.style.textAlign = 'left';
	dialog.style.overflow = 'auto';
	dialog.style.color = '#000000';
	dialog.style.border = '2px solid #000000';
	dialog.style.font = '18px Arial, Helvetica, sans-serif';
	dialog.style.zIndex = 30;

	dialog.innerHTML=msg;
	var viewportX=page.documentElement.clientWidth;
	var viewportY=page.documentElement.clientHeight;
	dialog.style.top=(viewportY/2)-(height/2)+'px';
	dialog.style.left=(viewportX/2)-(width/2)+'px';

	var body = page.getElementsByTagName('body')[0];
	body.appendChild(dialog);

	return dialog;
    }



    function removeExtras(list){
	for (var i in list) {
	    list[i].parentNode.removeChild(list[i]);
	}
    }



    function maybeAddTrustTab(page) {
	if (!isEnabledWiki(page.location)) return null;

	var mainTab = page.getElementById('ca-nstab-main');
	if (!mainTab) return null;		// must not be a main article!
	if (mainTab.getAttribute("class") != "selected") return null;

	var articleURL = getTrustTabURL(page.location);
	
	var trust_li = page.getElementById('ca-trust');
	if (trust_li) {
	    log("trust tab already on page.");
	    return null;	// already done, eh?
	}

	// And modify page to display "check trust" tab
	trust_li = page.createElement('li');
	trust_li.setAttribute("id", "ca-trust");
	trust_li.innerHTML = '<a href="'
	    + articleURL + '" title="Trust colored version of this page">'
	    + 'trust info</a>';

	var ul = mainTab.parentNode;
	ul.appendChild(trust_li);

	var cite_li = page.getElementById('t-cite');
	if (!cite_li) return null;	

	var revID = getQueryVariable(page.location.search, 'oldid');
	if (revID == '') revID = getQueryVariable(page.location.search, 'diff');
	var vote_a = page.createElement('a');
	vote_a.href = '#voted';
	vote_a.innerHTML ='Vote for this page';
	var clickHandler = function (e) {
		vote_a.innerHTML = 'Voting...';
		wgUserName = window.content.wrappedJSObject.wgUserName;
		if (wgUserName == null) wgUserName = '';
		var wgArticleId = window.content.wrappedJSObject.wgArticleId;
		var wgPageName = window.content.wrappedJSObject.wgPageName;
		var wgCurRevisionId = window.content.wrappedJSObject.wgCurRevisionId;
		if (revID == '') revID = wgCurRevisionId;
		var url = 'http://redherring.cse.ucsc.edu/firefox/frontend/index.php?action=ajax&rs=TextTrustImpl::handleVote&rsargs[]='+escape(wgUserName)+'&rsargs[]=' + wgArticleId + '&rsargs[]=' + revID + '&rsargs[]=' + escape(wgPageName);
		log("voting url: " + url);
		http_get(url,
		    function (req) {
			vote_a.innerHTML = 'Thanks for voting!'
			log("Voting request text: " + req.responseText);
			vote_a.click = null;
		    },
		    function (req) {
			vote_a.innerHTML = 'Voting error.';
			log("Voting request status: " + req.status);
			log("Voting request text: " + req.responseText);
			vote_a.click = null;
		    });
		return false;
	    };
	vote_a.addEventListener("click", clickHandler, false);
	var vote_li = page.createElement('li');
	vote_li.setAttribute('id', 't-vote');
	vote_li.appendChild(vote_a);

	ul = cite_li.parentNode;
	ul.appendChild(vote_li);

	return trust_li;
    }

    function maybeColorPage(page, tab) {
	if (!tab) return;
	addTrustHeaders(page);
	if (!/[?&]trust$/.test(page.location.search)) return;
	var wtURL = getWikiTrustURL(page.location);
	if (!wtURL) return;
	tab.setAttribute('class', 'selected');
	var addedNodes = new Array();
	addedNodes.push(darkenPage(page));
	addedNodes.push(showDialog(page,
		"<p>Downloading trust information...</p>", 300,100));
	log("Requesting trust url = " + wtURL);
	http_get(wtURL,
	    function (req) {
		log("trust page downloaded successfully.");
		removeExtras(addedNodes);
		var trustDiv = page.createElement('div');
		trustDiv.setAttribute('id', 'trust-div');
		var bodyContent = page.getElementById('bodyContent');
		
		if (req.responseXML != null) {
		    bodyContent.innerHTML = '';
		    bodyContent.appendChild(getWarningBox(page));
		    bodyContent.appendChild(trustDiv);
		    var trustContent = req.responseXML.getElementsByTagName('trustdata')[0].firstChild.nodeValue;
		    trustDiv.innerHTML = trustContent;
		} else if (req.responseText != null) {
		    if (getPrefBool('newapi', false)) {
			var siteSub = page.getElementById('siteSub');
			var contentSub = page.getElementById('contentSub');
			var catlinks = page.getElementById('catlinks');
			bodyContent.innerHTML = '';
			bodyContent.appendChild(siteSub);
			bodyContent.appendChild(getWarningBox(page));
			bodyContent.appendChild(contentSub);
			bodyContent.appendChild(trustDiv);
			if (catlinks) bodyContent.appendChild(catlinks);
			trustDiv.innerHTML = req.responseText;
			fixHrefs(bodyContent);
		    } else {
			bodyContent.innerHTML = '';
			var marker = 'id="bodyContent">';
			var startPos = req.responseText.indexOf(marker);
			if (startPos < 0) {
			    log("Could not find ["+marker+"] in response.");
			    return;
			}
			startPos += marker.length;
			var endMarker = '<div id="column-one">';
			var endPos = req.responseText.indexOf(endMarker);
			if (endPos < 0) {
			    log("Could not find ["+endMarker+"] in response.");
			    return;
			}
			bodyContent.innerHTML  = req.responseText.substring(startPos, endPos);
			fixHrefs(bodyContent);
			bodyContent.insertBefore(getWarningBox(page), bodyContent.firstChild);
		    }
		}
	    },
	    function (req) {
		log("trust page failed to download, status = " + req.status);
		removeExtras(addedNodes);
		addedNodes.push(darkenPage(page));
		addedNodes.push(showDialog(page,
		    "<p>Failed to contact trust server...</p>", 300,100));
	    });
    }

    window.addEventListener("load", function(ev) {
	document.getElementById("appcontent").addEventListener(
		"DOMContentLoaded",
	    function(ev) {
		var page = ev.originalTarget;
		if (page.nodeName != "#document") return;
		if (!page.location) return;


//		try {
		    var tab = maybeAddTrustTab(page);
		    maybeColorPage(page, tab);
//		} catch (e) {
//		    log(e);
//		};
	    }, false);
    }, false);
})();
