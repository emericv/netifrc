# Copyright (c) 2018 Emeric Verschuur <emeric@mbedsys.org>
# All rights reserved. Released under the 2-clause BSD license.

ovs_depend()
{
	program ovs-vsctl
	before interface macnet
}

ovs_pre_start()
{
	if typeset -p ovs_${IFVAR} > /dev/null 2>&1; then
		# Try to load mendatory openvswitch kernel module
		if ! modprobe openvswitch; then
			eend 1 "openvswitch module not present in your kernel (please enable CONFIG_OPENVSWITCH option in your kernel config)"
			return 1
		fi

		# ports is for static add
		local ports="$(_get_array "ovs_${IFVAR}")"
		
		(
		if ! ovs-vsctl br-exists "${IFVAR}" ; then
			ebegin "Creating bridge ${IFACE}"
			veinfo ovs-vsctl add-br "${IFACE}"
			ovs-vsctl add-br "${IFACE}"
			rc=$?
			if [ ${rc} != 0 ]; then
				eend 1
				return 1
			fi
		fi
		
		if [ -n "${ports}" ]; then
			einfo "Adding ports to ${IFACE}"
			eindent

			local BR_IFACE="${IFACE}"
			for x in ${ports}; do
				ebegin "${x}"
				local IFACE="${x}"
				local IFVAR=$(shell_var "${IFACE}")
				if ! _exists "${IFACE}" ; then
					eerror "Cannot add non-existent interface ${IFACE} to ${BR_IFACE}"
					return 1
				fi
				# The interface is known to exist now
				_up
				veinfo ovs-vsctl add-port ${BR_IFACE} ${IFACE}
				ovs-vsctl add-port ${BR_IFACE} ${IFACE}
				if [ $? != 0 ]; then
					eend 1
					return 1
				fi
				eend 0
			done
			eoutdent
		fi
		) || return 1
		
		_up
	fi

	if typeset -p ovsadd_${IFVAR}_to > /dev/null 2>&1; then
		eval BR_IFACE=\$ovsadd_${IFVAR}_to
		if [ "$(ovs-vsctl iface-to-br ${IFACE} 2> /dev/null)" != "$BR_IFACE" ]; then
			ebegin "Adding port ${IFACE} to $BR_IFACE"
			if [ -z $BR_IFACE ]; then
				eerror "OVS bridge name not valid"
				return 1
			fi
			if ! ovs-vsctl br-exists "$BR_IFACE" ; then
				eerror "You have to setup $BR_IFACE OVS bridge first"
				return 1
			fi
			veinfo ovs-vsctl add-port ${BR_IFACE} ${IFACE}
			ovs-vsctl add-port ${BR_IFACE} ${IFACE}
			eend $?
		fi
	fi
}


ovs_post_stop()
{
	if typeset -p ovs_${IFVAR} > /dev/null 2>&1; then
		ovs-vsctl br-exists "${IFVAR}" || exit 0
		ebegin "Destroying bridge ${IFACE}"
		_down
		veinfo ovs-vsctl del-br "${IFACE}"
		ovs-vsctl del-br "${IFACE}"
		eend $?
	fi
	
	if typeset -p ovsadd_${IFVAR}_to > /dev/null 2>&1; then
		eval BR_IFACE=\$ovsadd_${IFVAR}_to
		ebegin "Removing port ${IFACE} from $BR_IFACE"
		veinfo ovs-vsctl del-port ${BR_IFACE} ${IFACE}
		ovs-vsctl del-port ${BR_IFACE} ${IFACE}
		eend $?
	fi
}
