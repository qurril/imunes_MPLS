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
# This work was supported in part by Croatian Ministry of Science
# and Technology through the research contract #IP-2003-143.
#




#****h* imunes/mplsrouter.tcl
# NAME
#  mplsrouter.tcl -- defines specific procedures for mplsrouter
#  using frr/quagga/static routing model
# FUNCTION
#  This module defines all the specific procedures for a mplsrouter
#  which uses any routing model.
# NOTES
#  Procedures in this module start with the keyword mplsrouter and
#  end with function specific part that is the same for all the node
#  types that work on the same layer.
#****

set MODULE mplsrouter
registerModule $MODULE

################################################################################
########################### CONFIGURATION PROCEDURES ###########################
################################################################################

#****f* mplsrouter.tcl/mplsrouter.confNewNode
# NAME
#   mplsrouter.confNewNode -- configure new node
# SYNOPSIS
#   mplsrouter.confNewNode $node_id
# FUNCTION
#   Configures new node with the specified id.
# INPUTS
#   * node_id -- node id
#****

proc $MODULE.confNewNode { node_id } {
    global ripEnable ripngEnable ospfEnable ospf6Enable bgpEnable
    global rdconfig router_model mplsrouter_ConfigModel
    global def_router_model
    global nodeNamingBase

    lassign $rdconfig ripEnable ripngEnable ospfEnable ospf6Enable bgpEnable
    set mplsrouter_ConfigModel $router_model

    setNodeName $node_id [getNewNodeNameType mplsrouter $nodeNamingBase(mplsrouter)]
    setNodeModel $node_id $router_model

    setNodeProtocol $node_id "rip" $ripEnable
    setNodeProtocol $node_id "ripng" $ripngEnable
    setNodeProtocol $node_id "ospf" $ospfEnable
    setNodeProtocol $node_id "ospf6" $ospf6Enable
    setNodeProtocol $node_id "bgp" $bgpEnable

    setAutoDefaultRoutesStatus $node_id "enabled"

    set logiface_id [newLogIface $node_id "lo"]
    setIfcIPv4addrs $node_id $logiface_id "127.0.0.1/8"
    setIfcIPv6addrs $node_id $logiface_id "::1/128"
}

#****f* mplsrouter.tcl/mplsrouter.confNewIfc
# NAME
#   mplsrouter.confNewIfc -- configure new interface
# SYNOPSIS
#   mplsrouter.confNewIfc $node_id $iface_id
# FUNCTION
#   Configures new interface for the specified node.
# INPUTS
#   * node_id -- node id
#   * iface_id -- interface name
#****

proc $MODULE.confNewIfc { node_id iface_id } {
    autoIPv4addr $node_id $iface_id
    autoIPv6addr $node_id $iface_id
    autoMACaddr $node_id $iface_id

    lassign [logicalPeerByIfc $node_id $iface_id] peer_id -
    if { $peer_id != "" && [getNodeType $peer_id] == "extnat" } {
	setIfcNatState $node_id $iface_id "on"
    }
}

proc $MODULE.generateConfigIfaces { node_id ifaces } {
    set all_ifaces "[ifcList $node_id] [logIfcList $node_id]"
    if { $ifaces == "*" } {
	set ifaces $all_ifaces
    } else {
	# sort physical ifaces before logical ones (because of vlans)
	set negative_ifaces [removeFromList $all_ifaces $ifaces]
	set ifaces [removeFromList $all_ifaces $negative_ifaces]
    }

    set cfg {}
    foreach iface_id $ifaces {
	set cfg [concat $cfg [mplsrouterCfggenIfc $node_id $iface_id]]

	lappend cfg ""
    }

    return $cfg
}

proc $MODULE.generateUnconfigIfaces { node_id ifaces } {
    set all_ifaces "[ifcList $node_id] [logIfcList $node_id]"
    if { $ifaces == "*" } {
	set ifaces $all_ifaces
    } else {
	# sort physical ifaces before logical ones
	set negative_ifaces [removeFromList $all_ifaces $ifaces]
	set ifaces [removeFromList $all_ifaces $negative_ifaces]
    }

    set cfg {}
    foreach iface_id $ifaces {
	set cfg [concat $cfg [mplsrouterUncfggenIfc $node_id $iface_id]]

	lappend cfg ""
    }

    return $cfg
}

#****f* mplsrouter.tcl/mplsrouter.generateConfig
# NAME
#   mplsrouter.generateConfig -- configuration generator
# SYNOPSIS
#   set config [mplsrouter.generateConfig $node_id]
# FUNCTION
#   Generates configuration. This configuration represents the default
#   configuration loaded on the booting time of the virtual nodes and it is
#   closly related to the procedure mplsrouter.bootcmd.
#   Generated configuration comprises the ip addresses (both ipv4 and ipv6)
#   and interface states (up or down) for each interface of a given node.
#   Static routes are also included.
# INPUTS
#   * node_id - node id
# RESULT
#   * config -- generated configuration
#****
proc $MODULE.generateConfig { node_id } {
    set cfg {}
    if { [getCustomEnabled $node_id] != true || [getCustomConfigSelected $node_id "NODE_CONFIG"] in "\"\" DISABLED" } {
	foreach protocol { rip ripng ospf ospf6 bgp } {
	    set cfg [concat $cfg [getmplsrouterProtocolCfg $node_id $protocol]]
	}
    }

    set subnet_gws {}
    set nodes_l2data [dict create]
    if { [getAutoDefaultRoutesStatus $node_id] == "enabled" } {
	lassign [getDefaultGateways $node_id $subnet_gws $nodes_l2data] my_gws subnet_gws nodes_l2data
	lassign [getDefaultRoutesConfig $node_id $my_gws] all_routes4 all_routes6

	setDefaultIPv4routes $node_id $all_routes4
	setDefaultIPv6routes $node_id $all_routes6
    } else {
	setDefaultIPv4routes $node_id {}
	setDefaultIPv6routes $node_id {}
    }

    set cfg [concat $cfg [mplsrouterRoutesCfggen $node_id]]

    return $cfg
}

proc $MODULE.generateUnconfig { node_id } {
    set cfg {}

    if { [getCustomEnabled $node_id] != true } {
	foreach protocol { rip ripng ospf ospf6 bgp } {
	    set cfg [concat $cfg [getmplsrouterProtocolUnconfig $node_id $protocol]]
	}
    }

    set cfg [concat $cfg [mplsrouterRoutesUncfggen $node_id]]

    return $cfg
}

#****f* mplsrouter.tcl/mplsrouter.ifacePrefix
# NAME
#   mplsrouter.ifacePrefix -- interface name
# SYNOPSIS
#   mplsrouter.ifacePrefix
# FUNCTION
#   Returns mplsrouter interface name prefix.
# RESULT
#   * name -- name prefix string
#****
proc $MODULE.ifacePrefix {} {
    return "eth"
}

#****f* mplsrouter.tcl/mplsrouter.IPAddrRange
# NAME
#   mplsrouter.IPAddrRange -- IP address range
# SYNOPSIS
#   mplsrouter.IPAddrRange
# FUNCTION
#   Returns mplsrouter IP address range
# RESULT
#   * range -- mplsrouter IP address range
#****
proc $MODULE.IPAddrRange {} {
    return 1
}

#****f* mplsrouter.tcl/mplsrouter.netlayer
# NAME
#   mplsrouter.netlayer -- layer
# SYNOPSIS
#   set layer [mplsrouter.netlayer]
# FUNCTION
#   Returns the layer on which the mplsrouter operates, i.e. returns NETWORK.
# RESULT
#   * layer -- set to NETWORK
#****
proc $MODULE.netlayer {} {
    return NETWORK
}

#****f* mplsrouter.tcl/mplsrouter.virtlayer
# NAME
#   mplsrouter.virtlayer -- virtual layer
# SYNOPSIS
#   set layer [mplsrouter.virtlayer]
# FUNCTION
#   Returns the layer on which the mplsrouter is instantiated, i.e. returns
#   VIRTUALIZED.
# RESULT
#   * layer -- set to VIRTUALIZED
#****
proc $MODULE.virtlayer {} {
    return VIRTUALIZED
}

#****f* mplsrouter.tcl/mplsrouter.bootcmd
# NAME
#   mplsrouter.bootcmd -- boot command
# SYNOPSIS
#   set appl [mplsrouter.bootcmd $node_id]
# FUNCTION
#   Procedure bootcmd returns the defaut application that reads and employes
#   the configuration generated in mplsrouter.generateConfig.
# INPUTS
#   * node_id - node id
# RESULT
#   * appl -- application that reads the configuration
#****
proc $MODULE.bootcmd { node_id } {
    return "/bin/sh"
}

#****f* mplsrouter.tcl/mplsrouter.shellcmds
# NAME
#   mplsrouter.shellcmds -- shell commands
# SYNOPSIS
#   set shells [mplsrouter.shellcmds]
# FUNCTION
#   Procedure shellcmds returns the shells that can be opened
#   as a default shell for the system.
# RESULT
#   * shells -- default shells for the mplsrouter
#****
proc $MODULE.shellcmds {} {
    return "csh bash vtysh sh tcsh"
}

#****f* mplsrouter.tcl/mplsrouter.nghook
# NAME
#   mplsrouter.nghook -- nghook
# SYNOPSIS
#   mplsrouter.nghook $eid $node_id $iface_id
# FUNCTION
#   Returns the id of the netgraph node and the name of the netgraph hook
#   which is used for connecting two netgraph nodes. This procedure calls
#   l3node.hook procedure and passes the result of that procedure.
# INPUTS
#   * eid - experiment id
#   * node_id - node id
#   * iface_id - interface id
# RESULT
#   * nghook - the list containing netgraph node id and the
#     netgraph hook (ngNode ngHook).
#****
proc $MODULE.nghook { eid node_id iface_id } {
    return [list $node_id-[getIfcName $node_id $iface_id] ether]
}

################################################################################
############################ INSTANTIATE PROCEDURES ############################
################################################################################

#****f* mplsrouter.tcl/mplsrouter.prepareSystem
# NAME
#   mplsrouter.prepareSystem -- prepare system
# SYNOPSIS
#   mplsrouter.prepareSystem
# FUNCTION
#   Does nothing
#****
proc $MODULE.prepareSystem {} {
    # nothing to do
}

#****f* mplsrouter.tcl/mplsrouter.nodeCreate
# NAME
#   mplsrouter.nodeCreate -- instantiate
# SYNOPSIS
#   mplsrouter.nodeCreate $eid $node_id
# FUNCTION
#   Creates a new virtual node for a given node in imunes.
#   Procedure mplsrouter.nodeCreate creates a new virtual node with all
#   the interfaces and CPU parameters as defined in imunes. It sets the
#   net.inet.ip.forwarding and net.inet6.ip6.forwarding kernel variables to 1.
# INPUTS
#   * eid - experiment id
#   * node_id - node id
#****
proc $MODULE.nodeCreate { eid node_id } {
    prepareFilesystemForNode $node_id
    createNodeContainer $node_id
}

#****f* mplsrouter.tcl/mplsrouter.nodeNamespaceSetup
# NAME
#   mplsrouter.nodeNamespaceSetup -- mplsrouter node nodeNamespaceSetup
# SYNOPSIS
#   mplsrouter.nodeNamespaceSetup $eid $node_id
# FUNCTION
#   Linux only. Attaches the existing Docker netns to a new one.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeNamespaceSetup { eid node_id } {
    attachToL3NodeNamespace $node_id
}

#****f* mplsrouter.tcl/mplsrouter.nodeInitConfigure
# NAME
#   mplsrouter.nodeInitConfigure -- mplsrouter node nodeInitConfigure
# SYNOPSIS
#   mplsrouter.nodeInitConfigure $eid $node_id
# FUNCTION
#   Runs initial L3 configuration, such as creating logical interfaces and
#   configuring sysctls.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeInitConfigure { eid node_id } {
    configureICMPoptions $node_id
    enableIPforwarding $node_id
    startRoutingDaemons $node_id
}

proc $MODULE.nodePhysIfacesCreate { eid node_id ifaces } {
    nodePhysIfacesCreate $node_id $ifaces
}

proc $MODULE.nodeLogIfacesCreate { eid node_id ifaces } {
    nodeLogIfacesCreate $node_id $ifaces
}

#****f* mplsrouter.tcl/mplsrouter.nodeIfacesConfigure
# NAME
#   mplsrouter.nodeIfacesConfigure -- configure mplsrouter node interfaces
# SYNOPSIS
#   mplsrouter.nodeIfacesConfigure $eid $node_id $ifaces
# FUNCTION
#   Configure interfaces on a mplsrouter. Set MAC, MTU, queue parameters, assign the IP
#   addresses to the interfaces, etc. This procedure can be called if the node
#   is instantiated.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#   * ifaces -- list of interface ids
#****
proc $MODULE.nodeIfacesConfigure { eid node_id ifaces } {
    startNodeIfaces $node_id $ifaces
}

#****f* mplsrouter.tcl/mplsrouter.nodeConfigure
# NAME
#   mplsrouter.nodeConfigure -- start
# SYNOPSIS
#   mplsrouter.nodeConfigure $eid $node_id
# FUNCTION
#   Starts a new mplsrouter. The node can be started if it is instantiated.
#   Simulates the booting proces of a mplsrouter.
# INPUTS
#   * eid - experiment id
#   * node_id - node id
#****
proc $MODULE.nodeConfigure { eid node_id } {
    runConfOnNode $node_id
}

################################################################################
############################# TERMINATE PROCEDURES #############################
################################################################################

#****f* mplsrouter.tcl/mplsrouter.nodeIfacesUnconfigure
# NAME
#   mplsrouter.nodeIfacesUnconfigure -- unconfigure mplsrouter node interfaces
# SYNOPSIS
#   mplsrouter.nodeIfacesUnconfigure $eid $node_id $ifaces
# FUNCTION
#   Unconfigure interfaces on a mplsrouter to a default state. Set name to iface_id,
#   flush IP addresses to the interfaces, etc. This procedure can be called if
#   the node is instantiated.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#   * ifaces -- list of interface ids
#****
proc $MODULE.nodeIfacesUnconfigure { eid node_id ifaces } {
    unconfigNodeIfaces $eid $node_id $ifaces
}

proc $MODULE.nodeIfacesDestroy { eid node_id ifaces } {
    nodeIfacesDestroy $eid $node_id $ifaces
}

proc $MODULE.nodeUnconfigure { eid node_id } {
    unconfigNode $eid $node_id
}

#****f* mplsrouter.tcl/mplsrouter.nodeShutdown
# NAME
#   mplsrouter.nodeShutdown -- shutdown
# SYNOPSIS
#   mplsrouter.nodeShutdown $eid $node_id
# FUNCTION
#   Shutdowns a mplsrouter node.
#   Simulates the shutdown proces of a node, kills all the services and
# INPUTS
#   * eid - experiment id
#   * node_id - node id
#****
proc $MODULE.nodeShutdown { eid node_id } {
    killExtProcess "wireshark.*[getNodeName $node_id].*\\($eid\\)"
    killAllNodeProcesses $eid $node_id
}

#****f* mplsrouter.tcl/mplsrouter.nodeDestroy
# NAME
#   mplsrouter.nodeDestroy -- layer 3 node destroy
# SYNOPSIS
#   mplsrouter.nodeDestroy $eid $node_id
# FUNCTION
#   Destroys a mplsrouter node.
#   First, it destroys all remaining virtual ifaces (vlans, tuns, etc).
#   Then, it destroys the jail/container with its namespaces and FS.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeDestroy { eid node_id } {
    destroyNodeVirtIfcs $eid $node_id
    removeNodeContainer $eid $node_id
    destroyNamespace $eid-$node_id
    removeNodeFS $eid $node_id
}
