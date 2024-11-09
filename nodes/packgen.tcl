#
# Copyright 2005-2010 University of Zagreb, Croatia.
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
# This work was supported in part by Croatian Ministry of Science
# and Technology through the research contract #IP-2003-143.
#

#****h* imunes/packgen.tcl
# NAME
#  packgen.tcl -- defines packgen.specific procedures
# FUNCTION
#  This module is used to define all the packgen.specific procedures.
# NOTES
#  Procedures in this module start with the keyword packgen and
#  end with function specific part that is the same for all the node
#  types that work on the same layer.
#****

set MODULE packgen
registerModule $MODULE

################################################################################
########################### CONFIGURATION PROCEDURES ###########################
################################################################################

#****f* packgen.tcl/packgen.confNewNode
# NAME
#   packgen.confNewNode -- configure new node
# SYNOPSIS
#   packgen.confNewNode $node
# FUNCTION
#   Configures new node with the specified id.
# INPUTS
#   * node -- node id
#****
proc $MODULE.confNewNode { node } {
    upvar 0 ::cf::[set ::curcfg]::$node $node
    global nodeNamingBase

    set nconfig [list \
	"hostname [getNewNodeNameType packgen $nodeNamingBase(packgen)]" \
	! ]
    lappend $node "network-config [list $nconfig]"
}

#****f* packgen.tcl/packgen.ifacePrefix
# NAME
#   packgen.ifacePrefix -- interface name prefix
# SYNOPSIS
#   packgen.ifacePrefix
# FUNCTION
#   Returns packgen interface name prefix.
# RESULT
#   * name -- name prefix string
#****
proc $MODULE.ifacePrefix { l r } {
    return e
}

#****f* packgen.tcl/packgen.netlayer
# NAME
#   packgen.netlayer
# SYNOPSIS
#   set layer [packgen.netlayer]
# FUNCTION
#   Returns the layer on which the packgen.communicates
#   i.e. returns LINK.
# RESULT
#   * layer -- set to LINK
#****
proc $MODULE.netlayer {} {
    return LINK
}

#****f* packgen.tcl/packgen.virtlayer
# NAME
#   packgen.virtlayer
# SYNOPSIS
#   set layer [packgen.virtlayer]
# FUNCTION
#   Returns the layer on which the packgen is instantiated
#   i.e. returns NATIVE.
# RESULT
#   * layer -- set to NATIVE
#****
proc $MODULE.virtlayer {} {
    return NATIVE
}

#****f* packgen.tcl/packgen.nghook
# NAME
#   packgen.nghook
# SYNOPSIS
#   packgen.nghook $eid $node $iface
# FUNCTION
#   Returns the id of the netgraph node and the name of the
#   netgraph hook which is used for connecting two netgraph
#   nodes.
# INPUTS
#   * eid - experiment id
#   * node - node id
#   * iface - interface name
# RESULT
#   * nghook - the list containing netgraph node id and the
#     netgraph hook (ngNode ngHook).
#****
proc $MODULE.nghook { eid node iface } {
    return [list $node output]
}

#****f* packgen.tcl/packgen.maxLinks
# NAME
#   packgen.maxLinks -- maximum number of links
# SYNOPSIS
#   packgen.maxLinks
# FUNCTION
#   Returns packgen maximum number of links.
# RESULT
#   * maximum number of links.
#****
proc $MODULE.maxLinks {} {
    return 1
}

################################################################################
############################ INSTANTIATE PROCEDURES ############################
################################################################################

proc $MODULE.prepareSystem {} {
    catch { exec kldload ng_source }
}

#****f* packgen.tcl/packgen.nodeCreate
# NAME
#   packgen.nodeCreate
# SYNOPSIS
#   packgen.nodeCreate $eid $node
# FUNCTION
#   Procedure instantiate creates a new virtaul node
#   for a given node in imunes.
#   Procedure packgen.nodeCreate creates a new virtual node
#   with all the interfaces and CPU parameters as defined
#   in imunes.
# INPUTS
#   * eid - experiment id
#   * node - id of the node
#****
proc $MODULE.nodeCreate { eid node } {
    pipesExec "printf \"
    mkpeer . source inhook input \n
    msg .inhook setpersistent \n name .:inhook $node
    \" | jexec $eid ngctl -f -" "hold"
}

#****f* packgen.tcl/packgen.nodeConfigure
# NAME
#   packgen.nodeConfigure
# SYNOPSIS
#   packgen.nodeConfigure $eid $node
# FUNCTION
#   Starts a new packgen. The node can be started if it is instantiated.
# INPUTS
#   * eid - experiment id
#   * node - id of the node
#****
proc $MODULE.nodeConfigure { eid node } {
    foreach packet [packgenPackets $node] {
	set fd [open "| jexec $eid nghook $node: input" w]
	fconfigure $fd -encoding binary

	set pdata [getPackgenPacketData $node [lindex $packet 0]]
	set bin [binary format H* $pdata]
	puts -nonewline $fd $bin

	catch { close $fd }
    }

    set pps [getPackgenPacketRate $node]

    pipesExec "jexec $eid ngctl msg $node: setpps $pps" "hold"
    pipesExec "jexec $eid ngctl msg $node: start [expr 2**63]" "hold"
}

################################################################################
############################# TERMINATE PROCEDURES #############################
################################################################################

proc $MODULE.nodeIfacesDestroy { eid node ifaces } {
    l2node.nodeIfacesDestroy $eid $node $ifaces
}

#****f* packgen.tcl/packgen.nodeShutdown
# NAME
#   packgen.nodeShutdown
# SYNOPSIS
#   packgen.nodeShutdown $eid $node
# FUNCTION
#   Shutdowns a packgen. Simulates the shutdown proces of a packgen.
# INPUTS
#   * eid - experiment id
#   * node - id of the node
#****
proc $MODULE.nodeShutdown { eid node } {
    pipesExec "jexec $eid ngctl msg $node: clrdata" "hold"
    pipesExec "jexec $eid ngctl msg $node: stop" "hold"
}

#****f* packgen.tcl/packgen.nodeDestroy
# NAME
#   packgen.nodeDestroy
# SYNOPSIS
#   packgen.nodeDestroy $eid $node
# FUNCTION
#   Destroys a packgen. Destroys all the interfaces of the packgen.
# INPUTS
#   * eid - experiment id
#   * node - id of the node
#****
proc $MODULE.nodeDestroy { eid node } {
    pipesExec "jexec $eid ngctl msg $node: shutdown" "hold"
}

################################################################################
################################ GUI PROCEDURES ################################
################################################################################

proc $MODULE.icon { size } {
    global ROOTDIR LIBDIR

    switch $size {
	normal {
	    return $ROOTDIR/$LIBDIR/icons/normal/packgen.gif
	}
	small {
	    return $ROOTDIR/$LIBDIR/icons/small/packgen.gif
	}
	toolbar {
	    return $ROOTDIR/$LIBDIR/icons/tiny/packgen.gif
	}
    }
}

proc $MODULE.toolbarIconDescr {} {
    return "Add new Packet generator"
}

proc $MODULE.notebookDimensions { wi } {
    set h 430
    set w 652

    return [list $h $w]
}

#****f* packgen.tcl/packgen.configGUI
# NAME
#   packgen.configGUI
# SYNOPSIS
#   packgen.configGUI $c $node
# FUNCTION
#   Defines the structure of the packgen configuration window
#   by calling procedures for creating and organising the
#   window, as well as procedures for adding certain modules
#   to that window.
# INPUTS
#   * c - tk canvas
#   * node - node id
#****
proc $MODULE.configGUI { c node } {
    global wi
    global packgenguielements packgentreecolumns curnode

    set curnode $node
    set packgenguielements {}

    configGUI_createConfigPopupWin $c
    wm title $wi "packet generator configuration"
    configGUI_nodeName $wi $node "Node name:"

    set tabs [configGUI_addNotebookPackgen $wi $node]

    configGUI_packetRate [lindex $tabs 0] $node

    set packgentreecolumns { "Data Data" }
    foreach tab $tabs {
	configGUI_addTreePackgen $tab $node
    }

    configGUI_buttonsACPackgenNode $wi $node
}

#****f* packgen.tcl/packgen.configInterfacesGUI
# NAME
#   packgen.configInterfacesGUI
# SYNOPSIS
#   packgen.configInterfacesGUI $wi $node $iface
# FUNCTION
#   Defines which modules for changing interfaces parameters
#   are contained in the packgen.configuration window. It is done
#   by calling procedures for adding certain modules to the window.
# INPUTS
#   * wi - widget
#   * node - node id
#   * iface - interface id
#****
proc $MODULE.configPacketsGUI { wi node pac } {
    global packgenguielements

    configGUI_packetConfig $wi $node $pac
}
