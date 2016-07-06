/*

							  Stata Weaver Package
					   Developed by E. F. Haghish (2014)
			  Center for Medical Biometry and Medical Informatics
						University of Freiburg, Germany
						
						  haghish@imbi.uni-freiburg.de

		
                   The Weaver Package comes with no warranty    	
				  
	
	Description
	===========
	
	The div command is a part of Weaver package and it echos the command and 
	output in separate frames, in the dynamic document. 
	
	"div" includes two subcommands which are "code" and "result" which call 
	codes.ado and results.ado respectively
	
	The functions of the program changes based on status of Stata log:
	
	1- If Stata log is "on"
		
		- if the log type is smcl, create a temporary smcl log, translate it 
		  to text, append the text version to Weaver log, and then append the 
		  smcl version to Stata log
		  
		- if the log is in text, create a text log and then append it to both 
		  Weaver and Stata logs
		  
	2- If the Stata log is "off" or "closed" just create a text log and append 
	   it to Weaver log. 
	
	
	Weaver version 3.3.7  April, 2016
*/

program define div

version 11		//fails with newer Stata commands
	
	
	
	****************************************************************************
	* Searching for "codes" and "results" subcommands
	*
	* - if the command includes at least 2 words, check for subcommands
	* - if a subcommand is found, remove the subcommand name from the command
	* - define a local macro "jump" if no subcommand is found
	****************************************************************************
	local line = `"`macval(0)'"'						// Save the macro
	tokenize `"`line'"'
	if !missing("`2'") {
		if "`1'" == "c" | "`1'" == "co" | "`1'" == "cod" | "`1'" == "code"  {
			local 0 : subinstr local 0 "`1'" ""		
			codes `0'
		}
		else if "`1'" == "r" | "`1'" == "re" | "`1'" == "res" | "`1'" == "resu" ///
			| "`1'" == "resul" | "`1'" == "result" {
			local 0 : subinstr local 0 `"`1'"' ""		
			results `0'
		}

		else {
			local jump = 1	
			if "`1'" == "mata:" local mata 1
		}	
	} 

	****************************************************************************
	* the "div" command
	*
	* - 
	****************************************************************************
	if missing("`2'") | "`jump'" == "1" {
		
		//cap set linesize $width
		tempname canvas needle 
		tempfile smcl								//smcl log
		tempfile text								//txt log
		set more off 

		********************************************************************
		* CHECK THE CURRENT LOG
		********************************************************************
		quietly log query    
		if `"`r(filename)'"' != "" {
			local name   `"`r(filename)'"'		//save the log name
			local status `"`r(status)'"'		// status of the log
			local type   "`r(type)'"			//save the log type
		}
		
		********************************************************************
		* If log is ON 
		*
		* - save in information of the current log and then close it
		* - execute the code and save the output in a temporary log
		********************************************************************
		
		if "`name'" != "" {
			capture quietly log close
			if "`type'" == "text" cap qui log using `text', replace text
			if "`type'" == "smcl" cap qui log using `smcl', replace smcl
		}	
		else cap qui log using `text', replace text
		
		// NOTE: The `c(userversion)' is not available on Stata 12. This can be 
		//		 replaced with `c(stata_version)'
		
		*version `c(userversion)': `0'	
		version `c(stata_version)': `0
		cap quietly log close	
	
		********************************************************************
		* if log is SMCL
		*
		* - if the log is SMCL, save the smcl2txt translator details
		* - translate the smcl log to text
		* - reset the smcl2txt translator's default settings
		* - append the smcl or text temp log to the Stata log file
		********************************************************************
		if "`type'" == "smcl" { 
			qui translator query smcl2txt
			local savelinesize `r(linesize)'
			local lm `r(lmargin)'
			translator set smcl2txt linesize `c(linesize)'
			translator set smcl2txt lmargin 0
			if "`r(cmdnumber)'" == "on" {
				local savecmdnumber on
				translator set smcl2txt cmdnumber off
			}
			if "`r(logo)'" == "on" {
				local savelogo on
				translator set smcl2txt logo off
			}
			cap qui translate `smcl' `text', trans(smcl2txt) replace
			
			if "`savecmdnumber'" == "on" translator set smcl2txt cmdnumber on
			if "`savelogo'" == "on" translator set smcl2txt logo on
			if !missing("`lm'") translator set smcl2txt lmargin `lm'
			translator set smcl2txt linesize `savelinesize'
		}

		
		********************************************************************
		* Print the command to Weaver log 
		********************************************************************
		if "$weaverstyle" == "minimal" {
			cap file write `canvas' `"<pre class="sh_stata" >. "' 				///
			`"`macval(0)'"' _n 							//add dot
		}
		else {
			cap file write `canvas' `"<pre class="sh_stata" >"' 				///
			`"`macval(0)'"' _n 
		}
				
		cap file write `canvas' "</pre>" _n(3) 			// close syn highlighter
		
		********************************************************************
		* Append the temporary log to Weaver log 
		*
		* - append the content of the temporary log file to Stata log
		* - only write the results if there is at least 1 line in the log
		********************************************************************
		tempname canvas needle
		cap file open `canvas' using `"$weaverFullPath"', write text append
		cap file open `needle' using "`text'", read
		cap file read `needle' line
		
		if "$weaverMarkup" == "html" {
			if "$weaverstyle" == "minimal" {
				cap file write `canvas' `"<pre class="sh_stata" >. "' 			///
				`"`macval(0)'"' _n 
			}
			else {
				cap file write `canvas' `"<pre class="sh_stata" >"' 			///
				`"`macval(0)'"' _n 
			}
			cap file write `canvas' "</pre>" _n(3) 
		}
		
		if "$weaverMarkup" == "latex" {
			if "$weaverstyle" == "empty" | "$weaversynoff" == "synoff" {
				qui file write `canvas'  										///
				`"\begin{verbatim}. `macval(0)'\end{verbatim}"' 
			}
			else {
				qui file write `canvas'  										///
				"\begin{statax}" _n												///
				`". `macval(0)'\end{statax}"' 
			}
		}
	
	
		*if r(eof)==0 {
			if "$weaverMarkup" == "html"  cap file write `canvas' `"<pre class="output" >"'	
			if "$weaverMarkup" == "latex" cap file write `canvas' _n "\begin{verbatim}" _n
		*	local close close								//indicator
		*}
		while r(eof)==0 {
			cap file write `canvas' `"`macval(line)'"' _n      
			cap file read `needle' line
		}
		
		*if !missing("`close'") {
			if "$weaverMarkup" == "html" cap file write `canvas' "</pre>" _n(2)
			if "$weaverMarkup" == "latex" cap file write `canvas' "\end{verbatim}" _n(2)
		*}
		
		
		********************************************************************
		* Reopen Stata log, if it was open
		********************************************************************
		if !missing("`name'") {
			quietly log using "`name'", append `type'
			if "`status'" != "on" quietly log `status'
		}
		

		
		
		// Make sure the weaver html log is open
		if "$weaver" == "" {
			di as txt _n(2) "{hline}"
			di as error "{bf:Warning}" 
			di as txt "{help weaver}'s html log file is off!" 
			di as txt "{hline}{smcl}"	_n
		}   
	}
		
end

