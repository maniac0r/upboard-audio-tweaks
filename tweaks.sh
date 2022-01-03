#!/bin/bash
STR_LOG="/var/log/audio-tweaks.log"

P_ROON="RoonServer"
P_BRIDGE="RoonBridge"
P_RAAT="RAATServer"
P_APPLIANCE="RoonAppliance"
P_UPMPD="upmpdcli"
P_MPD="mpd"
P_HQP="networkaudiod"
P_SQUEEZE="squeezelite"
P_ETH="irq\/.*-eth0"
P_XHCI="irq\/.*-xhci_hc"
P_PCIPM="PCIe PM"
R_KERNELMOD="irq|mmc_|kworker"

# bit mask mapping for accesing /proc/irq/../smp_affinity files
CPU0=1	# 0001
CPU1=2	# 0010
CPU2=4	# 0100
CPU3=8	# 1000


cpu_affinity_eth0() {
  pgrep "irq\/.*-eth0" | xargs -n 1 /usr/bin/taskset -a -c -p $1
  echo "eth0 irq affinity set to CPU $1" >&2
}

cpu_affinity_enp1s0() {
#  XPID=$(procinfo | egrep 'enp1s0'  | sed 's/.*irq //' |sed 's/:.*//')
  XPID=$(procinfo | egrep '^irq' | egrep 'enp1s'  | sed 's/.*irq //' |sed 's/:.*//')
  echo $1 > /proc/irq/$XPID/smp_affinity
  C=$(printf "\x$1" | xxd -b | awk '{print $2}')
  echo "enp1s0 irq affinity set to CPUs $C ($1)" >&1
}

cpu_affinity_usbxhci() {
  /usr/bin/taskset -a -c -p $1 $(pgrep "$P_XHCI")
  #C=$(printf "\x$1" | xxd -b | awk '{print $2}')
  echo "usb task affinity set to CPU $1" >&2
}

cpu_affinity_usbxhci_irq() {
  XPID=$(procinfo | egrep '^irq' | egrep 'xhci'  | sed 's/.*irq //' |sed 's/:.*//')
#  XPID=$(procinfo | egrep 'xhci_$'  | sed 's/.*irq //' |sed 's/:.*//')
  echo $1 > /proc/irq/$XPID/smp_affinity
  C=$(printf "\x$1" | xxd -b | awk '{print $2}')
  echo "usb irq affinity set to CPUs $C  ($1)" >&2
}

cpu_affinity_pcipm() {
  /usr/bin/taskset -a -c -p $1 $(pgrep "$P_PCIPM")
  #C=$(printf "\x$1" | xxd -b | awk '{print $2}')
  echo "pci-pm task affinity set to CPU $1" >&2
}

cpu_affinity_pcipm_irq() {
  XPID=$(procinfo | egrep '^irq' | egrep 'PCIe'  | sed 's/.*irq //' |sed 's/:.*//')
#  XPID=$(procinfo | egrep 'xhci_$'  | sed 's/.*irq //' |sed 's/:.*//')
  echo $1 > /proc/irq/$XPID/smp_affinity
  C=$(printf "\x$1" | xxd -b | awk '{print $2}')
  echo "pci-pm irq affinity set to CPUs $C  ($1)" >&2
}

set_irq_affinity() {
  IRQ=$(egrep "$1"  /proc/interrupts | awk -F ':' '{print $1}' | tr -d \ )
#  XPID=$(procinfo | egrep 'xhci_$'  | sed 's/.*irq //' |sed 's/:.*//')
  echo $2 > /proc/irq/$IRQ/smp_affinity
  C=$(printf "\x$2" | xxd -b | awk '{print $2}')
  echo "IRQ-$IRQ ($1) affinity set to CPUs $C ($2)" >&2
}

set_pid_affinity() {
  PID=$(pgrep $1)
#  XPID=$(procinfo | egrep 'xhci_$'  | sed 's/.*irq //' |sed 's/:.*//')
  /usr/bin/taskset -a -c -p $2 $PID
  C=$(printf "\x$2" | xxd -b | awk '{print $2}')
  echo "Task $1 pid $PID affinity set to CPUs $C ($2)" >&2
}

cpu_affinity_upmpdcli() {
  /usr/bin/taskset -a -c -p $1 $(pgrep "$P_UPMPD")
  echo "upnpdcli affinity set to CPU $1" >&2
}

cpu_affinity_raat() {
  # pozor, z nejakeho dovodu sa musi pouzit taskset uz pri startovani raatu, takze uprava je hlavne v startup skripte potrebna..
  pgrep -f RAATServer | xargs -n 1 /usr/bin/taskset -c -p $1
  echo "RAATServer  affinity set to CPU $1 , MAY REQUIRE SVC MODIF." >&2
}

cpu_affinity_mpd() {
  # pozor, z nejakeho dovodu sa musi pouzit taskset uz pri startovani mpd (systemd service file)
  /usr/bin/taskset -a -c -p $1 $(pidof mpd)
  echo "MPD          affinity set to CPU $1 , MAY REQUIRE SVC MODIF." >&2
}

cpu_affinity_naa() {
  /usr/bin/taskset -a -c -p $1 $(pidof networkaudiod)
  echo "NetworkAudioA affinity set to CPU $1" >&2
}

cpu_affinity_squeeze() {
  /usr/bin/taskset -a -c -p $1 $(pidof squeezelite)
  echo "SqueezeLite affinity set to CPU $1."
}

cpu_affinity_trash() {
  # trash goes to this cpu
  /usr/bin/taskset -c -p $1 $(pidof RoonBridgeHelper)
  echo "RoonBridgeHelper affinity set to CPU $1."
  /usr/bin/taskset -c -p $1 $(pidof processreaper)
  echo "RoonProcReaper affinity set to CPU $1."
  /usr/bin/taskset -c -p $1 $(pgrep -f RoonBridge.exe)
  echo "RoonBridge affinity set to CPU $1."
  /usr/bin/taskset -c -p $1 $(pgrep -f rcu_preempt)
  echo "RCU_Preempt affinity set to CPU $1."
  /usr/bin/taskset -c -p $1 1
  echo "system init affinity set to CPU $1."
}

renice_usb() {
  # USB BUS
  /usr/bin/renice $1 -p $(pgrep "$P_XHCI")
  echo "USB irq nice set to $1." >&2
}

renice_mpd() {
  /usr/bin/renice $1 -p $(pgrep -w -f /mpd)
  echo "MPD nice set to $1." >&2
}

renice_raat() {
  /usr/bin/renice $1 -p $(pgrep -w -f RAATServer)
  echo "RAATServer nice set to $1." >&2
}

renice_hpq() {
  # HQP NAA
  /usr/bin/renice $1 -p $(pidof networkaudiod)
  echo "NAA nice set to $1. >&2"
}

renice_upmpdcli() {
  /usr/bin/renice $1 -p $(pidof upmpdcli)
  echo "upmpdcli nice set to $1." >&2
}

renice_squeeze() {
  /usr/bin/renice $1 -p $(pidof squeezelite)
  echo "squeezelite nice set to $1." >&2
}

renice_eth0() {
  # ETHERNET
  pgrep "irq\/.*-eth0" | xargs /usr/bin/renice $1
  echo "ethernet irq nice set to $1." >&2
}

#  * Options (At least one of them)
# s = roon Server
# a = roon Appliance
# r = RAAT
# b = roon Bridge
# d = mpD
# u = Upmpdcli
# q = HQP networkaudiod
# e = Ethernet
# x = Xhci USB
#
# Parameters
# m = Scheduling >> {FIFO|RR}
# p = Priority   >> {0-99}

realtime_usb_raat_hpq_mpd() {
  ./roon-realtime.sh -p 99 -m FIFO -b n -r y -d y -u n -q n -e n -x y
  # USB BUS (lebo skript hore asi nezafunguje?)
  # FIFO prio 99 (highest)
  chrt -f -p 99 $(pgrep "$P_XHCI") >> $STR_LOG
  chrt -p $(pgrep "$P_XHCI") >> $STR_LOG
  # ETH lowest priority, round robin
  # Round-Robin prio 1 (lowest)
  #pgrep "irq\/.*-eth0" | xargs -n 1 chrt -r -p 1 >> $STR_LOG
  #pgrep "irq\/.*-eth0" | xargs -n 1 chrt -p >> $STR_LOG
}

# # # # # # # # # #
# Function
# $1 = Value for Parent Process Name
# $2 = Value for Scheduling
# $3 = Value for Priority
# $4 = pidof/pgrep method
# # # # # # # # # # 
set_realtime() {
        if [ "$4" == "pgrep" ] ; then
          GETPID="pgrep -f"
        else
          GETPID="pidof"
        fi
        
        if [ "$2" == "FIFO" ] ; then
          SCHED="-f"
        else
          SCHED="-r"
        fi

	# just elevate prio of RT threads (mpd)
        if [ "$4" == "elevate" ] ; then
           ARR_PID=$( ps axHo rtprio,lwp,ni,pid,command | grep $1  | egrep -v '^\s+-\s+' | awk '{print $2}' )
	   INT_ROWS=0
           for p_id in $ARR_PID;
             do
#	echo "DEBUG p_id: $p_id"
#               echo "## Process : $(tail /proc/$($GETPID $1)/task/$p_id/comm) | PID = $p_id" >> $STR_LOG
                                chrt $SCHED -p $3 $p_id >> $STR_LOG
                                chrt -p $p_id >> $STR_LOG
                                INT_ROWS=$(($INT_ROWS + 1));
             done
             return
        fi
             
             
                [[ -d /proc/$($GETPID $1)/task ]] || return 1
                ARR_PID=$(ls /proc/$($GETPID $1)/task)
#                [[ "x${ARR_PID}" == "x" ]] && return
                INT_ROWS=0
                for p_id in $ARR_PID;
                        do
                                echo "## Process : $(tail /proc/$($GETPID $1)/task/$p_id/comm) | PID = $p_id" >> $STR_LOG
                                chrt -a $SCHED -p $3 $p_id >> $STR_LOG
                                chrt -a -p $p_id >> $STR_LOG
                                INT_ROWS=$(($INT_ROWS + 1));
                        done
                echo "## -----------------------------------------------------------------" >> $STR_LOG
                echo "## Parent Process [$1] >> $INT_ROWS child process updated..." >> $STR_LOG
                echo "## -----------------------------------------------------------------" >> $STR_LOG
                echo "- - - - " >> $STR_LOG
}

# chceme ci nie??
#prioritize_eth0() {
#  pgrep "irq\/.*-eth0" | xargs -n 1 chrt -f -p $1
#  pgrep "irq\/.*-eth0" | xargs -n 1 chrt -p
#  pgrep "irq\/.*-eth0" | xargs /usr/bin/renice $2
#}

set_kernelparams() {
   echo "Setting kernel parameters..." >&2
   echo 1 > /sys/bus/workqueue/devices/writeback/cpumask
#   echo 5000000 > /proc/sys/kernel/sched_migration_cost_ns
  #echo 6000000 > /proc/sys/kernel/sched_latency_ns	# default
  #echo 1500000 > /proc/sys/kernel/sched_latency_ns	# rune audio
#   echo 1000000 > /proc/sys/kernel/sched_latency_ns
#   echo 100000  > /proc/sys/kernel/sched_min_granularity_ns
  #echo 225000  > /proc/sys/kernel/sched_min_granularity_ns
#   echo 25000   > /proc/sys/kernel/sched_wakeup_granularity_ns
   echo -1      > /proc/sys/kernel/sched_rt_runtime_us
#   echo 1       > /proc/sys/kernel/hung_task_check_count
   echo 0       > /proc/sys/vm/swappiness
   echo 20      > /proc/sys/vm/stat_interval
   echo 10      > /proc/sys/vm/dirty_ratio
  #echo 3       > /proc/sys/vm/dirty_background_ratio
   echo 5       > /proc/sys/vm/dirty_background_ratio
   echo -n performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   echo -n performance > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
   echo -n performance > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
   echo -n performance > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
}

remove_kernelmodules() {
#./remove_modules.sh
#rmmod bluetooth cfg80211  nf_tables rpcsec_gss_krb5 input_leds intel_chtdc_ti_pwrbtn parport_pc ppdev lp ip_tables x_tables mei_txe mei nfnetlink snd_seq_oss snd_seq_midi intel_rapl_msr intel_rapl_common intel_powerclamp punit_atom_debug intel_cstate intel_xhci_usb_role_switch
rmmod bluetooth cfg80211  nf_tables rpcsec_gss_krb5 input_leds intel_chtdc_ti_pwrbtn parport_pc ppdev lp ip_tables x_tables mei_txe mei nfnetlink snd_seq_oss snd_seq_midi intel_rapl_msr intel_rapl_common intel_powerclamp punit_atom_debug intel_cstate intel_xhci_usb_role_switch nfnetlink snd_seq_oss snd_seq_midi intel_rapl_msr intel_rapl_common intel_powerclamp punit_atom_debug intel_cstate intel_xhci_usb_role_switch acpi_pad int3403_thermal int340x_thermal_zone ms autofs4 snd_seq_midi_event ghash_clmulni_intel crc32_pclmul dw_dmac dw_dmac_core snd_seq msr auth_rpcgss


true

}

tune_default() {
  ifconfig eth0 mtu 1500
  ifconfig eth0 txqueuelen 1000
  echo 0 > /proc/sys/vm/swappiness
  echo "6000000" /proc/sys/kernel/sched_latency_ns
}

tune_runeaudio() {
  ifconfig eth0 mtu 1500
  ifconfig eth0 txqueuelen 1000
  echo 0 > /proc/sys/vm/swappiness
  echo "1500000" > /proc/sys/kernel/sched_latency_ns
}

tune_acx() {
  ifconfig eth0 mtu 1500

  ifconfig eth0 txqueuelen 4000
  echo "850000" > /proc/sys/kernel/sched_latency_ns
}

tune_orion() {
  ifconfig eth0 mtu 1000
  ifconfig eth0 txqueuelen 1000
  echo 20 > /proc/sys/vm/swappiness
  echo "500000" > /proc/sys/kernel/sched_latency_ns
}

tune_orionv2() {
  ifconfig eth0 mtu 1000
  ifconfig eth0 txqueuelen 4000
  echo 0 > /proc/sys/vm/swappiness
  echo "120000" > /proc/sys/kernel/sched_latency_ns
}

tune_um3gg1h1u() {
  ifconfig eth0 mtu 1500
  ifconfig eth0 txqueuelen 1000
  echo 0 > /proc/sys/vm/swappiness
  echo "500000" > /proc/sys/kernel/sched_latency_ns
}

###################################
#


set_kernelparams >/dev/null

remove_kernelmodules > /dev/null 2>&1 

# USB
renice_usb	-19
set_realtime $P_XHCI		FIFO 98	pgrep
cpu_affinity_usbxhci	3	# stay together with XHCI IRQ on CPU0
cpu_affinity_usbxhci_irq $CPU3 #$CPU1

# RTC clock (vyzera ze znizi jitterdebug)
set_realtime rtc0 FIFO 97 pgrep
set_irq_affinity rtc0 $CPU1

# MMC SDcard
#echo $CPU1 > /proc/irq/45/smp_affinity

# Ethernet
# cpu_affinity_eth0	3
# echo $CPU3  > /proc/irq/46/smp_affinity	# RPI4 ETH0 RX
# echo $CPU3 > /proc/irq/47/smp_affinity		# RPI4 ETH0 TX
cpu_affinity_enp1s0 1
set_irq_affinity enp1s $CPU1

# bind eth0 queues to core3
#for F in $(ls /sys/class/net/eth0/queues/tx-*/xps_cpus) ; do echo $CPU3 > $F ; done
#for F in $(ls /sys/class/net/eth0/queues/tx-*/xps_rxqs) ; do echo $CPU3 > $F ; done
#echo $CPU3 > /sys/class/net/eth0/queues/rx-0/rps_cpus

# RAAT
cpu_affinity_raat	2
renice_raat		-18
# 2021-12-26 roonbridge si sam nastavi PRIO 95 a RR scheduler(preco RR??)
#set_realtime $P_RAAT	FIFO 93
#
set_realtime $P_RAAT    FIFO 93 elevate

# MPD
cpu_affinity_mpd	2
set_realtime $P_MPD    FIFO 95 elevate

#cpu_affinity_trash	0

cpu_affinity_pcipm	0
cpu_affinity_pcipm_irq	$CPU0

##set_irq_affinity rtc0 $CPU1
##set_pid_affinity "irq_work/3" 1

set_pid_affinity "rcub/0" 0,1,2
set_pid_affinity "rcu_preempt" 0,1,2
set_pid_affinity "PCIe" 1
#set_irq_affinity enp1s $CPU1
 
exit


exit

# move all possible RCU calbacks to cpu0 https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/offloading_rcu_callbacks

echo "tuna -  move all possible RCU calbacks to cpu0"
tuna -t rcu* -c 0 -m

echo "move rcuos to cpu0"
pgrep rcuo | xargs -I%% taskset -c -p $CPU0 %%

exit

# HQP NAA
cpu_affinty_naa	2
renice_hpq		-18
set_realtime $P_HQP	FIFO 94

# SQUEEZELITE
cpu_affinity_naa	2
renice_squeeze		-18
set_realtime $P_SQUEEZE	FIFO 94

cpu_affinity_sqeeze	2
cpu_affinity_upmpdcli	1

# ETH0
 echo $CPU3  > /proc/irq/46/smp_affinity	# RPI4 ETH0 RX
 echo $CPU3 > /proc/irq/47/smp_affinity		# RPI4 ETH0 TX

  # USB XHCI (is fixed to cpu0...)
  # echo $CPU0 > /proc/irq/54/smp_affinity

  # arch timer (is fixed to all cpus...)
  # echo $CPU123 > /proc/irq/19/smp_affinity

#renice_mpd	-18

renice_upmpdcli -17
renice_eth0	-5

# MPD si handluje RTPRIO sam (rtprio 40 len pre potrebne thready)
#set_realtime $P_MPD		FIFO 95


exit

# network servicec, not directly players
#set_realtime $P_BRIDGE		FIFO 90
#set_realtime $P_UPMPD		FIFO 90	pgrep

# 20210324 toto ked je zapnute tak seka zaciatok tracku a potom kazdych cca 10sec sek. vtedy mpd cachuje zo siete
#set_realtime $P_ETH		FIFO 80	pgrep

#set_realtime $P_APPLIANCE	RR 70
#set_realtime $P_ROON		RR 70

