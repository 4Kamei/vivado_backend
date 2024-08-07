proc rglob { dirpath patterns {exclude_pats {}} } {
    set rlist {}
    foreach fpath [glob -nocomplain -types f -directory ${dirpath} ${patterns}] {
        lappend rlist ${fpath}
    }
    foreach dir [glob -nocomplain -types d -directory ${dirpath} *] {
	lappend rlist {*}[rglob ${dir} ${patterns} ${exclude_pats}]
    }
    return ${rlist}
}
