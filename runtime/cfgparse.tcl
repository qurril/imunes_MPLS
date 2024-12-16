#
# Copyright 2005-2013 University of Zagreb.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# This work was supported in part by the Croatian Ministry of Science
# and Technology through the research contract #IP-2003-143.
#

# $Id: cfgparse.tcl 127 2014-12-18 15:10:09Z denis $


#****h* imunes/cfgparse.tcl
# NAME
#  cfgparse.tcl -- file used for parsing the configuration
# FUNCTION
#  This module is used for parsing the configuration, i.e. reading the
#  configuration from a file or a string and writing the configuration
#  to a file or a string. This module also contains a function for returning
#  a new ID for nodes, links and canvases.
#****

#****f* nodecfg.tcl/dumpputs
# NAME
#   dumpputs -- puts a string to a file or a string configuration
# SYNOPSIS
#   dumpputs $method $destination $string
# FUNCTION
#   Puts a sting to the file or appends the string configuration (used for
#   undo functions), the choice depends on the value of method parameter.
# INPUTS
#   * method -- method used. Possiable values are file (if saving the string
#     to the file) and string (if appending the string configuration)
#   * dest -- destination used. File_id for files, and string name for string
#     configuration
#   * string -- the string that is inserted to a file or appended to the string
#     configuartion
#****
proc dumpputs { method dest string } {
    switch -exact -- $method {
	file {
	    puts $dest $string
	}
	string {
	    global $dest
	    append $dest "$string
"
	}
    }
}

#****f* nodecfg.tcl/dumpCfg
# NAME
#   dumpCfg -- puts the current configuraton to a file or a string
# SYNOPSIS
#   dumpCfg $method $destination
# FUNCTION
#   Writes the working (current) configuration to a file or a string.
# INPUTS
#   * method -- used method. Possiable values are file (saving current config
#     to the file) and string (saving current config in a string)
#   * dest -- destination used. File_id for files, and string name for string
#     configurations
#****
proc dumpCfg { method dest } {
    # the globals bellow should be placed in a namespace as well
    global show_interface_names show_node_labels show_link_labels
    global show_interface_ipv4 show_interface_ipv6
    global show_background_image show_grid show_annotations
    global icon_size
    global auto_etc_hosts

    foreach node_id [getFromRunning "node_list"] {
	upvar 0 ::cf::[set ::curcfg]::$node_id lnode
	dumpputs $method $dest "node $node_id \{"
	foreach element $lnode {
	    if { "[lindex $element 0]" == "network-config" } {
		dumpputs $method $dest "    network-config \{"
		foreach line [lindex $element 1] {
		    dumpputs $method $dest "	$line"
		}
		dumpputs $method $dest "    \}"
	    } elseif { "[lindex $element 0]" == "ipsec-config" } {
		dumpputs $method $dest "    ipsec-config \{"
		foreach line [lindex $element 1] {
		    set header [lindex $line 0]
		    if { $header in "ca_cert local_cert local_key_file ipsec-logging" } {
			dumpputs $method $dest "        $line"
		    } elseif { $header == "configuration" } {
			dumpputs $method $dest "        configuration \{"
			foreach confline [lindex $line 1] {
			    set item [lindex $confline 0]
			    dumpputs $method $dest "            $item"
			    foreach element [lindex $confline 1] {
				dumpputs $method $dest "                $element"
			    }
			}
			dumpputs $method $dest "        \}"
		    }
		}
		dumpputs $method $dest "    \}"
	    } elseif { "[lindex $element 0]" == "custom-config" } {
		dumpputs $method $dest "    custom-config \{"
		foreach line [lindex $element 1] {
		    if { $line != {} } {
			set str [lindex $line 0]
			if { $str == "custom-config" } {
			    dumpputs $method $dest "    config \{"
			    foreach element [lindex $line 1] {
				dumpputs $method $dest "    $element"
			    }
			    dumpputs $method $dest "    \}"
			} else {
			    dumpputs $method $dest "	$line"
			}
		    }
		}
		dumpputs $method $dest "    \}"
	    } elseif { "[lindex $element 0]" == "custom-configs" } {
		dumpputs $method $dest "    custom-configs \{"
		foreach line [lindex $element 1] {
		    for { set x 0 } { $x<[llength $line] } { incr x 3 } {
			if { $x != {} } {
			    dumpputs $method $dest "        [lindex $line $x] [lindex $line $x+1] \{"
			    dumpputs $method $dest "            [lrange [lindex $line $x+2] 0 1]"
			    dumpputs $method $dest "            [lindex [lindex $line $x+2] 2] \{"
			    foreach l [lindex [lindex $line $x+2] 3] {
				dumpputs $method $dest "                $l"
			    }
			    dumpputs $method $dest "            \}"
			    dumpputs $method $dest "        \}"
			}
		    }
		}
		dumpputs $method $dest "    \}"
	    } elseif { "[lindex $element 0]" == "events" } {
		dumpputs $method $dest "    events \{"
		foreach line [lindex $element 1] {
		    if { $line != {} } {
			dumpputs $method $dest "	$line"
		    }
		}
		dumpputs $method $dest "    \}"
	    } elseif { "[lindex $element 0]" in "default_routes4 default_routes6" } {
		# do nothing
	    } else {
		dumpputs $method $dest "    $element"
	    }
	}
	dumpputs $method $dest "\}"
	dumpputs $method $dest ""
    }

    foreach obj "link annotation canvas" {
	foreach elem [getFromRunning "${obj}_list"] {
	    upvar 0 ::cf::[set ::curcfg]::$elem lelem
	    dumpputs $method $dest "$obj $elem \{"
	    foreach element $lelem {
		if { "[lindex $element 0]" == "events" } {
		    dumpputs $method $dest "    events \{"
		    foreach line [lindex $element 1] {
			if { $line != {} } {
			    dumpputs $method $dest "	$line"
			}
		    }
		    dumpputs $method $dest "    \}"
		} else {
		    dumpputs $method $dest "    $element"
		}
	    }
	    dumpputs $method $dest "\}"
	    dumpputs $method $dest ""
	}
    }

    dumpputs $method $dest "option show \{"

    # XXX - this needs to be refactored.
    if { $show_interface_names == 0 } {
	dumpputs $method $dest "    interface_names no"
    } else {
	dumpputs $method $dest "    interface_names yes" }
    if { $show_interface_ipv4 == 0 } {
	dumpputs $method $dest "    ip_addresses no"
    } else {
	dumpputs $method $dest "    ip_addresses yes" }
    if { $show_interface_ipv6 == 0 } {
	dumpputs $method $dest "    ipv6_addresses no"
    } else {
	dumpputs $method $dest "    ipv6_addresses yes" }
    if { $show_node_labels == 0 } {
	dumpputs $method $dest "    node_labels no"
    } else {
	dumpputs $method $dest "    node_labels yes" }
    if { $show_link_labels == 0 } {
	dumpputs $method $dest "    link_labels no"
    } else {
	dumpputs $method $dest "    link_labels yes" }
    if { $show_background_image == 0 } {
	dumpputs $method $dest "    background_images no"
    } else {
	dumpputs $method $dest "    background_images yes" }
    if { $show_annotations == 0 } {
	dumpputs $method $dest "    annotations no"
    } else {
	dumpputs $method $dest "    annotations yes" }
    if { $auto_etc_hosts == 0 } {
	dumpputs $method $dest "    hostsAutoAssign no"
    } else {
	dumpputs $method $dest "    hostsAutoAssign yes" }
    if { $show_grid == 0 } {
	dumpputs $method $dest "    grid no"
    } else {
	dumpputs $method $dest "    grid yes" }
    dumpputs $method $dest "    iconSize $icon_size"
    dumpputs $method $dest "    zoom [getFromRunning "zoom"]"
    dumpputs $method $dest "\}"
    dumpputs $method $dest ""

    foreach elem [getFromRunning "image_list"] {
	if { [getImageReferences $elem] != "" } {
	    upvar 0 ::cf::[set ::curcfg]::$elem lelem
	    dumpputs $method $dest "image $elem \{"
	    foreach element $lelem {
		if { [string match "*zoom_*" $element] != 1 } {
		    dumpputs $method $dest "    $element"
		}
	    }
	    dumpputs $method $dest "\}"
	    dumpputs $method $dest ""
	}
    }
}

#****f* nodecfg.tcl/loadCfgLegacy
# NAME
#   loadCfgLegacy -- loads the current configuration.
# SYNOPSIS
#   loadCfgLegacy $cfg
# FUNCTION
#   Loads the configuration written in the cfg string to a current
#   configuration.
# INPUTS
#   * cfg -- string containing the new working configuration.
#****
proc loadCfgLegacy { cfg } {
    global show_interface_names show_node_labels show_link_labels
    global show_interface_ipv4 show_interface_ipv6
    global show_background_image show_grid show_annotations
    global icon_size
    global auto_etc_hosts
    global execMode all_modules_list

    # Cleanup first
    set node_list {}
    set link_list {}
    set annotation_list {}
    set canvas_list {}
    set image_list {}
    set class ""
    set object ""
    foreach entry $cfg {
	if { "$class" == "" } {
	    set class $entry
	    continue
	} elseif { "$object" == "" } {
	    set object $entry
	    if { $object == "annotation_list" } {
		continue
	    }

	    upvar 0 ::cf::[set ::curcfg]::$object $object
	    set $object {}
	    if { "$class" == "node" } {
		lappend node_list $object
	    } elseif { "$class" == "link" } {
		lappend link_list $object
	    } elseif { "$class" == "link" } {
		lappend link_list $object
	    } elseif { "$class" == "canvas" } {
		lappend canvas_list $object
	    } elseif { "$class" == "option" } {
		# do nothing
	    } elseif { "$class" == "annotation" } {
		lappend annotation_list $object
	    } elseif { "$class" == "image" } {
		lappend image_list $object
	    } else {
		puts "configuration parsing error: unknown object class $class"
		exit 1
	    }
	    continue
	} else {
	    set line [concat $entry]
	    while { [llength $line] >= 2 } {
		set field [lindex $line 0]
		if { "$field" == "" } {
		    set line [lreplace $line 0 0]
		    continue
		}

		set value [lindex $line 1]
		set line [lreplace $line 0 1]

		if { "$class" == "node" } {
		    switch -exact -- $field {
			type {
			    lappend $object "type $value"
			}
			mirror {
			    lappend $object "mirror $value"
			}
			model {
			    lappend $object "model $value"
			}
			snapshot {
			    lappend $object "snapshot $value"
			}
			cpu {
			    lappend $object "cpu {$value}"
			}
			interface-peer {
			    lappend $object "interface-peer {$value}"
			}
			external-ifcs {
			    lappend $object "external-ifcs {$value}"
			}
			network-config {
			    set cfg ""
			    foreach zline [split $value {
}] {
				if { [string index "$zline" 0] == "	" } {
				    set zline [string replace "$zline" 0 0]
				}
				lappend cfg $zline
			    }
			    set cfg [lrange $cfg 1 [expr {[llength $cfg] - 2}]]
			    lappend $object "network-config {$cfg}"
			}
			ipsec-config {
			    set cfg ""
			    set conf_indicator 0
			    set cset_indicator 0
			    set conn_indicator 0
			    set conf_list ""
			    set conn_list ""
			    set cset_list ""
			    set conn_name ""
			    foreach zline [split $value {
}] {
				set zline [string trimleft "$zline"]
				if { [string first "ca_cert" $zline] != -1 || [string first "local_cert" $zline] != -1 || [string first "local_key_file" $zline] != -1 } {
				    lappend cfg $zline
				} elseif { [string first "ipsec-logging" $zline] != -1 } {
				    lappend cfg "$zline"
				} elseif { [string first "configuration" $zline] != -1 } {
				    set conf_indicator 1
				} elseif { [string first "\}" $zline] != -1 } {
				    set conf_indicator 0
				    set cset_indicator 0
				    if { $conn_indicator } {
					lappend conf_list "{$conn_name} {$conn_list}"
				    }
				    lappend cfg "configuration {$conf_list}"
				} elseif { $conf_indicator } {
				    if { [string first "config setup" $zline] != -1 } {
					set conn_indicator 0
					set cset_indicator 1
				    } elseif { $cset_indicator } {
					if { [string first "conn" $zline] != -1 } {
					    set cset_indicator 0
					    lappend conf_list "{config setup} {$cset_list}"
					} else {
					    lappend cset_list $zline
					}
				    }

				    if { [string first "conn" $zline] != -1 } {
					if { $conn_indicator } {
					    lappend conf_list "{$conn_name} {$conn_list}"
					} else {
					    set conn_indicator 1
					}
					set conn_name "$zline"
					set conn_list ""
				    } elseif { $conn_indicator } {
					lappend conn_list $zline
				    }
				}
			    }
			    lappend $object "ipsec-config {$cfg}"
			}
			custom-enabled {
			    lappend $object "custom-enabled $value"
			}
			custom-selected {
			    lappend $object "custom-selected $value"
			}
			custom-command {
			    lappend $object "custom-command {$value}"
			}
			custom-config {
			    set cfg ""

			    foreach zline [split $value {
}] {
				if { [string index "$zline" 0] == "	" } {
				    set zline [string replace "$zline" 0 0]
				}
				lappend cfg $zline
			    }
			    set cfg [lrange $cfg 1 [expr {[llength $cfg] - 2}]]
			    lappend $object "custom-config {$cfg}"
			}
			custom-configs {
			    set cfgs ""
			    for { set x 0 } { $x<[llength $value] } { incr x 3 } {
				set cfg ""
				set config [lindex [lindex $value $x+2] 3]
				set empty 0
				set config_split [split $config {
}]
				set config_split [lrange $config_split 1 end-1]
				set line1 [lindex $config_split 0]
				set empty [expr {[string length $line1]-\
				    [string length [string trimleft $line1]]}]
				set empty_str [string repeat " " $empty]
				foreach zline $config_split {
				    while { [string range $zline 0 $empty-1] != "$empty_str" } {
					set zline [regsub {\t} $zline "        "]
				    }
				    set zline [string range $zline $empty end]
				    lappend cfg $zline
				}
				set cfg_pconf [lreplace [lindex $value $x+2] 3 3 $cfg]
				set cfg [lreplace [lrange $value $x $x+2] 2 2 $cfg_pconf]
				lappend cfgs $cfg
			    }
			    lappend $object "custom-configs {$cfgs}"
			}
			iconcoords {
			    lappend $object "iconcoords {$value}"
			}
			labelcoords {
			    lappend $object "labelcoords {$value}"
			}
			auto_default_routes {
			    lappend $object "auto_default_routes $value"
			}
			canvas {
			    lappend $object "canvas $value"
			}
			services {
			    lappend $object "services {$value}"
			}
			docker-attach {
			    lappend $object "docker-attach $value"
			}
			# for backwards compatibility
			docker-image {
			    lappend $object "custom-image $value"
			}
			custom-image {
			    lappend $object "custom-image $value"
			}
			events {
			    set cfg ""
			    foreach zline [split $value {
}] {
				if { [string index "$zline" 0] == "	" } {
				    set zline [string replace "$zline" 0 0]
				}
				set zline [string trim $zline]
				lappend cfg $zline
			    }
			    set cfg [lrange $cfg 1 [expr {[llength $cfg] - 2}]]
			    lappend $object "events {$cfg}"
			}
			customIcon {
			    lappend $object "customIcon $value"
			}
		    }
		} elseif { "$class" == "link" } {
		    switch -exact -- $field {
			direct {
			    lappend $object "direct $value"
			}
			nodes {
			    lappend $object "nodes {$value}"
			}
			ifaces {
			    lappend $object "ifaces {$value}"
			}
			mirror {
			    lappend $object "mirror $value"
			}
			bandwidth {
			    lappend $object "bandwidth $value"
			}
			delay {
			    lappend $object "delay $value"
			}
			jitter-upstream {
			    lappend $object "jitter-upstream {$value}"
			}
			jitter-upstream-mode {
			    lappend $object "jitter-upstream-mode $value"
			}
			jitter-upstream-hold {
			    lappend $object "jitter-upstream-hold $value"
			}
			jitter-downstream {
			    lappend $object "jitter-downstream {$value}"
			}
			jitter-downstream-mode {
			    lappend $object "jitter-downstream-mode $value"
			}
			jitter-downstream-hold {
			    lappend $object "jitter-downstream-hold $value"
			}
			ber {
			    lappend $object "ber $value"
			}
			loss {
			    lappend $object "loss $value"
			}
			duplicate {
			    lappend $object "duplicate $value"
			}
			color {
			    lappend $object "color $value"
			}
			width {
			    lappend $object "width $value"
			}
			events {
			    set cfg ""
			    foreach zline [split $value {
}] {
				if { [string index "$zline" 0] == "	" } {
				    set zline [string replace "$zline" 0 0]
				}
				set zline [string trim $zline]
				lappend cfg $zline
			    }
			    set cfg [lrange $cfg 1 [expr {[llength $cfg] - 2}]]
			    lappend $object "events {$cfg}"
			}
		    }
		} elseif { "$class" == "canvas" } {
		    switch -exact -- $field {
			name {
			    lappend $object "name {$value}"
			}
			size {
			    lappend $object "size {$value}"
			}
			bkgImage {
			    lappend $object "bkgImage {$value}"
			}
		    }
		} elseif { "$class" == "option" } {
		    switch -exact -- $field {
			interface_names {
			    if { $value == "no" } {
				set show_interface_names 0
			    } elseif { $value == "yes" } {
				set show_interface_names 1
			    }
			}
			ip_addresses {
			    if { $value == "no" } {
				set show_interface_ipv4 0
			    } elseif { $value == "yes" } {
				set show_interface_ipv4 1
			    }
			}
			ipv6_addresses {
			    if { $value == "no" } {
				set show_interface_ipv6 0
			    } elseif { $value == "yes" } {
				set show_interface_ipv6 1
			    }
			}
			node_labels {
			    if { $value == "no" } {
				set show_node_labels 0
			    } elseif { $value == "yes" } {
				set show_node_labels 1
			    }
			}
			link_labels {
			    if { $value == "no" } {
				set show_link_labels 0
			    } elseif { $value == "yes" } {
				set show_link_labels 1
			    }
			}
			background_images {
			    if { $value == "no" } {
				set show_background_image 0
			    } elseif { $value == "yes" } {
				set show_background_image 1
			    }
			}
			annotations {
			    if { $value == "no" } {
				set show_annotations 0
			    } elseif { $value == "yes" } {
				set show_annotations 1
			    }
			}
			grid {
			    if { $value == "no" } {
				set show_grid 0
			    } elseif { $value == "yes" } {
				set show_grid 1
			    }
			}
			hostsAutoAssign {
			    if { $value == "no" } {
				set auto_etc_hosts 0
			    } elseif { $value == "yes" } {
				set auto_etc_hosts 1
			    }
			}
			zoom {
			    setToRunning "zoom" $value
			}
			iconSize {
			    set icon_size $value
			}
		    }
		} elseif { "$class" == "annotation" } {
		    switch -exact -- $field {
			type {
			    lappend $object "type $value"
			}
			iconcoords {
			    lappend $object "iconcoords {$value}"
			}
			color {
			    lappend $object "color $value"
			}
			label {
			    lappend $object "label {$value}"
			}
			labelcolor {
			    lappend $object "labelcolor $value"
			}
			size {
			    lappend $object "size $value"
			}
			canvas {
			    lappend $object "canvas $value"
			}
			font {
			    lappend $object "font {$value}"
			}
			fontfamily {
			    lappend $object "fontfamily {$value}"
			}
			fontsize {
			    lappend $object "fontsize {$value}"
			}
			effects {
			    lappend $object "effects {$value}"
			}
			width {
			    lappend $object "width $value"
			}
			bordercolor {
			    lappend $object "bordercolor $value"
			}
		    }
		} elseif { "$class" == "image" } {
		    upvar 0 ::cf::[set ::curcfg]::$object $object
		    switch -glob -- $field {
			referencedBy {
			    lappend $object "referencedBy {$value}"
			}
			file {
			    lappend $object "file {$value}"
			}
			type {
			    lappend $object "type {$value}"
			}
			data {
			    lappend $object "data {$value}"
			}
		    }
		}
	    }
	}
	set class ""
	set object ""
    }

    setToRunning "node_list" $node_list
    setToRunning "link_list" $link_list
    setToRunning "canvas_list" $canvas_list
    setToRunning "annotation_list" $annotation_list
    setToRunning "image_list" $image_list
    setToRunning "cfg_deployed" false

    #
    # Hack for comaptibility with old format files (no canvases)
    #
    if { $canvas_list == "" } {
	set curcanvas [newCanvas ""]
	foreach node_id $node_list {
	    setNodeCanvas $node_id $curcanvas
	}
    }
    #
    # Hack for comaptibility with old format files (no lo0 on nodes)
    #
    set ipv6_used_list {}
    set ipv4_used_list {}
    set mac_used_list {}
    foreach node_id $node_list {
	set node_type [getNodeType $node_id]
	if { $node_type in "extelem" } {
	    continue
	}

	if { $node_type ni [concat $all_modules_list "pseudo"] && \
	    ! [string match "router.*" $node_type] } {
	    set msg "Unknown node type: '$node_type'."
	    if { $execMode == "batch" } {
		statline $msg
	    } else {
		tk_dialog .dialog1 "IMUNES warning" \
		    "Error: $msg" \
		info 0 Dismiss
	    }
	    exit
	}

	if { "lo0" ni [logIfcList $node_id] && \
	    [$node_type.netlayer] == "NETWORK"} {

	    setLogIfcType $node_id lo0 lo
	    setIfcIPv4addrs $node_id lo0 "127.0.0.1/8"
	    setIfcIPv6addrs $node_id lo0 "::1/128"
	}

	# Speeding up auto renumbering of MAC, IPv4 and IPv6 addresses by remembering
	# used addresses in lists.
	foreach iface_id [ifcList $node_id] {
	    foreach addr [getIfcIPv6addrs $node_id $iface_id] {
		lassign [split $addr "/"] addr mask
		lappend ipv6_used_list "[ip::contract [ip::prefix $addr]]/$mask"
	    }

	    foreach addr [getIfcIPv4addrs $node_id $iface_id] {
		lappend ipv4_used_list $addr
	    }

	    set addr [getIfcMACaddr $node_id $iface_id]
	    if { $addr != "" } { lappend mac_used_list $addr }
	}
    }

    setToRunning "ipv4_used_list" $ipv4_used_list
    setToRunning "ipv6_used_list" $ipv6_used_list
    setToRunning "mac_used_list" $mac_used_list

    # older .imn files have only one link per node pair, so match links with interfaces
    foreach link_id $link_list {
	if { [getLinkPeersIfaces $link_id] != {} } {
	    # if one link has ifaces, then all of them do too
	    return
	}

	upvar 0 ::cf::[set ::curcfg]::$link_id $link_id

	lassign [getLinkPeers $link_id] node1_id node2_id
	set iface1_id [ifcByPeer $node1_id $node2_id]
	set iface2_id [ifcByPeer $node2_id $node1_id]

	lappend $link_id "ifaces {$iface1_id $iface2_id}"
    }
}

#****f* nodecfg.tcl/newObjectId
# NAME
#   newObjectId -- new object Id
# SYNOPSIS
#   set obj_id [newObjectId $elem_list $prefix]
# FUNCTION
#   Returns the ID for a new object of with the defined $prefix. The ID is in
#   the form $prefix$number. $number is the first available number from the
#   given list (all the elements of the list share the same prefix and the list
#   does not need to be sorted beforehand).
# INPUTS
#   * elem_list -- the list of existing elements
#   * prefix -- the prefix of the new object.
# RESULT
#   * obj_id -- object ID in the form $prefix$number
#****
proc newObjectId { elem_list prefix } {
    set sorted_list [lsort -dictionary [lsearch -regexp -all -inline $elem_list "^$prefix\[0-9\]\[0-9\]*$"]]
    set len [llength $sorted_list]
    if { $len == 0 } {
	return ${prefix}0
    }

    # Initial interval - the start to the middle of the list
    set start 0
    set end [expr $len - 1]
    set mid [expr $len / 2]
    set lastmid -1

    if { "$prefix$end" == [lindex $sorted_list end] } {
	return $prefix[expr $end + 1]
    }

    while { $mid != $lastmid } {
	set val [lindex $sorted_list $mid]
	set idx [lsearch -dictionary -bisect $sorted_list $val]
	regsub $prefix $val "" val

	if { [expr $mid < $val] } {
	    set end $mid
	} else {
	    set start [expr $mid + 1]
	}

	set lastmid $mid
	set mid [expr ($start + $end ) / 2]
    }

    return $prefix$mid
}

#########################################################################

proc getWithDefault { default_value dictionary args } {
    try {
	return [dict get $dictionary {*}$args]
    } on error {} {
	return $default_value
    }
}

proc dictGet { dictionary args } {
    try {
	dict get $dictionary {*}$args
    } on error {} {
	return {}
    } on ok retv {
	return $retv
    }
}

proc dictSet { dictionary args } {
    try {
	dict set dictionary {*}$args
    } on error {} {
	return $dictionary
    } on ok retv {
	return $retv
    }
}

proc dictLappend { dictionary args } {
    try {
	dict lappend dictionary {*}$args
    } on error {} {
	return $dictionary
    } on ok retv {
	return $retv
    }
}

proc dictUnset { dictionary args } {
    try {
	dict unset dictionary {*}$args
    } on error {} {
	return $dictionary
    } on ok retv {
	return $retv
    }
}

proc clipboardGet { args } {
    upvar 0 ::cf::clipboard::dict_cfg dict_cfg

    return [dictGet $dict_cfg {*}$args]
}

proc clipboardSet { args } {
    upvar 0 ::cf::clipboard::dict_cfg dict_cfg

    if { [lindex $args end] in {{} ""} } {
	for {set i 1} {$i < [llength $args]} {incr i} {
	    set dict_cfg [dictUnset $dict_cfg {*}[lrange $args 0 end-$i]]

	    set new_upper [dictGet $dict_cfg {*}[lrange $args 0 end-[expr $i+1]]]
	    if { $new_upper != "" } {
		break
	    }
	}
    } elseif { [dict exists $dict_cfg {*}$args] } {
	set dict_cfg [dictUnset $dict_cfg {*}$args]
    } else {
	set dict_cfg [dictSet $dict_cfg {*}$args]
    }

    return $dict_cfg
}

proc clipboardLappend { args } {
    upvar 0 ::cf::clipboard::dict_cfg dict_cfg

    set dict_cfg [dictLappend $dict_cfg {*}$args]

    return $dict_cfg
}

proc clipboardUnset { args } {
    upvar 0 ::cf::clipboard::dict_cfg dict_cfg

    for {set i 0} {$i < [llength $args]} {incr i} {
	set dict_cfg [dictUnset $dict_cfg {*}[lrange $args 0 end-$i]]

	set new_upper [dictGet $dict_cfg {*}[lrange $args 0 end-[expr $i+1]]]
	if { $new_upper != "" } {
	    break
	}
    }

    return $dict_cfg
}

#########################################################################

proc getFromRunning { key { config "" } } {
    if { $config == "" } {
	set config [set ::curcfg]
    }
    upvar 0 ::cf::${config}::dict_run dict_run

    return [dictGet $dict_run $key]
}

proc setToRunning { key value } {
    upvar 0 ::cf::[set ::curcfg]::dict_run dict_run

    set dict_run [dictSet $dict_run $key $value]

    return $dict_run
}

proc unsetRunning { key } {
    upvar 0 ::cf::[set ::curcfg]::dict_run dict_run

    set dict_run [dictUnset $dict_run $key]

    return $dict_run
}

proc lappendToRunning { key value } {
    upvar 0 ::cf::[set ::curcfg]::dict_run dict_run

    set dict_run [dictLappend $dict_run $key $value]

    return $dict_run
}

proc jumpToUndoLevel { undolevel } {
    upvar 0 ::cf::[set ::curcfg]::undolog undolog

    loadCfgLegacy $undolog($undolevel)
}

proc saveToUndoLevel { undolevel { value "" } } {
    upvar 0 ::cf::[set ::curcfg]::undolog undolog

    set undolog($undolevel) $value
}
